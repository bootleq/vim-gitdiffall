#!/usr/bin/env ruby

require 'optparse'
require 'pathname'
Version = '1.1.0'

config_path = [
  '~/gitdiffall/config.rb',
  '~/gitdiffall-config.rb',
  (File.dirname(__FILE__) + '/gitdiffall/config.rb'),
  (File.dirname(__FILE__) + '/gitdiffall-config.rb')
].find {|path|
  File.exist?(File.expand_path(path))
}
require config_path if config_path

config = ({
  :editor_cmd     => 'vim',
  :max_files      => 14,
  :min_hash_abbr  => 5,
  :ignore_pattern => /\.(png|jpg)\Z/i
}).merge!(defined?(CONFIG) ? CONFIG : {})

SHORTCUT_ENV_VAR = '_GITDIFFALL_LAST_SHORTCUT'

opt = OptionParser.new
opt.banner = "Usage: gitdiffall [revision] [diff-options] [--] [<path>...]"
common_opt_desc = '(delegate to git)'

revision, diff_opts, paths = '', [], ''
use_cached, relative, detect_shortcut = '', '', nil

opt.on('--[no-]shortcut', "force parsing REVISION as shortcut") {|v| detect_shortcut = v}

opt.on('--cached', '--staged', common_opt_desc) {|v| use_cached = "--cached"}
opt.on('--relative[=path]', common_opt_desc) {|v| relative = v; diff_opts << "--relative#{"=#{v}" unless v.nil?}"}

opt.on('--no-renames', common_opt_desc)                                    {|v| diff_opts << "--no-renames"}
opt.on('-B[<n>][/<m>]', '--break-rewrites[=[<n>][/<m>]]', common_opt_desc) {|v| diff_opts << "-B#{v}"}
opt.on('-M[<n>]', '--find-renames[=[<n>]]', common_opt_desc)               {|v| diff_opts << "-M#{v}"}
opt.on('-C[<n>]', '--find-copies[=[<n>]]', common_opt_desc)                {|v| diff_opts << "-C#{v}"}
opt.on('--find-copies-harder', common_opt_desc)                            {|v| diff_opts << "--find-copies-harder"}
opt.on('-D', '--irreversible-delete', common_opt_desc)                     {|v| diff_opts << "-D"}
opt.on('-l num', common_opt_desc)                                          {|v| diff_opts << "-l #{v}"}
opt.on('--diff-filter=filter', common_opt_desc)                            {|v| diff_opts << "--diff-filter=#{v}"}
opt.on('-S[string]', common_opt_desc)                                      {|v| diff_opts << "-S#{v}"}
opt.on('-G[regex]', common_opt_desc)                                       {|v| diff_opts << "-G#{v}"}
opt.on('--pickaxe', common_opt_desc)                                       {|v| diff_opts << "--pickaxe"}
opt.on('-O[orderfile]', common_opt_desc)                                   {|v| diff_opts << "-O#{v}"}
opt.on('-R', common_opt_desc)                                              {|v| diff_opts << "-R"}
opt.on('-a', '--text', common_opt_desc)                                    {|v| diff_opts << "-a"}
opt.on('-b', '--ignore-space-change', common_opt_desc)                     {|v| diff_opts << "-b"}
opt.on('-w', '--ignore-all-space', common_opt_desc)                        {|v| diff_opts << "-w"}
opt.on('--ignore-submodules[=<when>', common_opt_desc)                     {|v| diff_opts << "--ignore-submodules"}

paths = ARGV.slice!(ARGV.index('--'), ARGV.length).join(' ') if ARGV.index('--')
opt.parse!(ARGV)
revision = ARGV.join(' ')


def parse_shortcut(revision, extra_diff_args, config, force_shortcut)  # {{{
  if %w(j k).include?(revision)
    tac = %x(which tac).empty? ? 'tail -r' : 'tac'
    last_shortcut = ENV[SHORTCUT_ENV_VAR] || %x(tail -n 400 $HISTFILE | #{tac} | command grep -E 'gitdiffall \d+' -m 1 -o | cut -d ' ' -f 2)
    if last_shortcut.empty? || last_shortcut == '!'
      puts "Can't find last shortcut"
      abort
    end

    case revision
    when 'j'
      shortcut = last_shortcut.to_i + 1
    when 'k'
      shortcut = last_shortcut.to_i - 1
      if shortcut < 1
        puts "End of shortcuts\nSHORTCUT:0"
        abort
      end
    end
    revision = shortcut.to_s
    puts "shortcut: #{last_shortcut} to #{shortcut}"
  end

  if revision[0] == '@'
    real_rev = revision[1..-1]
    if system("git rev-parse --quiet --verify #{real_rev} >/dev/null 2>&1")
      normailized = %x(git rev-parse #{real_rev}).chomp
      shortcut = %x(git log --format=format:"%H" \
                    #{extra_diff_args} | \
                    grep #{normailized} \
                    --max-count=1 --line-number)[/\d+/]

      if shortcut.nil?
        puts "REVISION:#{real_rev}..#{real_rev}^\n"\
             "SHORTCUT:!"
        abort
      end

      revision = shortcut.to_s
      puts "Shortcut for this commit is #{shortcut}"
    end
  end

  if revision =~ /\A\d+\z/ && (force_shortcut || revision.to_s.length < config[:min_hash_abbr])
    shortcut = revision
    rev = %x(git log -1 --skip=#{revision.to_i - 1} --format=format:"%h" #{extra_diff_args})
    revision = "#{rev}..#{rev}^"
    puts "REVISION:#{revision}\nSHORTCUT:#{shortcut}"
    abort
  end

  unless system("git rev-parse --quiet #{revision} >/dev/null 2>&1")
    puts "Failed parsing revision '#{revision}'"
    abort
  end
end  # }}}


def normailize_revision(revision)  # {{{
  revision.to_s.gsub(/@(?!@)/, 'HEAD').tap do |rev|
    return rev if system("git rev-parse --quiet #{rev} >/dev/null 2>&1")
  end
  return revision
end # }}}


# revision example:
#   (nil)       - see current (unstaged) changes
#   <commit>    - see current changes, compare with <commit>
#   @<commit>   - compare <commit> with it's first parent (<commit>^)
#   4 (number)  - shortcut for @<commit> where commit is the <number>-th previous one
#   j           - shortcut for 'next'     commit from last evaluated <number> shortcut
#   k           - shortcut for 'previous' commit from last evaluated <number> shortcut

if %x(git rev-parse --is-inside-work-tree) == 'false'
  puts 'Not inside a git working tree.'
  abort
elsif $?.exitstatus != 0
  abort
end

extra_diff_args = "#{diff_opts.join(' ')} #{paths}"

revision = normailize_revision(revision)

parse_shortcut(revision.to_s, extra_diff_args, config, detect_shortcut == true) unless detect_shortcut == false

if rev = revision.to_s.match(/([^.]+)\.\./).to_a.last
  detail, comment = %x(git cat-file commit #{rev}).split("\n\n", 2)
  parents = detail.lines.count { |line| line =~ /^parent/ }
  if parents > 1
    STDOUT.flush
    puts "\nCommit #{rev}:\n\n" <<
    "  #{comment.lines.to_a.shift}\n"
    print "has #{parents} parents, continue? (y/N) "
    STDOUT.flush
    if STDIN.gets.chomp != 'y'
      puts "Aborted."
      abort
    end
  end
end

diff_cmd = "git diff --name-only #{revision} #{use_cached} #{extra_diff_args}"
files = %x{#{diff_cmd}}.chomp.split.uniq

to_skip, to_keep = files.partition {|file|
  file.match(config[:ignore_pattern])
}
count = to_skip.length
if count > 0
  plural = count > 1 ? 's' : ''
  puts "File#{plural} to be ignored:"
  to_skip.each {|f| puts "  #{f}"}
  print "skip all #{count} file#{plural}? (Y/n) "
  STDOUT.flush
  unless STDIN.gets.chomp.downcase == 'n'
    files = to_keep
  end
end

count = files.length
if count > config[:max_files]
  print "Will open #{count} files, continue? (y/N) "
  STDOUT.flush
  if STDIN.gets.chomp != 'y'
    puts "Aborted."
    abort
  end
end

if count > 0
  pwd = Pathname.pwd
  toplevel = Pathname.new %x(git rev-parse --show-toplevel).chomp

  args = files.map {|file|
    (toplevel + (relative || pwd) + file).relative_path_from(toplevel + pwd)
  }.to_a

  system("#{config[:editor_cmd]} -p #{args.join(' ')} -c 'tabdo GitDiff #{revision} #{use_cached} #{extra_diff_args}' -c 'tabfirst'")
else
  puts 'no differences'
end

#!/usr/bin/env ruby

require 'optparse'
require 'pathname'
Version = '0.1.1'

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

opt = OptionParser.new
opt.banner = "Usage: gitdiffall [revision] [diff-options] [--] [<path>...]"
common_opt_desc = '(delegate to git)'

revision, diff_opts, paths = '', [], ''
use_cached, relative = '', ''

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

# revision example:
#   (nil)       - see current (unstaged) changes
#   <commit>    - see current changes, compare with <commit>
#   @<commit>   - compare <commit> with it's previous commit (liner shown in git log)
#   4 (number)  - shortcut for @<commit> where commit is the <number>-th previous one

if %x(git rev-parse --is-inside-work-tree) == 'false'
  puts 'Not inside a git working tree.'
  abort
elsif $?.exitstatus != 0
  abort
end

extra_diff_args = "#{diff_opts.join(' ')} #{paths}"

if String(revision).match(/^@\w+$/)
  shortcut = %x(git log --format=format:"%H" #{extra_diff_args} | grep #{revision[1..-1]} --max-count=1 --line-number)[/\d+/]
  if shortcut.nil?
    puts "unknown revesion #{revision[1..-1]}"
    abort
  end

  revision = shortcut
  puts "Shortcut for this commit is #{revision}.\n\n"
end

if revision.to_i.to_s == revision and revision.length < config[:min_hash_abbr]
  rev = %x(git log -1 --skip=#{revision.to_i - 1} --format=format:"%h" #{extra_diff_args})
  previous = %x(git log -1 --skip=#{revision} --format=format:"%h" #{extra_diff_args})
  revision = "#{rev}..#{previous}"
end

diff_cmd = "git diff --name-only #{revision} #{use_cached} #{extra_diff_args}"
files = %x{#{diff_cmd}}.chomp.split.uniq

unmerged = %x{#{diff_cmd} --diff-filter=U}.chomp.split
count = unmerged.length
if count > 0
  plural = count > 1 ? 's' : ''
  puts "Unmerged file#{plural}:"
  unmerged.each {|f| puts "  #{f}"}
  print "skip all #{count} file#{plural}? (Y/n) "
  STDOUT.flush
  case STDIN.gets.chomp.downcase
  when "n"
  else
    files = files - unmerged
  end
end

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

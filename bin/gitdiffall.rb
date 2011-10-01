#!/usr/bin/env ruby

require 'optparse'
Version = '0.0.1'

MAX_FILES = 14
MIN_HASH_ABBR = 5

opt =  OptionParser.new
opt.banner = "Usage: gitdiffall [revision] [diff-options] [--] [<path>...]"

revision, diff_opts, pathes = '', [], ''
use_cached = ''

opt.on('--cached', '--staged', '(delegate to git-diff)') {|v| use_cached = "--cached"}

opt.on('--no-renames', '(delegate to git-diff)') {|v| diff_opts << "--no-renames"}
opt.on('-B[<n>][/<m>]', '--break-rewrites[=[<n>][/<m>]]', '(delegate to git-diff)') {|v| diff_opts << "-B#{v}"}
opt.on('-M[<n>]', '--find-renames[=[<n>]]', '(delegate to git-diff)') {|v| diff_opts << "-M#{v}"}
opt.on('-C[<n>]', '--find-copies[=[<n>]]', '(delegate to git-diff)') {|v| diff_opts << "-C#{v}"}
opt.on('--find-copies-harder', '(delegate to git-diff)') {|v| diff_opts << "--find-copies-harder"}
opt.on('-D', '--irreversible-delete', '(delegate to git-diff)') {|v| diff_opts << "-D"}
opt.on('-l num', '(delegate to git-diff)') {|v| diff_opts << "-l #{v}"}
opt.on('--diff-filter=filter', '(delegate to git-diff)') {|v| diff_opts << "--diff-filter=#{v}"}
opt.on('-S[string]', '(delegate to git-diff)') {|v| diff_opts << "-S#{v}"}
opt.on('-G[regex]', '(delegate to git-diff)') {|v| diff_opts << "-G#{v}"}
opt.on('--pickaxe', '(delegate to git-diff)') {|v| diff_opts << "--pickaxe"}
opt.on('-O[orderfile]', '(delegate to git-diff)') {|v| diff_opts << "-O#{v}"}
opt.on('-R', '(delegate to git-diff)') {|v| diff_opts << "-R"}
opt.on('--relative[=path]', '(delegate to git-diff)') {|v| diff_opts << "--relative=#{v}"}
opt.on('-a', '--text', '(delegate to git-diff)') {|v| diff_opts << "-a"}
opt.on('-b', '--ignore-space-change', '(delegate to git-diff)') {|v| diff_opts << "-b"}
opt.on('-w', '--ignore-all-space', '(delegate to git-diff)') {|v| diff_opts << "-w"}
opt.on('--ignore-submodules[=<when>', '(delegate to git-diff)') {|v| diff_opts << "--ignore-submodules"}

pathes = ARGV.slice!(ARGV.index('--'), ARGV.length).join(' ') if ARGV.index('--')
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

extra_diff_args = "#{diff_opts.join(' ')} #{pathes}"

if String(revision).match(/^@\w+/)
  logs = %x(git log --format=format:"_" #{revision[1..-1]}.. #{extra_diff_args})
  if logs == ''
    puts 'no differences'
    abort
  end

  revision = logs.lines.to_a.length.to_s
  puts "Shortcut for this commit is #{revision}.\n\n"
end

if revision.to_i.to_s == revision and revision.length < MIN_HASH_ABBR
  rev = %x(git log -1 --skip=#{revision} --format=format:"%h" #{extra_diff_args})
  previous = %x(git log -1 --skip=#{revision.to_i + 1} --format=format:"%h" #{extra_diff_args})
  revision = "#{rev}..#{previous}"
end

files = %x{git diff --name-only #{revision} #{use_cached} #{extra_diff_args}}.chomp
count = files.lines.to_a.length

if count > MAX_FILES
  print "Will open #{count} files, continue? (y/N) "
  STDOUT.flush
  if STDIN.gets.chomp != 'y'
    puts "Aborted."
    abort
  end
end

if count > 0
  system("vim -p #{files.gsub(/\n/, ' ')} -c 'tabdo GitDiff #{revision} #{use_cached} #{extra_diff_args}' -c 'tabfirst'")
else
  puts '# Changes outside this directory are ignored' if %x(git rev-parse --show-prefix) != ''
  puts 'no differences'
end

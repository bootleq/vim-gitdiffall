#!/usr/bin/env ruby

require 'optparse'
Version = '0.0.1'

MAX_FILES = 14
MIN_HASH_ABBR = 5

opt =  OptionParser.new
opt.banner = "Usage: gitdiffall [range] [options]"
# TODO take arbitrary git-diff options
# opt.on('-c', '--cached', 'Use git-diff with --cached option') {|v| }
opt.parse!(ARGV)

# Range example:
#   (nil)       - see current (unstaged) changes
#   <commit>    - see current changes, compare with <commit>
#   @<commit>   - compare <commit> with it's previous commit (liner shown in git log)
#   4 (number)  - shortcut for @<commit> where commit is the <number>-th previous one
range = opt.default_argv.first

if %x(git rev-parse --is-inside-work-tree) == 'false'
  puts 'Not inside a git working tree.'
  abort
elsif $?.exitstatus != 0
  abort
end

if String(range).match(/^@\w/)
  range = %x(git log --format=format:"_" #{range[1..-1]}..).lines.to_a.length.to_s
  puts "Shortcut for this commit is #{range}.\n\n"
end

if range.to_i.to_s == range and range.length < MIN_HASH_ABBR
  rev = %x(git log -1 --skip=#{range} --format=format:"%h")
  previous = %x(git log -1 --skip=#{range.to_i + 1} --format=format:"%h")
  range = "#{rev}..#{previous}"
end

files = %x{git diff --name-only --relative #{range}}.chomp
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
  system("vim -p #{files.gsub(/\n/, ' ')} -c 'tabdo GitDiff #{range}' -c 'tabfirst'")
else
  puts '# Changes outside this directory are ignored' if %x(git rev-parse --show-prefix) != ''
  puts 'no differences'
end

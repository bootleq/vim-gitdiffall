gitdiffall
==========

View git diff in Vim tabs.

- `gitdiffall` function for zsh (**requires ruby** for running _gitdiffall.rb_).
- `GitDiff`, `GitDiffInfo`, `GitDiffOff` commands for Vim.


Install
=======

Install like general Vim plugins.


## Install Zsh Helper Function

- With [zplug][]

  ```zsh
  zplug "bootleq/vim-gitdiffall", use:"bin/*.zsh"
  ```

- Manual install

  1. Execute _install.zsh_ (will ask you for copying scripts to path).
  2. Source _path/to/gitdiffall.zsh_ in your _.zshrc_.

  ```zsh
  if [ -e ~/some_dir/gitdiffall.zsh ]; then
    source ~/some_dir/gitdiffall.zsh
  fi
  ```


Zsh Function Usage
==================

In zsh, use `gitdiffall` to open git diff in Vim tabs, examples:

- `gitdiffall`  diff current unstaged/staged changes, like `git diff`.
- `gitdiffall --cached` diff staged changes with HEAD.
- `gitdiffall dae86e` see all changes since commit "dae86e".
- `gitdiffall HEAD..HEAD~2` works like `git diff HEAD..HEAD~2`.

For convenience, some special notations are available:

- `gitdiffall @dae86e` expands to `dae86e^..dae86e`,  
  this is a shortcut for checking changes at specific commit.  
  Examples: `@@~2` (HEAD~2), `@stash@{0}` (stashed entry), `@master` (last commit at master branch).

- `gitdiffall 1`  is similar to `@<rev>`, where `<rev>` is the *1*st previous commit from HEAD.  
  You can increase the digit for older commits.

- `gitdiffall j` and `gitdiffall k` shortcut to _next_/_previous_ commit from last evaluated `gitdiffall <n>`.  
  (this uses environment variable `$_GITDIFFALL_LAST_SHORTCUT` to remember last eval)

During merge conflicts, `gitdiffall` will open a 3-way diff in Vim.


Zsh Function Configuration
==========================

gitdiffall.rb takes configure file from one of the following:

- `~/gitdiffall/config.rb`
- `~/gitdiffall-config.rb`
- `{dir_contains_gitdiffall.rb}/gitdiffall/config.rb`
- `{dir_contains_gitdiffall.rb}/gitdiffall-config.rb`

Supported config items:

- `editor_cmd` (default: "vim")  
  Command to execute Vim.
- `max_files` (default: 14)  
  Wait for confirmation before open such many files.
- `min_hash_abbr` (default: 5)  
  When performing `gitdiffall <n>`,
  `<n>` must have this many digits to indicate a hash,
  otherwise it's a number.
- `ignore_pattern` (default: `/\.(png|jpg)\Z/i`)  
  Files match this pattern will not be sent to Vim.

Example `config.rb`:

```ruby
CONFIG = {
  :editor_cmd     => "vim -u /some/other/vimrc",
  :max_files      => 14,
  :min_hash_abbr  => 5,
  :ignore_pattern => /(\.(png|jpg)|-compressed\.js)\Z/i
}
```


Tips
====

In tmux copy mode, select some commit hash and press `>` to do gitdiffall in
new tmux window, see [tmux-in.rb][] gist.

```
bind -t vi-copy > copy-pipe "~/.tmux-in.rb gitdiffall"
```



[tmux-in.rb]: https://gist.github.com/bootleq/786cb41a8072e537467e
[zplug]: http://zplug.sh/

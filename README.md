gitdiffall
==========

View git diff in Vim tabs.

- `gitdiffall` command for zsh (**requires ruby** for running _gitdiffall.rb_).
- `GitDiff`, `GitDiffInfo`, `GitDiffOff` commands for Vim.


Install
=======

1. Install like general Vim plugins.
2. Execute _install.zsh_ (will ask you for copying scripts).
3. Source _path/to/gitdiffall.zsh_ in your _.zshrc_.

    ```
    if [ -e ~/some_dir/gitdiffall.zsh ]; then
      source ~/some_dir/gitdiffall.zsh
    fi
    ```

Usage
=====

In zsh, use `gitdiffall` to open git diff in Vim tabs, examples:

- `gitdiffall`  diff current unstaged/staged changes, like `git diff`.
- `gitdiffall --cached` diff staged changes with HEAD.
- `gitdiffall dae86e` see all changes since commit "dae86e".
- `gitdiffall HEAD^..HEAD~2` works like `git diff HEAD..HEAD~2`.

For convenience, some special notations are available:

- `gitdiffall @dae86e`  will be expanded to `<previous-rev>..dae86e`,  
  where `<previous-rev>` is the previous entry of "dae86e" in `git log` (may be different to `dae86e^`).  
  This is a shrotcut for checking changes in a specified commit.
- `gitdiffall 1`  is similar to `@<rev>`,  
  where `<rev>` is the nth previous commit from HEAD, starts from 1.

You can specified `@<rev>` for the oldest commit you care about,  
the shortcut number `<n>` of that commit will be shown in command line.  
Later you can use `gitdiffall <n-1>`, `gitdiffall <n-2>`, ..., to walk through every newer commit.

Configuration
=============

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

    CONFIG = {
      :editor_cmd     => "vim -u /some/other/vimrc",
      :max_files      => 14,
      :min_hash_abbr  => 5,
      :ignore_pattern => /(\.(png|jpg)|-compressed\.js)\Z/i
    }

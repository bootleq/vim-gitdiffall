CHANGES
=======

## 1.0.0 (2014-10-04)

* **CHANGE** meaning of "_previous_" commit for `gitdiffall @{commit}`, `gitdiffall <n>` shortcuts.  
  "_previous_" is used to say previous linear commit shown in git log,
  and has changed to first parent of current commit (i.e., `commit^`).
* Start 3-way merge during unmerged conflicts.
* Better `GitDiffInfo` display, with Vim's preview window.
* Add `gitdiffall j`, `gitdiffall k` shortcuts.
* Add `log_format`, `rebase_log_format` and `keep_info_window` options.
* gitdiffall.rb can skip a merge commit before open Vim.

## 0.1.1 (2011-12-03)

* gitdiffall.rb can skip unmerged files before send them to Vim.
* Some improvements of `--cached` option.

## 0.1.0 (2011-11-26)

* First release version.

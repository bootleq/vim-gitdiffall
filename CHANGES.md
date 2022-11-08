CHANGES
=======

## Unreleased

* For a `dos` format file, open the diff buffer with also dos fileformat.

## 1.3.1 (2020-04-04)

* Do additional diffupdate to cover autocmd in edge case.

## 1.3.0 (2017-10-19)

* Add `min_hash_abbr` option.

## 1.2.0 (2016-06-05)

* Easier integration with zplug.

## 1.1.0 (2016-05-08)

* Restore window layout after close `DiffInfo` preview.
* View commit in other branch, stash is also supported.
* Fix script compatibility problems on Mac (BSD based).

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

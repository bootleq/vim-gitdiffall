if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpo
set cpoptions&vim

" Commitish {{{
syntax match  GitDiffInfo_CommitishQuote "'" conceal contained
syntax region GitDiffInfo_Commitish      start=/\v'\ze%(\w|-)+\^?'/ end=/'/ contained keepend contains=GitDiffInfo_Commitish.*
" }}}


" Header {{{
syntax match GitDiffInfo_HeaderStatus /\v\(\c%(conflict|staged|wip)\)/ contained
syntax match GitDiffInfo_HeaderStatus /\v\+\d+\s+$/ contained
syntax match GitDiffInfo_Header       /\%1l.*/ contains=GitDiffInfo_Header.*,GitDiffInfo_Commitish
" }}}


" Rebasing {{{
syntax match  GitDiffInfo_RebaseTodoCommit /\(^*\?\s\{,2\}\k\+\s\)\@<=\w\+/ contained
syntax match  GitDiffInfo_RebaseTodoAction /\v^%(\*\s|\s{2})\k+/ contained nextgroup=GitDiffInfo_RebaseTodoCommit
syntax region GitDiffInfo_RebaseTodo       start=/\%3l\*\?\s/ end=/^\n/ keepend contains=GitDiffInfo_RebaseTodo.*
" }}}


" Log Meta {{{
syntax match  GitDiffInfo_LogMetaCommit /\v^commit\s\w{7}$/ contained containedin=GitDiffInfo_LogMeta
syntax match  GitDiffInfo_LogMetaMerge /\v^Merge:\s+.+$/  containedin=GitDiffInfo_LogMeta
syntax match  GitDiffInfo_LogMetaAuthor /\v^Author:\s+.+$/  containedin=GitDiffInfo_LogMeta
syntax match  GitDiffInfo_LogMetaDate   /\v^Date:\s+.+$/    containedin=GitDiffInfo_LogMeta
syntax region GitDiffInfo_LogMeta       start=/^commit\s\w/ end=/^Date:\s.*$/ keepend contains=GitDiffInfo_Commitish
" }}}


" HunkHead {{{
syntax match GitDiffInfo_HunkHead /\v^%(\>|\<){6} \w+/
" }}}


highlight default link GitDiffInfo_Header           Comment
highlight default link GitDiffInfo_HeaderStatus     PreProc
highlight default link GitDiffInfo_RebaseTodoAction Statement
highlight default link GitDiffInfo_RebaseTodoCommit Title
highlight default link GitDiffInfo_LogMeta          Comment
highlight default link GitDiffInfo_LogMetaMerge     Normal
highlight default link GitDiffInfo_LogMetaAuthor    Normal
highlight default link GitDiffInfo_LogMetaDate      Conceal
highlight default link GitDiffInfo_LogMetaCommit    Title
highlight default link GitDiffInfo_Commitish        Title
highlight default link GitDiffInfo_HunkHead         Comment

let b:current_syntax = 'gitdiffallinfo'


" Finish:  {{{

let &cpoptions = s:save_cpo
unlet s:save_cpo

" }}} Finish

" modeline {{{
" vim: expandtab softtabstop=2 shiftwidth=2 foldmethod=marker

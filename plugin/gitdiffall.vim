if exists('g:loaded_gitdiffall')
  finish
endif
let g:loaded_gitdiffall = 1
let s:save_cpo = &cpoptions
set cpoptions&vim


" Interface: {{{

if !exists('*GitDiff')
  command -nargs=? -complete=custom,gitdiffall#complete GitDiff call gitdiffall#diff([<f-args>])
endif

if !exists('*GitDiffInfo')
  command -nargs=? -complete=custom,gitdiffall#info_complete GitDiffInfo call gitdiffall#info([<f-args>])
endif

if !exists('*GitDiffOff')
  command GitDiffOff call gitdiffall#diffoff()
endif

" }}} Interface


" Finish:  {{{

let &cpoptions = s:save_cpo
unlet s:save_cpo

" }}} Finish


" modeline {{{
" vim: expandtab softtabstop=2 shiftwidth=2 foldmethod=marker

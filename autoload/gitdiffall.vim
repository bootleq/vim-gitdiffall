" Constants: {{{

let s:DIFF_OPTION_KEYS = [
      \   'diff',
      \   'foldcolumn',
      \   'foldmethod',
      \   'cursorbind',
      \   'scrollbind',
      \   'scrollopt',
      \   'wrap',
      \ ]

let s:COMPLETE_HASH_SIZE = 30

" }}} Constants


" Main Functions: {{{

function! gitdiffall#diff(args) "{{{
  if exists('t:gitdiffall_info')
    call gitdiffall#info([])
    return
  endif

  let range = empty(a:args) ? '' : a:args[0]
  let MIN_HASH_ABBR = 5
  call insert(s:complete_cache().recent, range)

  if stridx(range, '..') != -1
    let [begin_rev, rev] = split(range, '\V..', 1)
  elseif range =~ '^@\w'
    let rev = s:shortcut_for_commit(range)
    echo printf("Shortcut for this commit is %s.", rev)
  else
    let rev = range
  endif

  if string(str2nr(rev)) == rev && len(string(rev)) < MIN_HASH_ABBR
    let begin_rev = system('git log -1 --skip=' . rev . ' --format=format:"%h"')
    let rev = system('git log -1 --skip=' . (rev + 1) . ' --format=format:"%h"')
  endif

  let save_file = expand('%')
  let save_filetype = &filetype
  let save_dir = getcwd()
  let new_dir = fnameescape(expand('%:p:h'))
  let cd_command = haslocaldir() ? 'lcd' : 'cd'
  call s:save_diff_options()

  if isdirectory(new_dir)
    execute cd_command . " " . new_dir
  endif

  let prefix = substitute(system("git rev-parse --show-prefix"), '\n$', '', '')
  let filepath = expand('%:.')

  let rev_content = s:get_content(rev, prefix . filepath)
  if exists('begin_rev')
    let begin_rev_content = s:get_content(begin_rev, prefix . filepath)
  endif
  execute cd_command . " " . save_dir

  redraw!

  if exists('begin_rev')
    execute 'enew'
    silent execute 'file ' . escape(s:uniq_bufname(
          \   printf(
          \     '%s (%s)',
          \     prefix . filepath,
          \     begin_rev
          \   )
          \ ), ' \')
    call s:fill_buffer(begin_rev_content, save_filetype)
  endif

  execute 'vertical new'
  silent execute 'file ' . escape(s:uniq_bufname(
        \   printf(
        \     '%s (%s)',
        \     prefix . '[git diff] ' . filepath,
        \     rev
        \   )
        \ ), ' \')
  call s:fill_buffer(rev_content, save_filetype)

  if rev_content.success && (!exists('begin_rev') || begin_rev_content.success)
    windo diffthis
  endif
  wincmd p

  let t:gitdiffall_info = {
        \   'args': empty(a:args) ? '' : a:args[0],
        \   'begin_rev': exists('begin_rev') ? begin_rev : 0,
        \   'rev': rev,
        \   'file': save_file,
        \ }
endfunction "}}}


function! gitdiffall#info(args) "{{{
  if !exists('t:gitdiffall_info')
    echo 'No GitDiff info on this tab.'
    return
  endif

  let key = empty(a:args) ? 'default' : a:args[0]
  let [begin_rev, rev] = [t:gitdiffall_info.begin_rev, t:gitdiffall_info.rev]
  let info = t:gitdiffall_info

  if !has_key(info, key)
    if key == 'default'
      let info[key] = system('git log -1 ' . (empty(begin_rev) ? rev : begin_rev))
    elseif key == 'logs'
      let info[key] = system(
            \   "git log "
            \   . (empty(begin_rev) ? (rev . '..') : (rev . '..' . begin_rev))
            \ )
    endif
  endif

  if !has_key(info, key)
    echo 'Unsupported option "' . key . '", aborted.'
  else
    echo join([
          \   'GitDiff: ',
          \   info.args,
          \   "        ",
          \   (empty(begin_rev) ? '(wip)' : begin_rev) . " " . rev,
          \   "\n\n",
          \   info[key],
          \ ], '')
  endif
endfunction "}}}


function! gitdiffall#diffoff() "{{{
  if exists('t:gitdiffall_info')
    if fnamemodify(bufname("%"), ':t') =~ '^\[git diff]' && tabpagewinnr(tabpagenr(), '$') > 1
      wincmd q
    endif
    silent only

    execute 'edit ' . t:gitdiffall_info.file
    call s:restore_diff_options()
    unlet t:gitdiffall_info
  endif
endfunction "}}}

" }}} Main Functions


" Complete Functions: {{{

function! gitdiffall#complete(arglead, cmdline, cursorpos) "{{{
  let recent_size = 10
  let hash_size = s:COMPLETE_HASH_SIZE
  let objects = s:complete_cache()

  let objects.recent = s:uniq(objects.recent)[:(recent_size - 1)]

  let git_toplevel = system('git rev-parse --show-toplevel')
  if !exists('s:git_toplevel') || s:git_toplevel != git_toplevel
    let objects.tags = split(
          \   system('git tag -l'),
          \   "\n"
          \ )
    let objects.hashes = split(
          \   system('git log -n ' . hash_size . ' --format=format:"%h"'),
          \   "\n"
          \ )
  endif
  let s:git_toplevel = git_toplevel

  let candidates = 
        \   objects.recent +
        \   objects.default +
        \   objects.tags +
        \   objects.hashes

  return join(s:uniq(candidates), "\n")
endfunction "}}}


function! gitdiffall#info_complete(arglead, cmdline, cursorpos) "{{{
  return join([
        \   'logs', 'default',
        \ ], "\n")
endfunction "}}}


function! s:complete_cache() "{{{
  if !exists('s:complete_cache_hash')
    let s:complete_cache_hash = {
          \   'recent': [],
          \   'default': ['HEAD'],
          \   'tags': [],
          \   'hashes': [],
          \ }
  endif
  return s:complete_cache_hash
endfunction "}}}

" }}} Complete Functions


" Utils: {{{

function! s:shortcut_for_commit(rev) "{{{
  return len(
        \   split(
        \     system('git log --format=format:"%h" ' . strpart(a:rev, 1) . '..'),
        \   )
        \ )
endfunction "}}}


function! s:get_content(rev, file) "{{{
  " TODO :<n>:<path>, see gitrevisions(7)
  let result = system("git show " . (empty(a:rev) ? 'HEAD' : a:rev) . ":" . shellescape(a:file))
  if v:shell_error
    let result = substitute(result, '[\n]', ' ', 'g')
  endif
  return {
        \   'text': result,
        \   'success': !v:shell_error
        \ }
endfunction "}}}


function! s:fill_buffer(content, filetype) "{{{
  silent put=a:content.text | 0delete _
  if a:content.success
    execute 'setlocal filetype=' . a:filetype
  endif
  setlocal noswapfile buftype=nofile bufhidden=wipe
endfunction "}}}


function! s:save_diff_options() "{{{
  let b:save_diff_options = {}
  for key in s:DIFF_OPTION_KEYS
    let b:save_diff_options[key] = getbufvar('%', '&l:' . key)
  endfor
endfunction "}}}


function! s:restore_diff_options() "{{{
  if exists('b:save_diff_options')
    for key in s:DIFF_OPTION_KEYS
      call setbufvar(
            \   '%',
            \   '&' . key,
            \   b:save_diff_options[key]
            \ )
    endfor
    unlet b:save_diff_options
  endif
endfunction "}}}


function! s:uniq_bufname(name) "{{{
  let name = a:name
  while bufnr(name) != -1
    " \v(\((\d)\))?$
    " has submatch 1: \(\d\)$
    "     submatch 2: \d
    let name = substitute(
          \   name,
          \   '\v(\((\d)\))?$',
          \   '\= (len(submatch(1)) ? "" : " ") . "(" . (submatch(2) + 1) . ")"',
          \   ''
          \ )
  endwhile
  return name
endfunction "}}}


function! s:chomp(string, ...) "{{{
  let separator = a:0 ? a:1 : "\n"
  let pattern = (separator == "\n") ? '(\r|\n|\r\n)' : separator
  return substitute(
        \   a:string,
        \   '\v' . pattern . '$',
        \   '',
        \   ''
        \ )
endfunction "}}}


function! Uniq(list) "{{{
  let list = []
  for i in a:list
    if index(list, i) < 0
      call add(list, i)
    endif
  endfor
  return list
endfunction "}}}

" }}} Utils

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
let s:REV_UNDEFINED = -1
let s:OPTIONS = [
      \   '--cached',
      \   '--no-renames', '--diff-filter=',
      \   '-S', '-G',
      \   '--ignore-space-change', '--ignore-all-space', '--ignore-submodules',
      \ ]

" }}} Constants


" Main Functions: {{{

function! gitdiffall#diff(args) "{{{
  if exists('t:gitdiffall_info')
    call gitdiffall#info(['log'])
    return
  endif

  let [revision, use_cached, diff_opts, paths] = s:parse_options(a:args)

  try
    let [begin_rev, rev] = s:parse_revision(revision, use_cached, diff_opts, paths)
  catch /^gitdiffall:/
    echoerr printf("%s (%s)",
          \   substitute(v:exception, '^gitdiffall:', '', ''),
          \   v:throwpoint
          \ )
    return
  endtry

  let save_file = expand('%')
  let save_filetype = &filetype
  call s:save_diff_options()

  call s:cd_to_current_head()
  let prefix = s:get_prefix()
  let relative_path = expand('%:.')

  let rev_content = s:get_content(rev, prefix . relative_path)
  if begin_rev != s:REV_UNDEFINED
    let begin_rev_content = s:get_content(begin_rev, prefix . relative_path)
  endif
  call s:cd_to_original()

  if begin_rev != s:REV_UNDEFINED
    execute 'enew'
    silent execute 'file ' . escape(s:uniq_bufname(
          \   printf(
          \     '%s (%s)',
          \     prefix . relative_path,
          \     use_cached ? 'staged' : begin_rev
          \   )
          \ ), ' \')
    call s:fill_buffer(begin_rev_content, save_filetype)
  endif

  execute 'vertical new'
  silent execute 'file ' . escape(s:uniq_bufname(
        \   printf(
        \     '%s (%s)',
        \     prefix . '[git diff] ' . relative_path,
        \     rev
        \   )
        \ ), ' \')
  call s:fill_buffer(rev_content, save_filetype)

  if rev_content.success && (begin_rev == s:REV_UNDEFINED || begin_rev_content.success)
    windo diffthis
  endif
  wincmd p

  let t:gitdiffall_info = {
        \   'args': empty(a:args) ? '' : join(a:args),
        \   'diff_opts': diff_opts,
        \   'paths': paths,
        \   'begin_rev': begin_rev,
        \   'rev': rev,
        \   'file': save_file,
        \ }
endfunction "}}}


function! gitdiffall#info(args) "{{{
  if !exists('t:gitdiffall_info')
    echo 'No GitDiff info on this tab.'
    return
  endif

  let key = empty(a:args) ? 'logs' : a:args[0]
  let info = t:gitdiffall_info
  let [begin_rev, rev] = [info.begin_rev, info.rev]

  if !has_key(info, key)
    if key == 'log'
      let info[key] = system(printf(
            \   'git log -1 %s %s -- %s',
            \   begin_rev == s:REV_UNDEFINED ? rev : begin_rev,
            \   info.diff_opts,
            \   info.paths
            \ ))
    elseif key == 'logs'
      let info[key] = system(printf(
            \   'git log %s %s -- %s',
            \   begin_rev == s:REV_UNDEFINED ? (rev . '..') : (rev . '..' . begin_rev),
            \   info.diff_opts,
            \   info.paths
            \ ))
    endif
  endif

  if !has_key(info, key)
    echo 'Unsupported option "' . key . '", aborted.'
  else
    echo join([
          \   'GitDiff: ',
          \   info.args,
          \   "        ",
          \   (begin_rev == s:REV_UNDEFINED ? '(wip)' : begin_rev) . " " . rev,
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

    if t:gitdiffall_info.file != expand('%')
      execute 'edit ' . t:gitdiffall_info.file
    endif

    call s:restore_diff_options()
    unlet t:gitdiffall_info
  endif
endfunction "}}}

" }}} Main Functions


" Complete Functions: {{{

function! gitdiffall#complete(arglead, cmdline, cursorpos) "{{{
  if type(a:arglead) == type(0) || stridx(a:arglead, '-') == 0
    return join(s:OPTIONS, "\n")
  endif

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
        \ objects.recent +
        \ objects.default +
        \ objects.tags +
        \ objects.hashes

  return join(s:uniq(candidates), "\n")
endfunction "}}}


function! gitdiffall#info_complete(arglead, cmdline, cursorpos) "{{{
  return join([
        \   'logs', 'log',
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


" Git Operations: {{{

function! s:merge_base_of(begin_rev, rev) "{{{
  let rev = system('git merge-base ' . a:begin_rev . ' ' . a:rev)[0:6])
  call s:throw_shell_error()
  return rev[0:6]
endfunction "}}}


function! s:get_prefix() "{{{
  return substitute(system("git rev-parse --show-prefix"), '\n$', '', '')
endfunction "}}}


function! s:shortcut_for_commit(rev, ...) "{{{
  let option_args = a:0 ? a:1 : ''
  let path_args = a:0 > 1 ? a:2 : ''
  let shortcut = matchstr(
        \   system(printf(
        \     'git log --format=format:"%s" %s -- %s | grep %s --max-count=1 --line-number',
        \     '%H',
        \     option_args,
        \     path_args,
        \     a:rev
        \   )),
        \   '\v\d+'
        \ )
  if v:shell_error == 1
    throw "gitdiffall:Unknown revision: " . a:rev
  endif
  call s:throw_shell_error(2)
  return shortcut
endfunction "}}}


function! s:get_content(rev, file) "{{{
  " TODO use :<n>:<path> as rev, see gitrevisions(7)
  let result = system(printf(
        \   "git show %s:%s",
        \   empty(a:rev) ? 'HEAD' : a:rev,
        \   shellescape(a:file)
        \ ))
  if v:shell_error
    let result = substitute(result, '[\n]', ' ', 'g')
  endif
  return {
        \   'text': result,
        \   'success': !v:shell_error
        \ }
endfunction "}}}

" }}} Git Operations


" Utils: {{{

function! s:parse_options(args) "{{{
  let end_of_opts = index(a:args, '--')
  let paths = end_of_opts < 0 ? [] : a:args[(end_of_opts + 1):]
  let other_args = end_of_opts < 0 ? a:args : a:args[:max([0, end_of_opts - 1])]

  let revision = []
  let diff_opts = []
  let use_cached = 0
  for arg in other_args
    if arg =~ '^-'
      if arg == '--cached' || arg == '--staged'
        let use_cached = 1
      else
        call add(diff_opts, arg)
      endif
    elseif empty(diff_opts)
      call add(revision, arg)
    endif
  endfor
  if len(revision) > 1
    let revision = [split(revision[0], '\V..', 1)[0], split(revision[-1], '\V..', 1)[-1]]
  endif
  return [
        \   join(revision),
        \   use_cached,
        \   join(diff_opts),
        \   join(paths)
        \ ]
endfunction "}}}


function! s:parse_revision(revision, use_cached, ...) "{{{
  let diff_opts = a:0 ? a:1 : ''
  let paths = a:0 > 1 ? a:2 : ''
  let begin_rev = s:REV_UNDEFINED
  let rev = a:revision

  let MIN_HASH_ABBR = 5
  call insert(s:complete_cache().recent, a:revision)

  if a:use_cached
    let begin_rev = ''
    let rev = 'HEAD'
  elseif stridx(a:revision, '...') != -1
    let [begin_rev, rev] = split(a:revision, '\V...', 1)
    let begin_rev = s:merge_base_of(begin_rev, rev)
  elseif stridx(a:revision, '..') != -1
    let [begin_rev, rev] = split(a:revision, '\V..', 1)
  elseif a:revision =~ '\v^\@\w+$'
    let rev = s:shortcut_for_commit(strpart(a:revision, 1), diff_opts, paths)
    echo printf("Shortcut for this commit is %s.", rev)
  elseif a:revision =~ '\v\+\d+$'
    let rev = strpart(a:revision, 1)
    let paths .= ' ' . expand('%')
  endif

  if string(str2nr(rev)) == rev && len(rev) < MIN_HASH_ABBR
    let begin_rev = system(printf('git log -1 --skip=%s --format=format:"%s" %s -- %s',
          \   rev - 1,
          \   "%h",
          \   diff_opts,
          \   paths
          \ ))
    let rev = system(printf('git log -1 --skip=%s --format=format:"%s" %s -- %s',
          \   rev,
          \   "%h",
          \   diff_opts,
          \   paths
          \ ))
  endif

  return [begin_rev, rev]
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


function! s:cd_to_current_head() "{{{
  let s:save_dir = getcwd()
  let new_dir = fnameescape(expand('%:p:h'))
  let cd_command = haslocaldir() ? 'lcd' : 'cd'
  if isdirectory(new_dir)
    execute cd_command . " " . new_dir
  endif
endfunction "}}}


function! s:cd_to_original() "{{{
  let cd_command = haslocaldir() ? 'lcd' : 'cd'
  execute cd_command . " " . s:save_dir
endfunction "}}}


function! s:throw_shell_error(...) "{{{
  let code = a:0 ? 2 : 1
  if v:shell_error >= code
    throw "gitdiffall:shell exception: " . v:exception . " -- " . v:throwpoint
  else
    return 0
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


function! s:uniq(list) "{{{
  let list = []
  for i in a:list
    if index(list, i) < 0
      call add(list, i)
    endif
  endfor
  return list
endfunction "}}}

" }}} Utils

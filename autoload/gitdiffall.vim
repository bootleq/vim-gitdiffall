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
let s:STATUS_ONLY_WIDTH = 16
let s:STATUS_ONLY_CONTENT = {
      \   'A': 'file added',
      \   'D': 'file deleted'
      \ }

" }}} Constants


" Main Functions: {{{

function! gitdiffall#diff(args) "{{{
  if exists('t:gitdiffall_info')
    call gitdiffall#info(['log'])
    return
  endif

  let [revision, use_cached, diff_opts, paths] = s:parse_options(a:args)

  try
    let [rev_at, rev_aside] = s:parse_revision(revision, use_cached, diff_opts, paths)
  catch /^gitdiffall:/
    echoerr printf("%s (%s)",
          \   substitute(v:exception, '^gitdiffall:', '', ''),
          \   v:throwpoint
          \ )
    return
  endtry

  let save_file = expand('%')
  let save_filetype = &filetype
  if version < 704
    call s:save_diff_options()
  endif

  call s:cd_to_current_head()
  let prefix = s:get_prefix()
  let relative_path = expand('%:.')
  let path = prefix . relative_path

  if use_cached
    let diff_status = s:get_diff_status('--cached', relative_path)
    let rev_at_content = index(['D'], diff_status) > -1 ?
          \ s:get_diff_status_content(diff_status, path) :
          \ s:get_content(':0', path, 'staged')
    let rev_aside_content = index(['A'], diff_status) > -1 ?
          \ s:get_diff_status_content(diff_status, path) :
          \ s:get_content(empty(rev_aside) ? 'HEAD' : rev_aside, path, 'staged')
  else
    if rev_at != s:REV_UNDEFINED
      let diff_status = s:get_diff_status([rev_at, rev_aside], relative_path)
      let rev_at_content = index(['D'], diff_status) > -1 ?
            \ s:get_diff_status_content(diff_status, path) :
            \ s:get_content(rev_at, path)
    else
      let diff_status = s:get_diff_status('', relative_path)
    endif

    if index(['D'], diff_status) > -1
      let rev_at_content = s:get_diff_status_content(diff_status, path)
    endif

    let rev_aside_content = index(['A'], diff_status) > -1 ?
          \ s:get_diff_status_content(diff_status, path) :
          \ s:get_content(
          \   rev_aside,
          \   path,
          \   rev_at == s:REV_UNDEFINED ? 'HEAD' : ''
          \ )
  end

  call s:cd_to_original()
  call s:split_window(
        \   exists('rev_at_content') ?
        \     rev_at_content :
        \     (rev_at == s:REV_UNDEFINED ? s:REV_UNDEFINED : ''),
        \   rev_aside_content,
        \   save_filetype
        \ )

  let t:gitdiffall_info = {
        \   'args': empty(a:args) ? '' : join(a:args),
        \   'diff_opts': diff_opts,
        \   'use_cached': use_cached,
        \   'paths': paths,
        \   'rev_at': rev_at,
        \   'rev_aside': rev_aside,
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
  let [rev_at, rev_aside] = [info.rev_at, info.rev_aside]
  let format = exists('g:gitdiffall_log_format') ? printf("--format='%s'", g:gitdiffall_log_format) : ''

  if !has_key(info, key)
    if key == 'log'
      let info[key] = system(printf(
            \   'git log -1 %s %s %s -- %s',
            \   rev_at == s:REV_UNDEFINED ? rev_aside : rev_at,
            \   info.diff_opts,
            \   format,
            \   info.paths
            \ ))
    elseif key == 'logs'
      let info[key] = system(printf(
            \   'git log %s %s %s -- %s',
            \   rev_at == s:REV_UNDEFINED ? (rev_aside . '..') : (rev_aside . '..' . rev_at),
            \   info.diff_opts,
            \   format,
            \   info.paths
            \ ))
    endif
  endif

  if !has_key(info, key)
    echo 'Unsupported option "' . key . '", aborted.'
  else
    let rev_at_display = info.use_cached ? '(staged)' :
          \ rev_at == s:REV_UNDEFINED ? '(wip)' : rev_at
    echo join([
          \   'GitDiff: ',
          \   info.args,
          \   "        ",
          \   rev_at_display . " " . rev_aside,
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
      let pos = getpos('.')
      execute 'edit ' . t:gitdiffall_info.file
      if line("'\"") < 2
        call setpos('.', pos)
      endif
    endif

    if version >= 704
      if &diff
        diffoff
      endif
    else
      call s:restore_diff_options()
    endif

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

function! s:merge_base_of(rev_at, rev_aside) "{{{
  let rev = system('git merge-base ' . a:rev_at . ' ' . a:rev_aside)[0:6])
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


function! s:get_diff_status(revs, path) "{{{
  if type(a:revs) == type([])
    let compare = printf(
          \   '%s..%s',
          \   get(a:revs, 1),
          \   get(a:revs, 0)
          \ )
  else
    let compare = a:revs
  endif

  let result = system(printf(
        \   "git diff --name-status %s -- %s",
        \   compare,
        \   a:path
        \ ))
  return result[0]
endfunction "}}}


function! s:get_content(rev, file, ...) "{{{
  let file_desc = a:0 ? a:1 : ''

  " TODO use :<n>:<path> as rev, see gitrevisions(7)
  let result = system(printf(
        \   "git show %s:%s",
        \   a:rev,
        \   shellescape(a:file)
        \ ))
  if v:shell_error
    let result = substitute(result, '[\n]', ' ', 'g')
  endif

  let name = printf(
        \   '%s (%s)',
        \   a:file,
        \   empty(file_desc) ? a:rev : file_desc
        \ )

  return {
        \   'text': result,
        \   'success': !v:shell_error,
        \   'name': name,
        \   'no_file': 0
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
  let rev_at = s:REV_UNDEFINED
  let rev_aside = a:revision

  let MIN_HASH_ABBR = 5
  call insert(s:complete_cache().recent, a:revision)

  if a:use_cached
    " don't alter revisions here.
  elseif stridx(a:revision, '...') != -1
    let [rev_at, rev_aside] = split(a:revision, '\V...', 1)
    let rev_at = s:merge_base_of(rev_at, rev_aside)
  elseif stridx(a:revision, '..') != -1
    let [rev_at, rev_aside] = split(a:revision, '\V..', 1)
  elseif a:revision =~ '\v^\@\w+$'
    let rev_aside = s:shortcut_for_commit(strpart(a:revision, 1), diff_opts, paths)
    echo printf("Shortcut for this commit is %s.", rev_aside)
  elseif a:revision =~ '\v\+\d+$'
    let rev_aside = strpart(a:revision, 1)
    let paths .= ' ' . expand('%')
  endif

  if string(str2nr(rev_aside)) == rev_aside && len(rev_aside) < MIN_HASH_ABBR
    let rev_at = system(printf('git log -1 --skip=%s --format=format:"%s" %s -- %s',
          \   rev_aside - 1,
          \   "%h",
          \   diff_opts,
          \   paths
          \ ))
    let rev_aside = system(printf('git log -1 --skip=%s --format=format:"%s" %s -- %s',
          \   rev_aside,
          \   "%h",
          \   diff_opts,
          \   paths
          \ ))
  endif

  return [rev_at, rev_aside]
endfunction "}}}


function! s:fill_buffer(content, filetype) "{{{
  silent put=a:content.text | 0delete _
  if a:content.success
    let filetype = a:content.no_file ? 'help' : a:filetype
    execute 'setlocal filetype=' . filetype
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


function! s:get_diff_status_content(status, path) "{{{
  if has_key(s:STATUS_ONLY_CONTENT, a:status)
    let content = printf(
          \   "\n- Nothing -~\n\n(%s)",
          \   get(s:STATUS_ONLY_CONTENT, a:status, '')
          \ )
  endif
  return {
        \   'text': content,
        \   'success': !empty(content),
        \   'name': printf('%s (%s)', a:path, a:status),
        \   'no_file': 1
        \ }
endfunction "}}}


function! s:split_window(at, aside, filetype) "{{{
  if type(a:at) == type({})
    execute 'enew'
    silent execute 'file ' . escape(s:uniq_bufname(a:at.name), ' \')
    call s:fill_buffer(a:at, a:filetype)
  endif

  execute 'vertical new'

  if type(a:at) == type({}) && a:at.no_file
    execute 'wincmd p | vertical resize ' . s:STATUS_ONLY_WIDTH . ' | wincmd p'
  elseif a:aside.no_file
    execute 'vertical resize ' . s:STATUS_ONLY_WIDTH
  endif

  silent execute 'file ' . escape(s:uniq_bufname(a:aside.name), ' \')
  call s:fill_buffer(a:aside, a:filetype)

  if a:aside.success && !a:aside.no_file && (
        \ type(a:at) == type({}) ?
        \   (!a:at.no_file && a:at.success) :
        \   (a:at == s:REV_UNDEFINED)
        \ )
    windo diffthis
  endif
  wincmd p
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

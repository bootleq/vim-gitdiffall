if [[ -z "$script_dir" ]]; then
  local script_dir=$HOME/bin/
fi

function gitdiffall () {
  ruby ${script_dir}gitdiffall.rb $*
}

function _gitdiffall () {
  if [[ -z "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]]; then
    _message 'not a git repository'
    return 1
  fi

  local curcontext=$curcontext state line ret=1 arguments
  typeset -A opt_args

  arguments=(
    '(--cached --staged)'{--cached,--staged}
    '--no-renames'
    '--diff-filter=-:: :_guard "[ACDMRTUXB*]#"'
    '--relative=-:: :_directories'
    '-S-:'
    '-G-:'
    '(-a --text)'{-a,--text}
    '(-b --ignore-space-change)'{-b,--ignore-space-change}
    '(-w --ignore-all-space)'{-w,--ignore-all-space}
    '--ignore-submodules'
  )

  _arguments -C -w -S -s \
    $arguments \
    '*:: :->next' && ret=0

  case $state in
    (next)
      if [[ ${line[(i)--]} -ge $CURRENT ]]; then
        _arguments -C -S $arguments && return
        _alternative \
          'commits::__git_commits' \
          'tags::__git_tags' && ret=0
      else
        _alternative \
          'file::__git_files' && ret=0
      fi
      ;;
    (*)
      _nothing
      ;;
  esac

  return ret
}

compdef _git _gitdiffall gitdiffall
# compdef _git gitdiffall=git-diff

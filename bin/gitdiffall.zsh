if [[ -z "$script_dir" ]]; then
  local script_dir=$HOME/bin/
fi

function gitdiffall () {
  if [[ "$#" -eq 1 && "$1" =~ "^(j|k|@.+|[0-9]+)$" ]]; then
    local parsed shortcut revision msg
    parsed="`ruby ${script_dir}gitdiffall.rb $*`"

    shortcut=`echo "$parsed" | tail -1 | command grep -E '^SHORTCUT:' | cut -d : -f 2`
    revision=`echo "$parsed" | tail -2 | command grep -E '^REVISION:' | cut -d : -f 2`
    msg="`echo "$parsed" | sed -E '/^(REVISION|SHORTCUT):/d'`"

    [[ -n "$msg" ]] && echo "$msg"

    if [[ -n "$shortcut" ]]; then
      if [[ "$shortcut" == "!" ]]; then
        echo -n "Commit not in current branch, continue? (y/N) "
        read sure
        if [[ $sure != "y" ]]; then
          return 1
        fi
      fi
      export _GITDIFFALL_LAST_SHORTCUT=$shortcut
      [[ -n "$revision" ]] && ruby ${script_dir}gitdiffall.rb --no-shortcut $revision
    else
      unset _GITDIFFALL_LAST_SHORTCUT
      [[ -n "$revision" ]] && ruby ${script_dir}gitdiffall.rb --no-shortcut $revision
    fi
  else
    ruby ${script_dir}gitdiffall.rb $*
  fi
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
    '(--no-shortcut --shortcut)'{--no-shortcut,--shortcut}
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

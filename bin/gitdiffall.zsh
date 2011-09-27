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

  _arguments -w -S -s \
    '(-c --cached)'{-c,--cached}'[Use git-diff with --cached option]'

  _alternative \
    'tags::__git_tags'

  compadd 'HEAD'
}
compdef _git _gitdiffall gitdiffall
# compdef _git gitdiffall=git-checkout

#!/bin/zsh

install_dir=$HOME/bin/

if [[ -x ./config/install_dir.zsh ]]; then
  source ./config/install_dir.zsh
else
  echo "Copy scripts to directory:"
  echo "$install_dir\n"
  echo "Continue? (y/N) "
  echo "# To prevent this prompt, see config/install_dir.example"
  read sure
  if [[ $sure != "y" ]]; then
    echo "Aborded."
    exit 1
  fi
fi

mkdir -p $install_dir

cp -vi bin/gitdiffall.rb "$install_dir"gitdiffall.rb
cp -vi bin/gitdiffall.zsh "$install_dir"gitdiffall.zsh

if ! [[ -f "$install_dir"gitdiffall.zsh ]]; then
  echo "Install failed, gitdiffall.zsh not exist."
  exit 1
fi

local txt="$(<<__AUTO_INSERT__
# auto insert by install.zsh {{{
[[ -z "\$script_dir" ]] && local script_dir=$install_dir
# }}} auto insert by install.zsh\n
__AUTO_INSERT__)"

echo -e $txt|cat - "$install_dir"gitdiffall.zsh > /tmp/out && mv /tmp/out "$install_dir"gitdiffall.zsh

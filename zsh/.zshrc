if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  fzf
  fasd
  asdf
)

source $ZSH/oh-my-zsh.sh

# ALIASES
alias eval-github="eval $(ssh-agent -s) ; ssh-add ~/.ssh/orchwang-github"

# AWS
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

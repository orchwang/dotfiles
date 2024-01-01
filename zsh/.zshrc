ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  fzf
  fasd
  asdf
)

# ALIASES
alias eval-github="eval $(ssh-agent -s) ; ssh-add ~/.ssh/orchwang-github"

# AWS
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

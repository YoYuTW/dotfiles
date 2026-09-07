ZSH_DISABLE_COMPFIX=true
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL9K_DISABLE_INSTANT_PROMPT=true

# Plugins
plugins=(git git-prompt nvm npm python docker)

source $ZSH/oh-my-zsh.sh

# PATH
export PATH="./node_modules/.bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export APP_NAME=$USER-dev-studio

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Tools
export EDITOR=vim
export FZF_DEFAULT_OPTS="--height 40%"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Aliases
alias ll="ls -la"

# Platform-specific
if [[ "$(uname)" == "Darwin" ]]; then
  [ -f ~/.zshrc.mac ] && source ~/.zshrc.mac
else
  [ -f ~/.zshrc.linux ] && source ~/.zshrc.linux
fi

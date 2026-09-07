#!/bin/bash
set -e

DOTFILES_DIR="$HOME/dotfiles"

# Install system packages
install_pkg() {
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install "$1"
  else
    sudo apt install -y "$1"
  fi
}

for pkg in zsh jq git curl ffmpeg; do
  if ! command -v "$pkg" &>/dev/null; then
    install_pkg "$pkg"
  fi
done

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install powerlevel10k
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  echo "Installing powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# Install nvm + Node
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  . "$NVM_DIR/nvm.sh"
  echo "Installing Node LTS..."
  nvm install --lts
fi

# Install Bun
if ! command -v bun &>/dev/null; then
  echo "Installing bun..."
  curl -fsSL https://bun.sh/install | bash
fi

# Install Rust
if ! command -v rustc &>/dev/null; then
  echo "Installing rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Install fzf
if ! command -v fzf &>/dev/null; then
  echo "Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-bash --no-fish
fi

# Install claude code
if ! command -v claude &>/dev/null; then
  echo "Installing claude code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Install rtk
if ! command -v rtk &>/dev/null; then
  echo "Installing rtk..."
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
fi

# Symlink dotfiles
echo "Linking dotfiles..."
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.zshrc.linux" "$HOME/.zshrc.linux"
ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

# Claude Code config
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"

# Claude Code settings
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$CLAUDE_SETTINGS" ]; then
  echo '{}' > "$CLAUDE_SETTINGS"
fi

jq '
  .env = {
    "CLAUDE_CODE_DISABLE_1M_CONTEXT": "true",
    "CLAUDE_CODE_NO_FLICKER": "true",
    "CLAUDE_CODE_SUB_AGENT": "opus",
    "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING": "1"
  } |
  .permissions = {"defaultMode": "auto"} |
  .model = "sonnet" |
  .statusLine = {"type": "command", "command": "sh $HOME/.claude/statusline-command.sh"} |
  .enabledPlugins = {
    "impeccable@impeccable": true,
    "rust-analyzer-lsp@claude-plugins-official": true,
    "skill-creator@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true
  } |
  .sandbox = {"enabled": true} |
  .autoUpdatesChannel = "latest" |
  .showThinkingSummaries = true |
  .skipAutoPermissionPrompt = true |
  .agentPushNotifEnabled = true
' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"

# Set zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
fi

echo "Done! Restart your shell or run: exec zsh"

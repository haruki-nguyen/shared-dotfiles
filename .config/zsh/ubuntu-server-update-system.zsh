#!/bin/zsh
# Simplified System Update Script for Ubuntu Server

# Ensure basic system paths are available
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# --- Configuration ---
DOTFILES_REPO_PATH="$HOME/.dotfiles-ubuntu-server"
OMZ_PATH="$HOME/.oh-my-zsh"

# --- Logging ---
log_msg() {
  echo "=> $1"
}

# --- Main Update Logic ---
log_msg "Starting simplified system update..."

# 1. Update APT Packages (if sudo is available)
if command -v sudo >/dev/null && sudo -n true 2>/dev/null; then
  log_msg "Updating APT packages..."
  sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get clean
  log_msg "APT update complete."
else
  log_msg "Sudo not available or requires a password. Skipping APT updates."
fi

# 2. Update Dotfiles Repository
if [[ -d "$DOTFILES_REPO_PATH/.git" ]]; then
  log_msg "Updating dotfiles repository at $DOTFILES_REPO_PATH..."
  log_msg "WARNING: Discarding any local changes in the dotfiles repo."
  (cd "$DOTFILES_REPO_PATH" && command git fetch && command git reset --hard origin/main) || log_msg "Dotfiles update failed."
fi

# 3. Update Oh My Zsh
if [[ -d "$OMZ_PATH/.git" ]]; then
  log_msg "Updating Oh My Zsh..."
  (cd "$OMZ_PATH" && command git fetch && command git reset --hard origin/master) || log_msg "Oh My Zsh update failed."
fi

# 4. Update Tmux Plugins
if command -v tmux >/dev/null && [[ -f "$HOME/.config/tmux/tmux.conf" ]] && tmux info &>/dev/null 2>/dev/null; then
  log_msg "Updating tmux plugins..."
  "$HOME/.tmux/plugins/tpm/bin/update_plugins" all
fi

log_msg "System update script finished."
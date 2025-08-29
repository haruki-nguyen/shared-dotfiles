#!/bin/zsh
# Prevent sourcing: only allow running as a script
if [[ "${ZSH_EVAL_CONTEXT:-}" != "toplevel" ]]; then
  echo "[ERROR] This script should not be sourced. Please run it as a standalone script."
  return 1
fi

# Ensure basic system paths are available
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# System Update Script for Ubuntu Server Environment
# A comprehensive system update and maintenance script for the setup from ubuntu-server-installer.sh

# Configuration
typeset -A CONFIG=(
  # Project paths to update via git
  project_paths "/home/haruki/.dotfiles-ubuntu-server"
  
  # Logging
  log_level "INFO"  # DEBUG, INFO, WARN, ERROR
  
  # Package manager preferences
  package_managers "apt"
  
  # Packages from the installer script
  server_packages "build-essential curl wget git stow zsh zoxide locales python3 python3-pip python3-venv docker.io docker-compose openssh-server ufw fail2ban syncthing bluetooth bluez bluez-tools rfkill llvm gpg ffmpeg btop acpi elinks fbgrab emacs ripgrep fd-find markdown shellcheck jq"
  
  # Cleanup settings
  journal_retention_days 3
  snap_cleanup_enabled true
  flatpak_cleanup_enabled true
  npm_cleanup_enabled true
  pip_cleanup_enabled true
  apt_cache_cleanup_enabled true
  temp_cleanup_enabled true
  log_cleanup_enabled true
  docker_cleanup_enabled true
  
  # Advanced settings
  cleanup_orphans true
  remove_unused_configs true
)

# Colors for output
typeset -A COLORS=(
  reset "[0m"
  red "[31m"
  green "[32m"
  yellow "[33m"
  blue "[34m"
  magenta "[35m"
  cyan "[36m"
)

# Logging functions
log_msg() {
  local level="$1"; shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case "$level" in
    DEBUG) [[ "$CONFIG[log_level]" == "DEBUG" ]] && echo "${COLORS[cyan]}[DEBUG]${COLORS[reset]} $timestamp: $message" ;;
    INFO)  echo "${COLORS[green]}[INFO]${COLORS[reset]} $timestamp: $message" ;;
    WARN)  echo "${COLORS[yellow]}[WARN]${COLORS[reset]} $timestamp: $message" ;;
    ERROR) echo "${COLORS[red]}[ERROR]${COLORS[reset]} $timestamp: $message" >&2 ;;
  esac
}

# Error handling
error_exit() {
  log_msg ERROR "$1"
  return 1
}

# Command validation
command_exists() {
  command -v "$1" &>/dev/null
}

# Check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    log_msg WARN "This script is not intended to be run as root."
    return 1
  fi
}

# Git repository management
git_pull_all() {
  if ! command_exists git; then
    log_msg ERROR "git is not installed, skipping repository updates."
    return 1
  fi
  log_msg INFO "Updating Git repositories..."
  local original_dir="$PWD"
  
  for path in ${=CONFIG[project_paths]}; do
    if [[ -d "$path/.git" ]]; then
      log_msg INFO "Updating repository: $path"
      cd "$path" && git pull && cd "$original_dir" || log_msg WARN "Failed to update: $path"
    else
      log_msg WARN "Not a git repository: $path"
    fi
  done
  log_msg INFO "Git updates completed."
}

# Update server packages
update_server_packages() {
  log_msg INFO "Updating server packages..."
  if ! command_exists apt; then
    log_msg ERROR "apt not available, cannot update packages."
    return 1
  fi
  
  log_msg INFO "Updating package lists..."
  sudo apt update || log_msg WARN "apt update failed."
  
  log_msg INFO "Performing general system upgrade..."
  sudo apt upgrade -y || log_msg WARN "General upgrade failed."
  
  log_msg INFO "Removing unused packages..."
  sudo apt autoremove -y || log_msg WARN "autoremove failed."
}

# Update NVM and Node.js
update_nvm_and_node() {
  log_msg INFO "Updating NVM and Node.js v20..."
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    . "$NVM_DIR/nvm.sh"
    if ! command_exists nvm; then
        log_msg WARN "NVM script sourced but command not found."
        return 1
    fi
    log_msg INFO "Updating nvm..."
    nvm_install_dir=$(dirname $(dirname $(which nvm)))
    (cd "$nvm_install_dir" && git pull)
    . "$NVM_DIR/nvm.sh"

    log_msg INFO "Installing/updating Node.js v20..."
    nvm install 20
    nvm alias default 20
    log_msg INFO "Node.js v20 set as default."
  else
    log_msg WARN "NVM not found, skipping Node.js update."
  fi
}

# Update global npm packages
update_npm_packages() {
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
      . "$NVM_DIR/nvm.sh"
  fi
  if ! command_exists npm || ! command_exists jq; then
    log_msg WARN "npm or jq not found, skipping npm updates."
    return
  fi
  log_msg INFO "Updating global npm packages..."
  
  local global_packages=$(npm list -g --depth=0 --json | jq -r '.dependencies | keys[]' 2>/dev/null)
  if [[ -n "$global_packages" ]]; then
    echo "$global_packages" | while read -r pkg; do
      if [[ -n "$pkg" && "$pkg" != "npm" ]]; then
        log_msg INFO "Updating npm package: $pkg"
        npm install -g "$pkg"
      fi
    done
  fi
}

# Update Python packages
update_python_packages() {
  if ! command_exists pip3; then
    log_msg INFO "pip3 not found, skipping Python updates."
    return
  fi
  log_msg INFO "Updating global Python packages..."
  pip3 list --outdated --user | awk 'NR>2 {print $1}' | xargs -r -n1 pip3 install -U --user
}

# Update shell tools
update_shell_tools() {
  log_msg INFO "Updating shell tools..."
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_msg INFO "Updating Oh My Zsh..."
    (cd "$HOME/.oh-my-zsh" && git pull) || log_msg WARN "Failed to update Oh My Zsh."
  fi
  
  if command_exists tmux && [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
    if tmux info &>/dev/null; then
      log_msg INFO "Updating tmux plugins..."
      ~/.tmux/plugins/tpm/bin/update_plugins all
    fi
  fi
}

# Comprehensive environment cleanup
clean_env() {
  log_msg INFO "Starting environment cleanup..."
  
  # APT cache
  command_exists apt && sudo apt clean && sudo apt autoclean
  
  # Pip cache
  command_exists pip3 && pip3 cache purge
  
  # NPM cache
  command_exists npm && npm cache clean --force
  
  # Docker
  if command_exists docker; then
    log_msg INFO "Cleaning Docker resources..."
    docker system prune -af
  fi
  
  # Journal logs
  command_exists journalctl && sudo journalctl --vacuum-time="${CONFIG[journal_retention_days]}d"
  
  log_msg INFO "Environment cleanup completed."
}

# Main update function
update_system() {
  log_msg INFO "Starting Ubuntu Server update process..."
  check_root || return 1
  
  update_server_packages
  update_nvm_and_node
  update_npm_packages
  update_python_packages
  update_shell_tools
  git_pull_all
  
  if [[ "$CONFIG[cleanup_orphans]" == "true" ]]; then
    log_msg INFO "Removing orphaned packages..."
    sudo apt autoremove -y
  fi
  
  clean_env
  
  log_msg INFO "System update completed successfully."
}

# Run the update
update_system
#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
TTY_DEVICE="/dev/tty"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh"

log() {
  printf '%s\n' "$1"
}

print_banner() {
  cat <<'EOF'
______   _______ _________ _______  _______           _______  _______  ______   _______
(  __  \ (  ____ )\__   __// ___   )/ ___   )|\     /|(  ____ \(  ___  )(  __  \ (  ____ \
| (  \  )| (    )|   ) (   \/   )  |\/   )  |( \   / )| (    \/| (   ) || (  \  )| (    \/
| |   ) || (____)|   | |       /   )    /   ) \ (_) / | |      | |   | || |   ) || (__
| |   | ||     __)   | |      /   /    /   /   \   /  | |      | |   | || |   | ||  __)
| |   ) || (\ (      | |     /   /    /   /     ) (   | |      | |   | || |   ) || (
| (__/  )| ) \ \_____) (___ /   (_/\ /   (_/\   | |   | (____/\| (___) || (__/  )| (____/\
(______/ |/   \__/\_______/(_______/(_______/   \_/   (_______/(_______)(______/ (_______/
EOF
}

refresh_runtime_paths() {
  export PATH="${HOME}/.opencode/bin:${PATH}"

  if [[ -z "${NVM_DIR:-}" ]]; then
    export NVM_DIR="${HOME}/.nvm"
  fi

  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    . "$NVM_DIR/nvm.sh"
  fi

  if command -v npm >/dev/null 2>&1; then
    local npm_prefix
    npm_prefix="$(npm config get prefix 2>/dev/null || true)"
    if [[ -n "$npm_prefix" ]] && [[ -d "$npm_prefix/bin" ]]; then
      export PATH="$npm_prefix/bin:${PATH}"
    fi
  fi
}

backup_if_exists() {
  local target="$1"

  if [[ -f "$target" ]]; then
    local datetime
    datetime="$(date +%Y%m%d_%H%M%S)"
    local filename
    filename="$(basename "$target")"
    local backup_name="${filename%.json}-${datetime}.json.bak"
    local backup_path="$(dirname "$target")/${backup_name}"
    cp "$target" "$backup_path"
    log "Backed up ${target} -> ${backup_path}"
  fi
}

install_opencode() {
  refresh_runtime_paths

  if command -v opencode >/dev/null 2>&1; then
    log "OpenCode already installed: $(opencode --version)"
    return
  fi

  log "Installing OpenCode..."
  local installer
  installer="$(mktemp)"

  curl -fsSL "https://opencode.ai/install" -o "$installer"
  bash "$installer"
  rm -f "$installer"

  refresh_runtime_paths

  if ! command -v opencode >/dev/null 2>&1; then
    log "OpenCode install finished but \`opencode\` is still unavailable."
    exit 1
  fi

  log "Installed OpenCode: $(opencode --version)"
}

install_node() {
  log "Installing nvm..."
  curl -fsSL "$NVM_INSTALL_URL" | bash

  export NVM_DIR="${HOME}/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    log "Node.js install failed because $NVM_DIR/nvm.sh was not created."
    exit 1
  fi

  . "$NVM_DIR/nvm.sh"

  log "Installing Node.js 22..."
  nvm install 22
  refresh_runtime_paths

  if ! command -v node >/dev/null 2>&1; then
    log "Node.js install finished but `node` is still unavailable."
    exit 1
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log "npm is unavailable after installing Node.js."
    exit 1
  fi

  log "Installed Node.js: $(node -v)"
  log "Installed npm: $(npm -v)"
}

ensure_node_and_bun() {
  refresh_runtime_paths

  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log "Node.js already installed: $(node -v)"
    log "npm already installed: $(npm -v)"
  else
    install_node
  fi

  refresh_runtime_paths

  if command -v bunx >/dev/null 2>&1; then
    log "Bun already installed: $(bun --version)"
    return
  fi

  log "Installing Bun..."
  npm install -g bun
  refresh_runtime_paths

  if ! command -v bunx >/dev/null 2>&1; then
    log "Bun install finished but `bunx` is still unavailable."
    exit 1
  fi

  log "Installed Bun: $(bun --version)"
}

install_oh_my_opencode() {
  ensure_node_and_bun
  refresh_runtime_paths

  log "Installing oh-my-opencode..."

  if command -v bunx >/dev/null 2>&1; then
    bunx oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=no
  elif command -v npx >/dev/null 2>&1; then
    npx -y -p oh-my-opencode oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=no
  else
    log "oh-my-opencode install could not start because neither bunx nor npx is available."
    exit 1
  fi
}

prompt_config_choice() {
  if [[ ! -r "$TTY_DEVICE" ]] || [[ ! -w "$TTY_DEVICE" ]]; then
    printf '%s\n' "No interactive terminal detected. Defaulting to Regular config." >&2
    echo "regular"
    return
  fi

  printf '\nSelect your oh-my-opencode configuration:\n' > "$TTY_DEVICE"
  printf '  1) Regular - Uses Kimi/GLM models (default, free)\n' > "$TTY_DEVICE"
  printf '  2) OpenAI - Uses GPT-5 models with variants (requires OpenAI API key)\n\n' > "$TTY_DEVICE"
  printf "Type '1' or 'Regular', or type '2' or 'OpenAI', then press Enter.\n" > "$TTY_DEVICE"

  local choice normalized_choice
  while true; do
    printf 'Enter choice [1/2, Regular/OpenAI]: ' > "$TTY_DEVICE"
    IFS= read -r choice < "$TTY_DEVICE" || true
    normalized_choice="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')"

    case "$normalized_choice" in
      2|openai)
        printf 'Selected: OpenAI config\n' > "$TTY_DEVICE"
        echo "openai"
        return
        ;;
      ""|1|regular)
        printf 'Selected: Regular config\n' > "$TTY_DEVICE"
        echo "regular"
        return
        ;;
      *)
        printf "Please enter 1, 2, Regular, or OpenAI.\n" > "$TTY_DEVICE"
        ;;
    esac
  done
}

GITHUB_RAW_URL="https://raw.githubusercontent.com/AndreDalwin/drizzycode/main/config"

fetch_config() {
  local url="$1"
  local output="$2"
  
  log "Fetching config from $url..."
  if ! curl -fsSL "$url" -o "$output"; then
    log "ERROR: Failed to download config from $url"
    exit 1
  fi
}

write_opencode_json() {
  cat <<'EOF'
{
  "plugin": ["oh-my-opencode"]
}
EOF
}

install_drizzycode_config() {
  mkdir -p "$CONFIG_DIR"

  backup_if_exists "$CONFIG_DIR/opencode.json"
  backup_if_exists "$CONFIG_DIR/oh-my-opencode.json"

  local temp_opencode_json
  local temp_oh_my_opencode_json
  temp_opencode_json="$(mktemp "$CONFIG_DIR/opencode.json.XXXXXX")"
  temp_oh_my_opencode_json="$(mktemp "$CONFIG_DIR/oh-my-opencode.json.XXXXXX")"

  write_opencode_json > "$temp_opencode_json"

  local config_choice
  config_choice="$(prompt_config_choice)"
  
  if [[ "$config_choice" == "openai" ]]; then
    fetch_config "$GITHUB_RAW_URL/oh-my-opencode-gpt.json" "$temp_oh_my_opencode_json"
    mv "$temp_oh_my_opencode_json" "$CONFIG_DIR/oh-my-opencode.json"
    log "Wrote OpenAI config to $CONFIG_DIR/oh-my-opencode.json"
  else
    fetch_config "$GITHUB_RAW_URL/oh-my-opencode.json" "$temp_oh_my_opencode_json"
    mv "$temp_oh_my_opencode_json" "$CONFIG_DIR/oh-my-opencode.json"
    log "Wrote Regular config to $CONFIG_DIR/oh-my-opencode.json"
  fi

  mv "$temp_opencode_json" "$CONFIG_DIR/opencode.json"
  log "Wrote $CONFIG_DIR/opencode.json"
}

main() {
  print_banner
  log ""
  install_opencode
  install_oh_my_opencode
  install_drizzycode_config

  log ""
  log "========================================"
  log "Setup complete!"
  log ""
  log "Next step:"
  log "  Run: opencode auth login"
  log ""
  log "  Then enter your API key:"
  log "    - Kimi API key (for Regular config)"
  log "    - OR OpenAI API key (for OpenAI config)"
  log ""
  log "Start OpenCode anytime with: opencode"
  log "========================================"
}

main "$@"

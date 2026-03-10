#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"

log() {
  printf '%s\n' "$1"
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
  export PATH="${HOME}/.opencode/bin:${PATH}"

  if command -v opencode >/dev/null 2>&1; then
    log "OpenCode already installed: $(opencode --version)"
    return
  fi

  log "Installing OpenCode..."
  local installer
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT

  curl -fsSL "https://opencode.ai/install" -o "$installer"
  bash "$installer"

  export PATH="${HOME}/.opencode/bin:${PATH}"

  if ! command -v opencode >/dev/null 2>&1; then
    log "OpenCode install finished but \`opencode\` is still unavailable."
    exit 1
  fi

  log "Installed OpenCode: $(opencode --version)"
}

install_oh_my_opencode() {
  export PATH="${HOME}/.opencode/bin:${PATH}"

  if opencode plugin list 2>/dev/null | grep -q "oh-my-opencode"; then
    log "oh-my-opencode already installed"
    return
  fi

  if [[ -f "$CONFIG_DIR/opencode.json" ]]; then
    if grep -q '"oh-my-opencode"' "$CONFIG_DIR/opencode.json" 2>/dev/null; then
      log "oh-my-opencode already configured"
      return
    fi
  fi

  log "Installing oh-my-opencode..."

  if command -v npx >/dev/null 2>&1; then
    npx oh-my-opencode install || true
  elif command -v bunx >/dev/null 2>&1; then
    bunx oh-my-opencode install || true
  else
    log "Warning: Neither npx nor bunx found. Skipping oh-my-opencode CLI install."
    log "The plugin will still be enabled via config."
  fi
}

prompt_config_choice() {
  log ""
  log "Select your oh-my-opencode configuration:"
  log "  1) Regular - Uses Kimi/GLM models (default, free)"
  log "  2) OpenAI - Uses GPT-5 models with variants (requires OpenAI API key)"
  log ""
  
  local choice
  read -r -p "Enter choice [1/2]: " choice || true
  
  case "$choice" in
    2)
      log "Selected: OpenAI config"
      echo "openai"
      ;;
    *)
      log "Selected: Regular config"
      echo "regular"
      ;;
  esac
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

  write_opencode_json > "$CONFIG_DIR/opencode.json"
  
  local config_choice
  config_choice="$(prompt_config_choice)"
  
  if [[ "$config_choice" == "openai" ]]; then
    fetch_config "$GITHUB_RAW_URL/oh-my-opencode-gpt.json" "$CONFIG_DIR/oh-my-opencode.json"
    log "Wrote OpenAI config to $CONFIG_DIR/oh-my-opencode.json"
  else
    fetch_config "$GITHUB_RAW_URL/oh-my-opencode.json" "$CONFIG_DIR/oh-my-opencode.json"
    log "Wrote Regular config to $CONFIG_DIR/oh-my-opencode.json"
  fi

  log "Wrote $CONFIG_DIR/opencode.json"
}

main() {
  install_opencode
  install_oh_my_opencode
  install_drizzycode_config

  log ""
  log "Done. Start OpenCode with: opencode"
}

main "$@"
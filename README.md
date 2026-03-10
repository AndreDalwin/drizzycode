# drizzycode

Bootstrap installer for OpenCode plus Drizzy's `oh-my-opencode` config.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/AndreDalwin/drizzycode/main/install.sh | bash
```

## What it does

1. **Installs OpenCode** if `opencode` is missing.
2. **Installs oh-my-opencode** if not already present (via `npx` or `bunx`).
3. **Prompts for config choice:**
   - **Regular** - Uses Kimi/GLM models (default, free)
   - **OpenAI** - Uses GPT-5 models with variants (requires OpenAI API key)
4. **Writes config files** to `~/.config/opencode/`:
   - `opencode.json` - Enables the oh-my-opencode plugin
   - `oh-my-opencode.json` - Your selected agent/category configuration

### Backup Behavior

If config files already exist, they are backed up with a timestamp:
```
~/.config/opencode/oh-my-opencode-20240310_143022.json.bak
```

## Config Options

### Regular Config
Uses primarily free models:
- Kimi K2.5 for agents (Sisyphus, Hephaestus, Oracle, etc.)
- GLM-4.7 for deep/librarian tasks
- OpenCode's free tier models for quick/visual tasks

### OpenAI Config
Uses GPT-5 models where beneficial:
- GPT-5.4 with variants for Hephaestus, Oracle, Momus
- GPT-5.1 Codex Mini for lightweight exploration
- Kimi K2.5 retained for Sisyphus, Prometheus, and high-tier tasks

Both configs include the same ultrawork-mode prompt append for maximum agent utilization.

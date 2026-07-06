#!/usr/bin/env bash
# install.sh — install dotfiles onto Linux, macOS, or WSL.
#
# Run once per machine (safe to re-run — idempotent):
#   cd ~/dotfiles && ./scripts/install.sh
#
# What it does (each step is conditional and skipped with a WARN if prerequisites
# are missing — the installer never fails hard on missing tools):
#
#   1. Symlink .claude/AGENTS.md   -> ~/AGENTS.md          (always)
#   2. Symlink .tmux.conf          -> ~/.tmux.conf         (if tmux installed)
#   3. If Claude Code is installed (~/.claude/ exists):
#      a. Symlink .claude/AGENTS.md               -> ~/.claude/CLAUDE.md
#      b. Symlink scripts/statusline-command.sh   -> ~/.claude/statusline-command.sh
#      c. Symlink each dir in .claude/skills/*/   -> ~/.claude/skills/<name>
#      d. Merge statusLine key into ~/.claude/settings.json
#
# What it does NOT touch:
#   - ~/.claude/settings.json secrets (auth tokens, mcpServers) — copy from
#     another machine by hand.
#   - Skills managed by external harnesses (agent-harness, sap-harness) — those
#     coexist because we symlink per-skill, not the whole skills/ directory.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

warn() { printf '\033[33mWARN\033[0m: %s\n' "$1" >&2; }
info() { printf '%s\n' "$1"; }

# link_file SRC DST — idempotent symlink helper. Backs up a pre-existing non-symlink.
link_file() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    info "symlink already correct: $dst"
    return
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.pre-dotfiles.$(printf '%(%s)T\n' -1)"
    mv "$dst" "$backup"
    info "backed up existing $dst -> $backup"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
  info "linked $dst -> $src"
}

# 1. Cross-tool AGENTS.md (always applies — read by many coding agents).
link_file "$REPO/.claude/AGENTS.md" "$HOME/AGENTS.md"

# 2. tmux.conf — only if tmux is installed.
if command -v tmux >/dev/null 2>&1; then
  link_file "$REPO/.tmux.conf" "$HOME/.tmux.conf"
else
  warn "tmux not installed — skipping .tmux.conf symlink"
fi

# 3. Claude Code-specific setup — only if ~/.claude/ exists (i.e. Claude Code was
#    installed at some point on this machine).
if [ -d "$CLAUDE_DIR" ]; then
  # 3a. CLAUDE.md — Claude reads this filename specifically; point at same source
  #     file as ~/AGENTS.md so we don't duplicate content.
  link_file "$REPO/.claude/AGENTS.md" "$CLAUDE_DIR/CLAUDE.md"

  # 3b. statusline script
  link_file "$REPO/scripts/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"

  # 3c. Per-skill symlinks — leave ~/.claude/skills/ as a real dir so external
  #     harnesses can drop their own symlinks in without conflict.
  mkdir -p "$CLAUDE_DIR/skills"
  for skill in "$REPO"/.claude/skills/*/; do
    [ -d "$skill" ] || continue  # skip if glob didn't match (empty skills/)
    name="$(basename "$skill")"
    link_file "$skill" "$CLAUDE_DIR/skills/$name"
  done

  # 3d. Merge statusLine key into settings.json (create file if absent).
  if [ ! -f "$SETTINGS" ]; then
    echo "{}" > "$SETTINGS"
    info "created $SETTINGS"
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$SETTINGS" <<'EOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)

cfg["statusLine"] = {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
}

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"merged statusLine into {path}")
EOF
  else
    warn "python3 not installed — skipping statusLine merge into settings.json"
  fi
else
  warn "~/.claude/ not found — Claude Code is not installed on this machine."
  warn "  Skipped: CLAUDE.md, statusline-command.sh, skills, settings.json merge."
  warn "  Install Claude Code and re-run this script to complete setup."
fi

info "install.sh complete."

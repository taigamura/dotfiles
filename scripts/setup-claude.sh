#!/usr/bin/env bash
# setup-claude.sh — install Claude + tmux user-level config from this dotfiles repo.
#
# Run once per machine (safe to re-run — idempotent):
#   cd ~/dotfiles && ./scripts/setup-claude.sh
#
# What it does:
#   1. Symlinks scripts/statusline-command.sh -> ~/.claude/statusline-command.sh
#   2. Symlinks .claude/CLAUDE.md             -> ~/.claude/CLAUDE.md
#   3. Symlinks .tmux.conf                    -> ~/.tmux.conf
#   4. Symlinks each dir in .claude/skills/*/ -> ~/.claude/skills/<name>
#   5. Merges the statusLine key into ~/.claude/settings.json (creates file if absent)
#
# What it does NOT touch:
#   - ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, mcpServers — copy-paste from another
#     machine into ~/.claude/settings.json by hand.
#   - Skills managed by agent-harness or sap-harness — those repos install their own
#     symlinks into ~/.claude/skills/, and they coexist with ours because we symlink
#     per-skill, not the whole skills directory.
#   - Any key already in settings.json that this script does not manage.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR" "$CLAUDE_DIR/skills"

# link_file SRC DST — idempotent symlink helper. Backs up a pre-existing non-symlink.
link_file() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "symlink already correct: $dst"
    return
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.pre-dotfiles.$(printf '%(%s)T\n' -1)"
    mv "$dst" "$backup"
    echo "backed up existing $dst -> $backup"
  fi

  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}

# 1. statusline script
link_file "$REPO/scripts/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"

# 2. CLAUDE.md
link_file "$REPO/.claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# 3. .tmux.conf
link_file "$REPO/.tmux.conf" "$HOME/.tmux.conf"

# 4. Per-skill symlinks — leave ~/.claude/skills/ as a real dir so agent-harness /
#    sap-harness can drop their own symlinks in without conflict.
if [ -d "$REPO/.claude/skills" ]; then
  for skill in "$REPO"/.claude/skills/*/; do
    [ -d "$skill" ] || continue  # skip if glob didn't match (empty skills/)
    name="$(basename "$skill")"
    link_file "$skill" "$CLAUDE_DIR/skills/$name"
  done
fi

# 5. Merge statusLine key into settings.json (create file if absent).
if [ ! -f "$SETTINGS" ]; then
  echo "{}" > "$SETTINGS"
  echo "created $SETTINGS"
fi

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

echo "setup-claude.sh complete."

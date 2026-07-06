# dotfiles

Personal environment I want mirrored across machines (work laptop, personal desktop, etc.).

## What's in here

```
.claude/
├── CLAUDE.md          # global memory Claude reads every session
└── skills/            # skills I author myself (starts empty)
scripts/
├── setup-claude.sh    # the installer — safe to re-run
└── statusline-command.sh
.tmux.conf
```

## What's *not* in here (deliberately)

- **`~/.claude/settings.json`** — contains secrets (`ANTHROPIC_AUTH_TOKEN`, MCP
  Bearer tokens) and a few machine-specific paths. Copy-paste it from another
  machine when setting up a new box, then let `setup-claude.sh` merge the
  `statusLine` key into it.
- **MCP servers** — configured directly in `settings.json` per machine.
- **Skills from `agent-harness` and `sap-harness`** — those repos install their
  own symlinks into `~/.claude/skills/`. We coexist by symlinking *per skill*
  rather than the whole `skills/` directory.
- **`settings.local.json`** — machine-local permission overrides, stays local.

## Bootstrapping a new machine

```bash
# 1. Clone this repo
git clone <this-repo-url> ~/dotfiles

# 2. Run the installer (safe to re-run)
~/dotfiles/scripts/setup-claude.sh

# 3. Get secrets onto the machine — copy ~/.claude/settings.json from another
#    machine (or reconstruct by hand). Re-run the installer afterward so the
#    statusLine key gets merged back in.

# 4. Clone and install the harness repos separately
git clone <agent-harness-url> ~/agent-harness
git clone <sap-harness-url>    ~/sap-harness
# Follow each repo's install instructions to link their skills into ~/.claude/skills/
```

## Adding new things to sync

- **Something in `~/.claude/`** → move it into `~/dotfiles/.claude/`, add a
  `link_file` call in `setup-claude.sh` if it's not covered by the existing
  patterns (CLAUDE.md, statusline, per-skill loop).
- **A shell rc, editor config, etc.** → drop it at the corresponding path under
  `~/dotfiles/` and add a `link_file` line.

## Idempotency

`setup-claude.sh` is safe to re-run. It:
- Skips symlinks that already point at the right target.
- Backs up any pre-existing non-symlink at the target path
  (as `<file>.pre-dotfiles.<timestamp>`) before replacing it.
- Only writes `statusLine` into `settings.json` — leaves every other key alone.

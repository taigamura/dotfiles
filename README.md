# dotfiles

Personal environment I want mirrored across machines (work laptop, personal desktop, etc.).
Deliberately small — sync the stable, portable things; leave secrets and machine-specific
config out.

## What's in here

```
.claude/
├── AGENTS.md          # cross-agent memory (symlinked to ~/AGENTS.md and ~/.claude/CLAUDE.md)
└── skills/            # skills I author myself (starts empty)
scripts/
├── install.sh         # installer for Linux / macOS / WSL
├── install.ps1        # installer for native Windows (PowerShell)
└── statusline-command.sh
.tmux.conf
```

## What's *not* in here (deliberately)

- **`~/.claude/settings.json`** — contains secrets (`ANTHROPIC_AUTH_TOKEN`, MCP
  Bearer tokens) and a few machine-specific paths. Copy it from another machine
  by hand when setting up a new box, then re-run the installer so it merges the
  `statusLine` key back in.
- **MCP servers** — configured directly in `settings.json` per machine.
- **Skills from `agent-harness` and `sap-harness`** — those repos install their
  own symlinks into `~/.claude/skills/`. We coexist by symlinking *per skill*
  rather than the whole `skills/` directory.
- **`settings.local.json`** — machine-local permission overrides, stays local.

## AGENTS.md vs CLAUDE.md

The file is authored once as `.claude/AGENTS.md` — the emerging cross-vendor
convention that tools like Cursor and Aider follow. The installer creates *two*
symlinks pointing at this same source file:

- `~/AGENTS.md` — picked up by cross-vendor tools.
- `~/.claude/CLAUDE.md` — Claude Code's specific filename.

One source of truth, two filenames — no duplicated content.

## Bootstrapping a new machine

### Linux / macOS / WSL

```bash
git clone <this-repo-url> ~/dotfiles
~/dotfiles/scripts/install.sh
```

Then copy `~/.claude/settings.json` from another machine, and clone the harness
repos separately:

```bash
git clone <agent-harness-url> ~/agent-harness
git clone <sap-harness-url>   ~/sap-harness
# Follow each repo's install instructions.
```

### Native Windows (no WSL)

Prerequisite: enable **Developer Mode** so PowerShell can create symlinks without
admin. Settings > Privacy & security > For developers > Developer Mode: On.

```powershell
git clone <this-repo-url> $HOME\dotfiles
cd $HOME\dotfiles
.\scripts\install.ps1
```

Native Windows skips things that don't apply there: `.tmux.conf` (no tmux),
`statusline-command.sh` (bash script), and the `statusLine` merge into
`settings.json` (would point at a broken script). The installer warns about each
skip. If you want Claude Code with the full experience, run it inside WSL and use
`install.sh` from there.

## Idempotency

Both installers are safe to re-run. They:
- Skip symlinks that already point at the right target.
- Back up any pre-existing non-symlink at the target path
  (as `<file>.pre-dotfiles.<timestamp>`) before replacing it.
- Only write the `statusLine` key into `settings.json` — leave every other key alone.

## Graceful degradation

Neither installer fails hard on missing tools. If Claude Code isn't installed
(no `~/.claude/`), or tmux isn't installed, or python3 is missing (Linux/macOS/WSL
only — needed for the JSON merge), you'll get a `WARN` and that step is skipped.
The installer never leaves the machine in a half-configured state.

## Adding new things to sync

- **Something in `~/.claude/`** → move it into `~/dotfiles/.claude/`, add a
  `link_file` call in `install.sh` (and `Link-File` in `install.ps1` if it also
  applies to Windows).
- **A shell rc, editor config, etc.** → drop it at the corresponding path under
  `~/dotfiles/` and add a link call.

# install.ps1 -- install dotfiles onto native Windows (PowerShell).
#
# Run once per machine (safe to re-run -- idempotent):
#   cd $HOME\dotfiles
#   .\scripts\install.ps1
#
# Prerequisites:
#   - Windows 10 build 14972+ (2016+) with Developer Mode ENABLED, OR run
#     PowerShell as Administrator. Symlink creation fails without one of these.
#     Enable Developer Mode: Settings > Privacy & security > For developers.
#
# What it does (each step is conditional and skipped with a WARN if prerequisites
# are missing -- the installer never fails hard on missing tools):
#
#   1. Symlink .claude\AGENTS.md -> $HOME\AGENTS.md  (always)
#   2. If Claude Code is installed ($HOME\.claude\ exists):
#      a. Symlink .claude\AGENTS.md -> $HOME\.claude\CLAUDE.md
#      b. Symlink each dir in .claude\skills\*\ -> $HOME\.claude\skills\<name>
#
# What it SKIPS on native Windows (unlike install.sh):
#   - .tmux.conf              -- tmux does not run on native Windows.
#   - statusline-command.sh   -- bash script, will not execute on native Windows.
#   - statusLine key merge    -- would point at a broken script.
#
# If you run Claude Code inside WSL, use scripts/install.sh from within WSL
# instead -- this .ps1 is only for native Windows Claude Code installs.

$ErrorActionPreference = 'Stop'

$Repo      = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ClaudeDir = Join-Path $HOME '.claude'

function Write-Warn { param([string]$Message) Write-Host "WARN: $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host $Message }

# Link-File -- idempotent symlink helper. Backs up pre-existing non-symlink.
function Link-File {
  param(
    [Parameter(Mandatory)][string]$Src,
    [Parameter(Mandatory)][string]$Dst
  )

  # If Dst is already a symlink pointing at Src, nothing to do.
  if (Test-Path $Dst) {
    $item = Get-Item $Dst -Force
    if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -and (Resolve-Path $item.Target[0] -ErrorAction SilentlyContinue).Path -eq (Resolve-Path $Src).Path) {
      Write-Info "symlink already correct: $Dst"
      return
    }

    # Back up any pre-existing non-symlink at Dst.
    if ($item.LinkType -ne 'SymbolicLink') {
      $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
      $backup = "$Dst.pre-dotfiles.$timestamp"
      Move-Item -Path $Dst -Destination $backup
      Write-Info "backed up existing $Dst -> $backup"
    } else {
      # Existing symlink points elsewhere -- remove it.
      Remove-Item -Path $Dst -Force
    }
  }

  # Ensure parent dir exists.
  $parent = Split-Path -Parent $Dst
  if ($parent -and -not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  try {
    New-Item -ItemType SymbolicLink -Path $Dst -Target $Src -Force | Out-Null
    Write-Info "linked $Dst -> $Src"
  } catch {
    Write-Warn "failed to create symlink $Dst -> $Src"
    Write-Warn "  reason: $($_.Exception.Message)"
    Write-Warn "  fix: enable Developer Mode (Settings > Privacy & security > For developers)"
    Write-Warn "       or run this script from an Administrator PowerShell."
  }
}

# 1. Cross-tool AGENTS.md (always applies).
Link-File -Src (Join-Path $Repo '.claude\AGENTS.md') -Dst (Join-Path $HOME 'AGENTS.md')

# tmux -- not available on native Windows; skip with warning.
Write-Warn "skipping .tmux.conf -- tmux is not available on native Windows"

# 2. Claude Code-specific setup -- only if ~\.claude\ exists.
if (Test-Path $ClaudeDir) {
  # 2a. CLAUDE.md points at same source file as ~\AGENTS.md.
  Link-File -Src (Join-Path $Repo '.claude\AGENTS.md') -Dst (Join-Path $ClaudeDir 'CLAUDE.md')

  # 2b. Statusline -- bash script, cannot run on native Windows. Skip with warning.
  Write-Warn "skipping statusline-command.sh symlink -- bash script will not run on native Windows"
  Write-Warn "skipping statusLine merge into settings.json for the same reason"

  # 2c. Per-skill symlinks.
  $skillsDst = Join-Path $ClaudeDir 'skills'
  if (-not (Test-Path $skillsDst)) {
    New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
  }

  $skillsSrc = Join-Path $Repo '.claude\skills'
  if (Test-Path $skillsSrc) {
    Get-ChildItem -Path $skillsSrc -Directory | ForEach-Object {
      Link-File -Src $_.FullName -Dst (Join-Path $skillsDst $_.Name)
    }
  }
} else {
  Write-Warn "$ClaudeDir not found -- Claude Code is not installed on this machine."
  Write-Warn "  Skipped: CLAUDE.md, skills."
  Write-Warn "  Install Claude Code and re-run this script to complete setup."
}

Write-Info "install.ps1 complete."

#!/usr/bin/env bash
# pick_concepts.sh — list wiki pages modified in the last N days, sample K of them.
#
# Usage: pick_concepts.sh <days> <count> [vault_path]
#   days:       lookback window (e.g. 7)
#   count:      how many pages to return (e.g. 5)
#   vault_path: optional; defaults to $OBSIDIAN_VAULT, then a hardcoded fallback
#
# Filters to wiki/concepts, wiki/domains, wiki/sources — the pages that actually
# encode learned material. Skips wiki/hot.md, wiki/log.md, wiki/index.md.
#
# Output: newline-separated relative paths, shuffled, capped at <count>.

set -euo pipefail

days="${1:-7}"
count="${2:-5}"
vault="${3:-${OBSIDIAN_VAULT:-C:/Users/I538340/OneDrive - SAP SE/Documents/Obsidian Vault}}"

if [ ! -d "$vault" ]; then
  echo "vault not found: $vault" >&2
  exit 1
fi

cd "$vault"

# Git log with --since gives us pages that were actually touched. --name-only
# lists paths; --diff-filter=AM keeps adds + modifications (drops deletes/renames-target).
# Uniq because a page edited N times shows up N times.
git log --since="${days}.days.ago" --name-only --diff-filter=AM --pretty=format: -- \
  'wiki/concepts/*.md' 'wiki/domains/*.md' 'wiki/sources/*.md' 2>/dev/null \
  | grep -v '^$' \
  | grep -Ev 'wiki/(hot|log|index|overview)\.md$' \
  | sort -u \
  | shuf \
  | head -n "$count"

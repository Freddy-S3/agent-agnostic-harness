#!/bin/sh
# Refresh Codex's copy of the harness rulebook.
#
# Claude reads ~/.claude/CLAUDE.md as a stub with an @-import, so it tracks the
# source live. Codex has no import mechanism: ~/.codex/AGENTS.md must be a real
# copy of instructions/AGENTS.md, and a copy rots. It did - the installed copy
# sat 31 diff lines and two days behind the source, so Codex was running an
# older rulebook than every other host.
#
# A link is not available as a substitute. A directory junction cannot stand in
# for a single file, and a file symlink needs administrator rights or Developer
# Mode, which this machine does not grant (verified 2026-08-23: "Administrator
# privilege required for this operation"). A hard link does not survive an
# editor that writes by replace-and-rename, which is how most edits land.
#
# So the copy stays and is refreshed mechanically instead. The post-commit,
# post-merge and post-checkout hooks call this, and core.hooksPath is global,
# so any commit in any repository re-syncs the rulebook. Every durable edit to
# AGENTS.md is committed, so the copy cannot fall more than one commit behind.
#
# --check reports drift without writing, and exits 1 when the copy is stale.

set -e

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_root=$(dirname -- "$script_dir")
src="$source_root/instructions/AGENTS.md"

# USERPROFILE arrives as a Windows path under Git Bash. Git Bash tolerates the
# mixed form, but the messages below are read by a human, so normalise it.
home=${USERPROFILE:-$HOME}
# Two escapes: tr resolves `\\` to one backslash, and a lone trailing backslash
# makes tr warn on every commit.
bs=$(printf '\134\134')
home=$(printf '%s' "$home" | tr "$bs" '/' | sed -e 's|^\([A-Za-z]\):|/\1|')
dest="$home/.codex/AGENTS.md"

[ -f "$src" ] || exit 0
# No Codex on this machine, or Codex was never installed for. Nothing to keep
# in sync, and a hook firing in an unrelated repository must stay silent.
[ -d "$home/.codex" ] || exit 0

if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    [ "$1" = "--check" ] && echo "codex rulebook: in sync"
    exit 0
fi

if [ "$1" = "--check" ]; then
    echo "codex rulebook: STALE - $dest does not match $src" >&2
    echo "  refresh with: sh tools/sync-codex-rulebook.sh" >&2
    exit 1
fi

cp -- "$src" "$dest"
echo "codex rulebook: refreshed $dest from instructions/AGENTS.md"

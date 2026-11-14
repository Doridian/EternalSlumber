#!/usr/bin/env bash
# (Re)create the headless Ghidra project in ghidra/ and analyze orig/ALIFE.EXE.
# Usage: tools/ghidra/setup.sh [--force]    (~a few minutes)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GHIDRA="${GHIDRA_INSTALL_DIR:-/opt/ghidra}"
PROJ="$ROOT/ghidra"
SCRIPTS="$ROOT/tools/ghidra/scripts"

if [[ -e "$PROJ/EternalSlumber.gpr" ]]; then
	if [[ "${1:-}" != "--force" ]]; then
		echo "ghidra/EternalSlumber.gpr exists; pass --force to delete and re-create it" >&2
		exit 1
	fi
	rm -rf "$PROJ/EternalSlumber.gpr" "$PROJ/EternalSlumber.rep"
fi
mkdir -p "$PROJ/logs"
rm -f "$PROJ"/logs/setup*

# Import, auto-analyze with Ghidra's defaults (ALIFE.EXE is MSVC-built, so
# __cdecl/__stdcall are right), create functions for orphan code, then apply
# the repo's symbol file. EternalSlumberSetup.java (__watcall) is only for the
# Watcom-built ALIFEDOS.EXE, which needs an LE loader extension to import.
exec 9>"$PROJ/.gh.lock"
flock 9
"$GHIDRA/support/analyzeHeadless" "$PROJ" EternalSlumber \
	-import "$ROOT/orig/ALIFE.EXE" \
	-scriptPath "$SCRIPTS" \
	-postScript EternalSlumberPost.java \
	-postScript GhCli.java "$PROJ/logs/setup-apply.out" apply \
	-log "$PROJ/logs/setup.log" -scriptlog "$PROJ/logs/setup-script.log" \
	>"$PROJ/logs/setup.stdout" 2>&1 || { tail -50 "$PROJ/logs/setup.stdout"; exit 1; }
grep -E "EternalSlumberSetup|EternalSlumberPost|ERROR" "$PROJ/logs/setup-script.log" || true
cat "$PROJ/logs/setup-apply.out" 2>/dev/null || true
echo "done: $PROJ/EternalSlumber.gpr"

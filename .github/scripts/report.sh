#!/usr/bin/env bash
# Run a command; on failure, surface the tail of its output as a single
# GitHub annotation so it is readable through the API without downloading logs.
# Usage: .github/scripts/report.sh <label> <command> [args...]
set -uo pipefail
label="$1"; shift
log="$(mktemp)"
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  tail -n 80 "$log" | cut -c1-400 | python3 -c '
import sys
text = sys.stdin.read().replace("%", "%25").replace("\r", "").replace("\n", "%0A")
print("::error title=" + sys.argv[1] + " failed::" + text)
' "$label"
fi
exit "$status"

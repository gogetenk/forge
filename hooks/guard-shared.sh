#!/usr/bin/env bash
# Hook PreToolUse — blocks writes to frozen files without explicit authorization
# Frozen files require "MODIFY_FROZEN: authorized" in the active wip-*.md task.
#
# Copyright 2026 Yannis TOCREAU — Apache License 2.0

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
inp = data.get('tool_input', {})
print(inp.get('file_path') or inp.get('path') or inp.get('target_file') or '')
" 2>/dev/null)

if [ -z "$FILE_PATH" ]; then exit 0; fi

# CONFIGURE: list your frozen paths here
if echo "$FILE_PATH" | grep -qE "^Shared/|/Shared/"; then
  AUTHORIZED=$(grep -rl "MODIFY_FROZEN: authorized" tasks/wip-*.md 2>/dev/null | wc -l)
  if [ "$AUTHORIZED" -eq 0 ]; then
    echo "BLOCKED: modification of frozen files is forbidden without explicit authorization."
    echo "Add 'MODIFY_FROZEN: authorized' in your wip-*.md task and create questions/{task-id}-frozen-change.md for arbitration."
    exit 2
  fi
fi

exit 0

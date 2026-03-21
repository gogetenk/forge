#!/usr/bin/env bash
# Hook PreToolUse (Bash matcher) — blocks git push if build/tests fail
# Only triggers on "git push" commands.
#
# Copyright 2026 Yannis TOCREAU — Apache License 2.0

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
inp = data.get('tool_input', {})
print(inp.get('command') or '')
" 2>/dev/null)

if ! echo "$COMMAND" | grep -qE '^git push'; then
  exit 0
fi

echo "Pre-push verification: running build + tests..."

# CONFIGURE: replace with your build/test commands
# Example for .NET:
# dotnet build -c Release || { echo "BLOCKED: build failed"; exit 2; }
# dotnet test tests/Unit/ --no-build -c Release || { echo "BLOCKED: unit tests failed"; exit 2; }

# Example for Node.js:
# npm run lint || { echo "BLOCKED: lint failed"; exit 2; }
# npm run build || { echo "BLOCKED: build failed"; exit 2; }

# Example for Python:
# python -m pytest tests/unit/ || { echo "BLOCKED: tests failed"; exit 2; }

echo "All checks passed. Push allowed."
exit 0

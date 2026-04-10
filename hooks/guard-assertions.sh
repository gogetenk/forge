#!/usr/bin/env bash
# Hook PreToolUse — blocks weakening assertions in step definition files
# Rule: TDD means fix the source code, never weaken the tests.
# Agents may ADD assertions but never REMOVE or COMMENT them.
#
# Triggers on: Write, Edit tools targeting *StepDefinitions*.cs files
# Detects: removal of .Should(), .Be(), .Contain(), .NotBe(), .NotBeNull() lines
#          commenting out assertion lines (// ...Should...)
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
if ! echo "$FILE_PATH" | grep -qE 'StepDefinitions.*\.cs$'; then exit 0; fi

# For Edit tool: check if old_string contains assertions that new_string removes
OLD_STRING=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
inp = data.get('tool_input', {})
print(inp.get('old_string') or '')
" 2>/dev/null)

NEW_STRING=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
inp = data.get('tool_input', {})
print(inp.get('new_string') or '')
" 2>/dev/null)

# For Write tool: check if content contains commented-out assertions
CONTENT=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
inp = data.get('tool_input', {})
print(inp.get('content') or '')
" 2>/dev/null)

VIOLATIONS=""

# Check Edit: assertions present in old_string but removed/commented in new_string
if [ -n "$OLD_STRING" ] && [ -n "$NEW_STRING" ]; then
  # Count assertion calls in old vs new
  OLD_ASSERTIONS=$(echo "$OLD_STRING" | grep -cE '\.Should\(|\.Be\(|\.Contain\(|\.NotBe\(|\.NotBeNull\(|\.BeOneOf\(' 2>/dev/null || echo 0)
  NEW_ASSERTIONS=$(echo "$NEW_STRING" | grep -cE '\.Should\(|\.Be\(|\.Contain\(|\.NotBe\(|\.NotBeNull\(|\.BeOneOf\(' 2>/dev/null || echo 0)

  # Check for commented-out assertions in new_string
  COMMENTED=$(echo "$NEW_STRING" | grep -cE '//.*\.Should\(' 2>/dev/null || echo 0)

  if [ "$NEW_ASSERTIONS" -lt "$OLD_ASSERTIONS" ]; then
    REMOVED=$((OLD_ASSERTIONS - NEW_ASSERTIONS))
    VIOLATIONS="$VIOLATIONS\n- $REMOVED assertion(s) REMOVED from step definition"
  fi

  if [ "$COMMENTED" -gt 0 ]; then
    VIOLATIONS="$VIOLATIONS\n- $COMMENTED assertion(s) COMMENTED OUT in step definition"
  fi
fi

# Check Write: detect commented-out assertions in full file content
if [ -n "$CONTENT" ]; then
  COMMENTED=$(echo "$CONTENT" | grep -cE '//.*\.Should\(' 2>/dev/null || echo 0)
  if [ "$COMMENTED" -gt 0 ]; then
    VIOLATIONS="$VIOLATIONS\n- $COMMENTED commented-out assertion(s) detected in step definition"
  fi
fi

if [ -n "$VIOLATIONS" ]; then
  echo "BLOCKED: Step definition assertions must not be weakened."
  echo ""
  echo "Violations found:"
  echo -e "$VIOLATIONS"
  echo ""
  echo "TDD rule: when a test fails, fix the SOURCE CODE (src/), not the test."
  echo ""
  echo "Allowed changes to step definitions:"
  echo "  - ADD new assertions"
  echo "  - FIX test infrastructure (ScenarioContext, helpers, data setup)"
  echo "  - MOVE assertions between files (centralizing into CommonSteps)"
  echo ""
  echo "Forbidden changes:"
  echo "  - REMOVE an assertion (.Should(), .Be(), etc.)"
  echo "  - COMMENT OUT an assertion (// ...Should...)"
  echo "  - WEAKEN an assertion (replace strict check with loose check)"
  exit 2
fi

exit 0

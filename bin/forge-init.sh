#!/usr/bin/env bash
# forge-init.sh — Interactive setup wizard for Forge
# Creates the full Forge structure in the current project directory.
#
# Compatible: Linux, macOS, Git Bash (Windows)
# No external dependencies (no jq, no python — just bash + sed + grep)
#
# Copyright 2026 Yannis TOCREAU — Apache License 2.0

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# Resolve FORGE_HOME (where forge is installed)
# ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

# Verify forge repo structure
if [ ! -d "$FORGE_HOME/agents" ] || [ ! -d "$FORGE_HOME/hooks" ] || [ ! -d "$FORGE_HOME/commands" ]; then
  echo "ERROR: Forge installation not found at $FORGE_HOME"
  echo "Expected directories: agents/, hooks/, commands/, templates/"
  exit 1
fi

PROJECT_DIR="$(pwd)"

# ──────────────────────────────────────────────────────────────────────
# Colors (disabled if not a terminal)
# ──────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD="\033[1m"
  DIM="\033[2m"
  GREEN="\033[32m"
  CYAN="\033[36m"
  YELLOW="\033[33m"
  RESET="\033[0m"
else
  BOLD="" DIM="" GREEN="" CYAN="" YELLOW="" RESET=""
fi

# ──────────────────────────────────────────────────────────────────────
# Helper: prompt with default
# Usage: ask "Backend stack" "Node.js + Express" → stores in REPLY
# ──────────────────────────────────────────────────────────────────────
ask() {
  local prompt="$1"
  local default="$2"
  local answer
  printf "${CYAN}? ${RESET}${BOLD}%s${RESET} ${DIM}[%s]${RESET}: " "$prompt" "$default"
  read -r answer
  REPLY="${answer:-$default}"
}

# ──────────────────────────────────────────────────────────────────────
# Step 1: Detect stack
# ──────────────────────────────────────────────────────────────────────
detect_stack() {
  DETECTED_BACKEND=""
  DETECTED_FRONTEND=""
  DETECTED_TEST=""
  DETECTED_BUILD=""
  DETECTED_TEST_CMD=""
  DETECTED_LINT=""
  DETECTED_FEATURES="tests/features/"

  # --- Node.js ---
  if [ -f "$PROJECT_DIR/package.json" ]; then
    local deps
    deps="$(cat "$PROJECT_DIR/package.json")"

    # Detect frontend framework
    if echo "$deps" | grep -q '"next"'; then
      # Try to extract Next.js version
      local next_ver
      next_ver=$(echo "$deps" | sed -n 's/.*"next"[[:space:]]*:[[:space:]]*"\^*~*\([0-9]*\).*/\1/p' | head -1)
      DETECTED_FRONTEND="Next.js${next_ver:+ $next_ver}"
    elif echo "$deps" | grep -q '"nuxt"'; then
      DETECTED_FRONTEND="Nuxt.js"
    elif echo "$deps" | grep -q '"vue"'; then
      DETECTED_FRONTEND="Vue.js"
    elif echo "$deps" | grep -q '"react"'; then
      DETECTED_FRONTEND="React"
    elif echo "$deps" | grep -q '"svelte"'; then
      DETECTED_FRONTEND="Svelte"
    elif echo "$deps" | grep -q '"angular"'; then
      DETECTED_FRONTEND="Angular"
    fi

    # Detect backend framework
    if echo "$deps" | grep -q '"express"'; then
      DETECTED_BACKEND="Node.js + Express"
    elif echo "$deps" | grep -q '"fastify"'; then
      DETECTED_BACKEND="Node.js + Fastify"
    elif echo "$deps" | grep -q '"hono"'; then
      DETECTED_BACKEND="Node.js + Hono"
    elif echo "$deps" | grep -q '"koa"'; then
      DETECTED_BACKEND="Node.js + Koa"
    elif [ -n "$DETECTED_FRONTEND" ]; then
      DETECTED_BACKEND="$DETECTED_FRONTEND (fullstack)"
    else
      DETECTED_BACKEND="Node.js"
    fi

    # Detect test framework
    if echo "$deps" | grep -q '"vitest"'; then
      DETECTED_TEST="Vitest"
    elif echo "$deps" | grep -q '"jest"'; then
      DETECTED_TEST="Jest"
    elif echo "$deps" | grep -q '"mocha"'; then
      DETECTED_TEST="Mocha"
    fi
    if echo "$deps" | grep -q '"playwright"'; then
      DETECTED_TEST="${DETECTED_TEST:+$DETECTED_TEST + }Playwright"
    elif echo "$deps" | grep -q '"cypress"'; then
      DETECTED_TEST="${DETECTED_TEST:+$DETECTED_TEST + }Cypress"
    fi
    DETECTED_TEST="${DETECTED_TEST:-Jest}"

    DETECTED_BUILD="npm run build"
    DETECTED_TEST_CMD="npm test"
    DETECTED_LINT="npm run lint"
    DETECTED_STACK="Node.js"
  fi

  # --- .NET ---
  if ls "$PROJECT_DIR"/*.sln "$PROJECT_DIR"/*.csproj 2>/dev/null | head -1 > /dev/null 2>&1; then
    DETECTED_BACKEND="${DETECTED_BACKEND:-ASP.NET Core}"
    DETECTED_TEST="${DETECTED_TEST:-xUnit}"
    DETECTED_BUILD="${DETECTED_BUILD:-dotnet build -c Release}"
    DETECTED_TEST_CMD="${DETECTED_TEST_CMD:-dotnet test -c Release}"
    DETECTED_LINT="${DETECTED_LINT:-dotnet format --verify-no-changes}"
    DETECTED_STACK="${DETECTED_STACK:+$DETECTED_STACK + }.NET"
    DETECTED_STACK="${DETECTED_STACK:-.NET}"
  fi

  # --- Go ---
  if [ -f "$PROJECT_DIR/go.mod" ]; then
    DETECTED_BACKEND="${DETECTED_BACKEND:-Go}"
    DETECTED_TEST="${DETECTED_TEST:-go test}"
    DETECTED_BUILD="${DETECTED_BUILD:-go build ./...}"
    DETECTED_TEST_CMD="${DETECTED_TEST_CMD:-go test ./...}"
    DETECTED_LINT="${DETECTED_LINT:-golangci-lint run}"
    DETECTED_STACK="${DETECTED_STACK:-Go}"
  fi

  # --- Python ---
  if [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    # Detect Python framework
    local py_backend="Python"
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
      if grep -qi 'django' "$PROJECT_DIR/requirements.txt" 2>/dev/null; then py_backend="Python + Django"; fi
      if grep -qi 'fastapi' "$PROJECT_DIR/requirements.txt" 2>/dev/null; then py_backend="Python + FastAPI"; fi
      if grep -qi 'flask' "$PROJECT_DIR/requirements.txt" 2>/dev/null; then py_backend="Python + Flask"; fi
    fi
    if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
      if grep -qi 'django' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then py_backend="Python + Django"; fi
      if grep -qi 'fastapi' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then py_backend="Python + FastAPI"; fi
      if grep -qi 'flask' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then py_backend="Python + Flask"; fi
    fi
    DETECTED_BACKEND="${DETECTED_BACKEND:-$py_backend}"
    DETECTED_TEST="${DETECTED_TEST:-pytest}"
    DETECTED_BUILD="${DETECTED_BUILD:-python -m py_compile}"
    DETECTED_TEST_CMD="${DETECTED_TEST_CMD:-python -m pytest}"
    DETECTED_LINT="${DETECTED_LINT:-ruff check .}"
    DETECTED_STACK="${DETECTED_STACK:-Python}"
  fi

  # --- Rust ---
  if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    DETECTED_BACKEND="${DETECTED_BACKEND:-Rust}"
    DETECTED_TEST="${DETECTED_TEST:-cargo test}"
    DETECTED_BUILD="${DETECTED_BUILD:-cargo build}"
    DETECTED_TEST_CMD="${DETECTED_TEST_CMD:-cargo test}"
    DETECTED_LINT="${DETECTED_LINT:-cargo clippy}"
    DETECTED_STACK="${DETECTED_STACK:-Rust}"
  fi

  # --- Fallback ---
  DETECTED_STACK="${DETECTED_STACK:-Unknown}"
  DETECTED_BACKEND="${DETECTED_BACKEND:-Unknown}"
  DETECTED_FRONTEND="${DETECTED_FRONTEND:-None}"
  DETECTED_TEST="${DETECTED_TEST:-Unknown}"
  DETECTED_BUILD="${DETECTED_BUILD:-echo 'no build command configured'}"
  DETECTED_TEST_CMD="${DETECTED_TEST_CMD:-echo 'no test command configured'}"
  DETECTED_LINT="${DETECTED_LINT:-echo 'no lint command configured'}"
}

# ──────────────────────────────────────────────────────────────────────
# Step 2: Interactive prompts
# ──────────────────────────────────────────────────────────────────────
run_prompts() {
  echo ""
  printf "${BOLD}${GREEN}Forge Init${RESET} — AI-Powered Development Factory\n"
  echo ""
  printf "Detected stack: ${YELLOW}%s${RESET}\n" "$DETECTED_STACK"
  echo ""

  ask "Backend stack" "$DETECTED_BACKEND"
  USER_BACKEND="$REPLY"

  ask "Frontend stack" "$DETECTED_FRONTEND"
  USER_FRONTEND="$REPLY"

  ask "Test framework" "$DETECTED_TEST"
  USER_TEST="$REPLY"

  ask "Build command" "$DETECTED_BUILD"
  USER_BUILD="$REPLY"

  ask "Test command" "$DETECTED_TEST_CMD"
  USER_TEST_CMD="$REPLY"

  ask "Lint command" "$DETECTED_LINT"
  USER_LINT="$REPLY"

  ask "Feature files location" "$DETECTED_FEATURES"
  USER_FEATURES="$REPLY"

  ask "Frozen files (comma-separated)" "src/core/"
  USER_FROZEN="$REPLY"

  ask "CI tool" "github-actions"
  USER_CI="$REPLY"

  echo ""
}

# ──────────────────────────────────────────────────────────────────────
# Step 3: Create directory structure
# ──────────────────────────────────────────────────────────────────────
create_structure() {
  mkdir -p "$PROJECT_DIR/.claude/hooks"
  mkdir -p "$PROJECT_DIR/.claude/commands"
  mkdir -p "$PROJECT_DIR/agents"
  mkdir -p "$PROJECT_DIR/tasks"
  mkdir -p "$PROJECT_DIR/questions"
}

# ──────────────────────────────────────────────────────────────────────
# Step 4: Copy files from Forge repo
# ──────────────────────────────────────────────────────────────────────
copy_forge_files() {
  # Copy agents
  if [ -d "$FORGE_HOME/agents" ]; then
    cp "$FORGE_HOME/agents"/*.md "$PROJECT_DIR/agents/" 2>/dev/null || true
  fi

  # Copy hooks (make executable)
  if [ -d "$FORGE_HOME/hooks" ]; then
    cp "$FORGE_HOME/hooks"/*.sh "$PROJECT_DIR/.claude/hooks/" 2>/dev/null || true
    chmod +x "$PROJECT_DIR/.claude/hooks"/*.sh 2>/dev/null || true
  fi

  # Copy commands
  if [ -d "$FORGE_HOME/commands" ]; then
    cp "$FORGE_HOME/commands"/*.md "$PROJECT_DIR/.claude/commands/" 2>/dev/null || true
  fi
}

# ──────────────────────────────────────────────────────────────────────
# Step 5: Generate settings.json
# ──────────────────────────────────────────────────────────────────────
generate_settings() {
  # Build sparsePaths based on detected stack
  local sparse_paths=""

  # Always include core forge paths
  sparse_paths="$sparse_paths      \"agents/\",\n"
  sparse_paths="$sparse_paths      \"tasks/\",\n"
  sparse_paths="$sparse_paths      \"questions/\",\n"
  sparse_paths="$sparse_paths      \"CLAUDE.md\""

  # Add src/ if it exists
  if [ -d "$PROJECT_DIR/src" ]; then
    sparse_paths="      \"src/\",\n$sparse_paths"
  fi

  # Add tests/ or test/ if they exist
  if [ -d "$PROJECT_DIR/tests" ]; then
    sparse_paths="      \"tests/\",\n$sparse_paths"
  elif [ -d "$PROJECT_DIR/test" ]; then
    sparse_paths="      \"test/\",\n$sparse_paths"
  fi

  # Add feature files location
  local feat_dir="$USER_FEATURES"
  # Strip trailing slash for comparison
  feat_dir="${feat_dir%/}"
  if [ "$feat_dir" != "tests/features" ] && [ "$feat_dir" != "test/features" ] && [ "$feat_dir" != "tests" ] && [ "$feat_dir" != "test" ] && [ "$feat_dir" != "src" ]; then
    sparse_paths="      \"${USER_FEATURES}\",\n$sparse_paths"
  fi

  # Build permissions based on stack
  local allow_perms=""
  allow_perms="$allow_perms      \"Bash(git:*)\",\n"
  allow_perms="$allow_perms      \"Bash(ls:*)\",\n"
  allow_perms="$allow_perms      \"Bash(cat:*)\",\n"
  allow_perms="$allow_perms      \"Bash(find:*)\",\n"
  allow_perms="$allow_perms      \"Bash(mv:*)\",\n"
  allow_perms="$allow_perms      \"Bash(cp:*)\",\n"
  allow_perms="$allow_perms      \"Bash(mkdir:*)\",\n"
  allow_perms="$allow_perms      \"Bash(echo:*)\",\n"
  allow_perms="$allow_perms      \"Bash(grep:*)\",\n"
  allow_perms="$allow_perms      \"Bash(touch:*)\",\n"
  allow_perms="$allow_perms      \"Bash(gh:*)\""

  # Add stack-specific permissions
  case "$DETECTED_STACK" in
    *Node*)
      allow_perms="$allow_perms,\n      \"Bash(npm:*)\",\n      \"Bash(npx:*)\",\n      \"Bash(node:*)\""
      ;;
    *.NET*)
      allow_perms="$allow_perms,\n      \"Bash(dotnet:*)\""
      ;;
    *Go*)
      allow_perms="$allow_perms,\n      \"Bash(go:*)\""
      ;;
    *Python*)
      allow_perms="$allow_perms,\n      \"Bash(python:*)\",\n      \"Bash(pip:*)\",\n      \"Bash(ruff:*)\""
      ;;
    *Rust*)
      allow_perms="$allow_perms,\n      \"Bash(cargo:*)\",\n      \"Bash(rustc:*)\""
      ;;
  esac

  # Write settings.json
  printf '{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "worktree": {
    "sparsePaths": [\n%b\n    ]
  },
  "hooks": {
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash -c '"'"'echo \\"[COMPACT] $(date -Iseconds) — context compacted in $(pwd)\\" >> .claude/compact-log.txt'"'"'"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/guard-shared.sh"
          },
          {
            "type": "command",
            "command": "bash .claude/hooks/guard-feature.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/verify-before-push.sh"
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [\n%b\n    ],
    "deny": [
      "Bash(curl:*)",
      "Bash(wget:*)",
      "Bash(ssh:*)",
      "Bash(docker:*)",
      "Bash(kubectl:*)"
    ]
  }
}\n' "$sparse_paths" "$allow_perms" > "$PROJECT_DIR/.claude/settings.json"
}

# ──────────────────────────────────────────────────────────────────────
# Step 6: Generate CLAUDE.md from template
# ──────────────────────────────────────────────────────────────────────
generate_claude_md() {
  if [ ! -f "$FORGE_HOME/templates/claude-md-template.md" ]; then
    echo "WARNING: Template claude-md-template.md not found, skipping CLAUDE.md generation."
    return
  fi

  # Build frozen files list for template
  local frozen_list=""
  IFS=',' read -ra FROZEN_ITEMS <<< "$USER_FROZEN"
  for item in "${FROZEN_ITEMS[@]}"; do
    # Trim whitespace
    item="$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    frozen_list="${frozen_list}- \`${item}\`\n"
  done
  # Remove trailing newline
  frozen_list="${frozen_list%\\n}"

  # Generate a simple project structure
  local project_struct
  project_struct="$(ls -1 "$PROJECT_DIR" | grep -v '^\.' | head -20 | sed 's/^/  /')"

  # Copy template and replace placeholders
  sed \
    -e "s|{YOUR_BACKEND_STACK}|${USER_BACKEND}|g" \
    -e "s|{YOUR_FRONTEND_STACK}|${USER_FRONTEND}|g" \
    -e "s|{YOUR_TEST_FRAMEWORK}|${USER_TEST}|g" \
    -e "s|{YOUR_CI_TOOL}|${USER_CI}|g" \
    -e "s|{YOUR_BUILD_COMMAND}|${USER_BUILD}|g" \
    -e "s|{YOUR_TEST_COMMAND}|${USER_TEST_CMD}|g" \
    "$FORGE_HOME/templates/claude-md-template.md" > "$PROJECT_DIR/CLAUDE.md"

  # Replace multi-line placeholders with sed-safe approach
  # Replace frozen files list
  local escaped_frozen
  escaped_frozen="$(echo -e "$frozen_list")"
  # Use a temp file approach for multi-line replacements
  local tmpfile
  tmpfile="$(mktemp)"
  while IFS= read -r line; do
    if echo "$line" | grep -q '{LIST YOUR FROZEN FILES/DIRECTORIES}'; then
      echo -e "$frozen_list"
    elif echo "$line" | grep -q '{YOUR_PROJECT_STRUCTURE}'; then
      echo "$project_struct"
    else
      echo "$line"
    fi
  done < "$PROJECT_DIR/CLAUDE.md" > "$tmpfile"
  mv "$tmpfile" "$PROJECT_DIR/CLAUDE.md"
}

# ──────────────────────────────────────────────────────────────────────
# Step 7: Generate verify-before-push.sh with actual commands
# ──────────────────────────────────────────────────────────────────────
generate_verify_hook() {
  cat > "$PROJECT_DIR/.claude/hooks/verify-before-push.sh" << 'HOOK_HEADER'
#!/usr/bin/env bash
# Hook PreToolUse (Bash matcher) — blocks git push if build/tests fail
# Only triggers on "git push" commands.
# Generated by forge-init.sh

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

HOOK_HEADER

  # Add lint command if not a no-op
  if ! echo "$USER_LINT" | grep -q '^echo '; then
    cat >> "$PROJECT_DIR/.claude/hooks/verify-before-push.sh" << EOF
$USER_LINT || { echo "BLOCKED: lint failed"; exit 2; }

EOF
  fi

  # Add build command
  if ! echo "$USER_BUILD" | grep -q '^echo '; then
    cat >> "$PROJECT_DIR/.claude/hooks/verify-before-push.sh" << EOF
$USER_BUILD || { echo "BLOCKED: build failed"; exit 2; }

EOF
  fi

  # Add test command
  if ! echo "$USER_TEST_CMD" | grep -q '^echo '; then
    cat >> "$PROJECT_DIR/.claude/hooks/verify-before-push.sh" << EOF
$USER_TEST_CMD || { echo "BLOCKED: tests failed"; exit 2; }

EOF
  fi

  cat >> "$PROJECT_DIR/.claude/hooks/verify-before-push.sh" << 'HOOK_FOOTER'
echo "All checks passed. Push allowed."
exit 0
HOOK_FOOTER

  chmod +x "$PROJECT_DIR/.claude/hooks/verify-before-push.sh"
}

# ──────────────────────────────────────────────────────────────────────
# Step 8: Generate guard-shared.sh with actual frozen paths
# ──────────────────────────────────────────────────────────────────────
generate_guard_shared() {
  # Build grep pattern from frozen files
  local frozen_pattern=""
  IFS=',' read -ra FROZEN_ITEMS <<< "$USER_FROZEN"
  for item in "${FROZEN_ITEMS[@]}"; do
    item="$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    # Escape slashes for grep
    local escaped
    escaped="$(echo "$item" | sed 's|/|\\/|g')"
    if [ -n "$frozen_pattern" ]; then
      frozen_pattern="${frozen_pattern}|${escaped}"
    else
      frozen_pattern="${escaped}"
    fi
  done

  cat > "$PROJECT_DIR/.claude/hooks/guard-shared.sh" << GUARD_EOF
#!/usr/bin/env bash
# Hook PreToolUse — blocks writes to frozen files without explicit authorization
# Generated by forge-init.sh

INPUT=\$(cat)

FILE_PATH=\$(echo "\$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
inp = data.get('tool_input', {})
print(inp.get('file_path') or inp.get('path') or inp.get('target_file') or '')
" 2>/dev/null)

if [ -z "\$FILE_PATH" ]; then exit 0; fi

if echo "\$FILE_PATH" | grep -qE "${frozen_pattern}"; then
  AUTHORIZED=\$(grep -rl "MODIFY_FROZEN: authorized" tasks/wip-*.md 2>/dev/null | wc -l)
  if [ "\$AUTHORIZED" -eq 0 ]; then
    echo "BLOCKED: modification of frozen files is forbidden without explicit authorization."
    echo "Add 'MODIFY_FROZEN: authorized' in your wip-*.md task and create questions/{task-id}-frozen-change.md for arbitration."
    exit 2
  fi
fi

exit 0
GUARD_EOF

  chmod +x "$PROJECT_DIR/.claude/hooks/guard-shared.sh"
}

# ──────────────────────────────────────────────────────────────────────
# Step 9: Summary
# ──────────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  printf "${GREEN}${BOLD}Forge initialized successfully!${RESET}\n"
  echo ""
  printf "${BOLD}Created:${RESET}\n"

  # List created files
  local files=(
    ".claude/settings.json"
    ".claude/hooks/guard-feature.sh"
    ".claude/hooks/guard-shared.sh"
    ".claude/hooks/verify-before-push.sh"
  )

  # Add commands
  for f in "$PROJECT_DIR/.claude/commands"/*.md; do
    [ -f "$f" ] && files+=(".claude/commands/$(basename "$f")")
  done

  # Add agents
  for f in "$PROJECT_DIR/agents"/*.md; do
    [ -f "$f" ] && files+=("agents/$(basename "$f")")
  done

  files+=("CLAUDE.md")

  for f in "${files[@]}"; do
    printf "  ${DIM}%s${RESET}\n" "$f"
  done

  echo ""
  printf "${BOLD}Next steps:${RESET}\n"
  printf "  1. Review ${CYAN}CLAUDE.md${RESET} and adjust to your project\n"
  printf "  2. Run: ${CYAN}claude${RESET}\n"
  printf "  3. Type: ${CYAN}/kickoff${RESET}\n"
  echo ""
}

# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────
main() {
  # Check if already initialized
  if [ -f "$PROJECT_DIR/CLAUDE.md" ] && [ -d "$PROJECT_DIR/.claude/hooks" ]; then
    printf "${YELLOW}WARNING: Forge appears to already be initialized in this directory.${RESET}\n"
    printf "${CYAN}? ${RESET}${BOLD}Overwrite existing files?${RESET} ${DIM}[y/N]${RESET}: "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
      echo "Aborted."
      exit 0
    fi
    echo ""
  fi

  detect_stack
  run_prompts
  create_structure
  copy_forge_files
  generate_settings
  generate_claude_md
  generate_verify_hook
  generate_guard_shared
  print_summary
}

main "$@"

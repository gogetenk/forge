# Getting Started with Forge

> From zero to your first orchestrated build in 15 minutes.

## Prerequisites

- [Claude Code CLI](https://claude.com/claude-code) v2.1.72+
- Git
- GitHub CLI (`gh`) authenticated
- A GitHub repository with CI/CD configured
- Your project's build and test commands working locally

## Step 1 — Install Forge in your project

```bash
# Clone the Forge repo
git clone https://github.com/gogetenk/forge.git /tmp/forge

# Create the required directories in your project
mkdir -p .claude/hooks .claude/commands agents tasks questions

# Copy the agents
cp /tmp/forge/agents/*.md agents/

# Copy the hooks
cp /tmp/forge/hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh

# Copy the slash commands
cp /tmp/forge/commands/*.md .claude/commands/

# Copy the settings template
cp /tmp/forge/templates/settings.json .claude/settings.json
```

## Step 2 — Configure CLAUDE.md

Copy the template and fill in your stack details:

```bash
cp /tmp/forge/templates/claude-md-template.md CLAUDE.md
```

Edit `CLAUDE.md` and replace all `{PLACEHOLDER}` values:
- `{YOUR_BACKEND_STACK}` → e.g., "Node.js 22, Express, TypeScript"
- `{YOUR_FRONTEND_STACK}` → e.g., "React 19, Vite, Tailwind"
- `{YOUR_TEST_FRAMEWORK}` → e.g., "Vitest + Playwright"
- `{YOUR_BUILD_COMMAND}` → e.g., "npm run build"
- `{YOUR_TEST_COMMAND}` → e.g., "npm test"
- `{YOUR_PROJECT_STRUCTURE}` → your actual folder tree
- Frozen files list → files agents must never modify

## Step 3 — Configure hooks

Edit `.claude/hooks/verify-before-push.sh` and uncomment/add your build+test commands:

```bash
# For Node.js projects:
npm run lint || { echo "BLOCKED: lint failed"; exit 2; }
npm run build || { echo "BLOCKED: build failed"; exit 2; }
npm test || { echo "BLOCKED: tests failed"; exit 2; }
```

Edit `.claude/hooks/guard-shared.sh` and update the frozen paths regex:

```bash
# Replace "Shared/" with your frozen directories
if echo "$FILE_PATH" | grep -qE "^src/core/|/migrations/"; then
```

## Step 4 — Configure settings.json

Edit `.claude/settings.json` and update `worktree.sparsePaths` to match your project:

```json
"worktree": {
  "sparsePaths": [
    "src/",
    "tests/",
    "agents/",
    "tasks/",
    "CLAUDE.md"
  ]
}
```

## Step 5 — Write your first .feature files

The PO writes Gherkin specs describing expected behavior:

```gherkin
# tests/features/auth/login.feature
Feature: User authentication

  Scenario: Valid credentials grant access
    Given a registered user with email "user@example.com"
    When the user logs in with valid credentials
    Then the user is authenticated

  Scenario: Invalid credentials are rejected
    Given a registered user with email "user@example.com"
    When the user logs in with wrong password
    Then the login is rejected
    And an error message is displayed
```

## Step 6 — Create your first tasks

```bash
cat > tasks/todo-back-auth-001.md << 'EOF'
# todo-back-auth-001.md — Implement authentication

**Dependencies**: none
**Skills**: your-stack-specific-skills

## Objective
Implement login endpoint with email/password validation.

## Gherkin
See tests/features/auth/login.feature

## Completion criteria
- [ ] All Gherkin scenarios GREEN
- [ ] Unit tests GREEN
- [ ] PR created towards develop
EOF
```

## Step 7 — Launch Forge

```bash
# Start Claude Code
claude

# Run a single cycle
/forge

# Or start the continuous loop (every 15 min)
/loop 15m /forge
```

## Step 8 — Monitor

```bash
# Quick status
/status

# Check progress
cat progress.md

# Check for blocked agents
cat questions/*.md
```

## What happens next

The orchestrator will:
1. Check develop CI is GREEN
2. Find your `todo-back-auth-001.md` task
3. Rename it to `wip-back-auth-001.md` (claim)
4. Dispatch an agent in an isolated worktree
5. The agent reads the task + .feature, implements, tests, creates a PR
6. Copilot reviews the PR automatically
7. If all checks pass → orchestrator merges
8. Rename to `done-back-auth-001.md`

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues.

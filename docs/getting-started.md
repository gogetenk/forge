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

## Step 4 — Kickoff: build your backlog with the PO agent

**This is the key step.** You don't create tasks manually — you describe your project to the PO agent, and it builds the complete backlog with you through a structured Q&A.

```bash
claude
# Then type:
/kickoff
```

The PO agent will:
1. Ask you to describe your project (what it does, who it's for)
2. Ask clarifying questions about modules, roles, business rules, edge cases
3. Propose a module breakdown for your validation
4. Write all `.feature` files in natural language (your acceptance criteria)
5. Create all `todo-*.md` task files with proper dependencies
6. Present the complete backlog with a dependency graph

**Example session:**

```
You:  /kickoff

PO:   Tell me about your project. What does it do, who is it for?

You:  It's a veterinary clinic management app for the UAE market.
      Vets manage appointments, medical records, billing. Pet owners
      can book online. Multi-tenant — each clinic is isolated.

PO:   Great. A few questions:
      - What user roles? (vet, receptionist, owner, admin?)
      - Is billing per-consultation or subscription?
      - What languages? English + Arabic?
      - Any regulatory requirements?

You:  Roles: vet, receptionist, assistant, owner, admin.
      Billing per-consultation with VAT 5%.
      English first, Arabic later. No specific regulation yet.

PO:   Here's my proposed module breakdown:
      1. Auth — signup, login, RBAC, multi-tenant
      2. Agenda — appointments, calendar, availability
      3. Patients — pet registry, owner management
      4. Medical Records — consultations, prescriptions
      5. Billing — invoices, payments, PDF
      6. Notifications — email, SMS reminders
      Does this look right? Anything missing?

You:  Add a Dashboard module for clinic analytics. Otherwise good.

PO:   Writing .feature files and tasks...
      [creates 40+ .feature scenarios across 7 modules]
      [creates 25+ todo-*.md task files with dependencies]

      Backlog ready:
      - 7 modules, 27 tasks
      - Max parallelism: 12 agents
      - Critical path: scaffold → auth → agenda → wire
      Ready for /forge?

You:  /forge
```

**Important:** Don't rush the Q&A. The better the PO understands your domain, the better the .feature files, and the less the agents will deviate.

## Step 5 — Launch the factory

Once the backlog is ready:

```bash
# Run a single cycle to verify everything works
/forge

# Then start the continuous loop
/loop 15m /forge
```

## Step 6 — Monitor

```bash
# Quick status
/status

# Check progress
cat progress.md

# Check for blocked agents with business questions
cat questions/*.md

# Answer questions (as PO)
/po
```

## What happens next

The orchestrator will:
1. Check develop CI is GREEN
2. Find ready `todo-*.md` tasks (dependencies satisfied)
3. Rename to `wip-*.md` (claim)
4. Dispatch dev agents in isolated worktrees (max parallelism)
5. Each agent reads its task + .feature, implements via TDD, creates a PR
6. Copilot reviews the PR automatically
7. QA agent validates with Playwright screenshots
8. Designer agent checks visual consistency
9. If all green → orchestrator merges
10. Rename to `done-*.md`
11. When back + front are both done → auto-creates wire task
12. Repeat every 15 minutes

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and lessons learned.

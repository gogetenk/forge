# Forge — AI-Powered Development Factory

> Zero-trust multi-agent orchestration for building fully functional systems with Claude Code.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

---

## What is Forge?

Forge is a **process + tooling framework** that lets multiple AI coding agents work in parallel on the same project, without conflicts, and with strict quality guardrails.

One **orchestrator** distributes work. Isolated **dev agents** each build one feature in their own git worktree and deliver a PR. The **human (PO)** controls the specs (Gherkin), reviews, and business decisions — never the code. Mechanical **hooks and checks** enforce every rule automatically.

**Core principle: if a rule isn't enforced by a mechanism, it will be violated.** Conventions don't work with AI agents. Every critical rule has a hook, a CI check, or an automatic block.

### For what kind of project?

- **MVP / v1** with independent modules that can be parallelized
- **Well-defined stack** — agents need clear conventions, no improvisation
- **Available PO** to write Gherkin specs and answer questions
- **CI/CD in place** — the loop relies on a pipeline to validate each PR

Not suited for: legacy code without tests, exploratory R&D, or solo projects.

### Battle-tested numbers (Vetolib MVP)

- **234+ tasks** completed in days, not weeks
- **682 tests** (unit + integration + acceptance) — all green
- **10+ agents** in parallel with zero conflicts

---

## How it works

See [`docs/forge-overview.md`](docs/forge-overview.md) for the full process documentation with Mermaid diagrams.

### Quick overview

```
Human (PO) writes .feature specs
       |
       v
   Orchestrator (/forge loop every 15 min)
       |
       +-- dispatches Agent back-auth (worktree)
       +-- dispatches Agent front-auth (worktree, MSW mocks)
       +-- dispatches Agent back-agenda (worktree)
       +-- dispatches Agent front-agenda (worktree, MSW mocks)
       +-- ...N agents in parallel
       |
       v
   Each agent creates a PR towards develop
       |
       v
   Copilot review → QA agent (Playwright) → Designer agent
       |
       v
   Merge to develop (CI must stay GREEN)
```

### Key concepts

| Concept | Description |
|---|---|
| **BDD-first** | PO writes `.feature` files before any code. Agents make them pass. |
| **Zero trust** | Every rule enforced by hooks/CI, never by convention |
| **File-based tasks** | `todo-*.md` → `wip-*.md` → `done-*.md` (atomic rename = state transition) |
| **Worktree isolation** | Each agent works in its own git worktree, own branch, own PR |
| **MSW-first** | Frontend starts immediately with mock API (Mock Service Worker) |
| **QA + Designer** | Playwright screenshots validate behavior AND visual consistency |
| **Fail-fast** | Agent blocked? Writes to `questions/` and stops |

---

## Repository structure

```
forge/
├── docs/
│   └── forge-overview.md          # Full process doc with Mermaid diagrams
├── agents/
│   ├── orchestrator.md            # Orchestrator behavior and loop
│   ├── qa.md                      # QA agent (Playwright + screenshots)
│   └── designer.md                # Designer agent (visual consistency)
├── hooks/
│   ├── guard-feature.sh           # Blocks technical jargon in .feature files
│   ├── guard-shared.sh            # Blocks writes to frozen files
│   └── verify-before-push.sh      # Build + tests must pass before push
├── templates/
│   ├── settings.json              # Claude Code settings with hooks configured
│   ├── task-template.md           # Task file template
│   └── claude-md-template.md      # CLAUDE.md rules template
├── commands/
│   ├── forge.md                   # /forge slash command
│   ├── dev.md                     # /dev slash command
│   ├── status.md                  # /status slash command
│   └── po.md                      # /po slash command
├── NOTICE                         # Attribution notice (required by Apache 2.0)
├── LICENSE                        # Apache License 2.0
└── README.md
```

---

## Getting started

### 1. Copy the structure into your project

```bash
# Clone forge
git clone https://github.com/gogetenk/forge.git

# Copy agents, hooks, and commands to your project
cp -r forge/agents/ your-project/agents/
cp -r forge/hooks/ your-project/.claude/hooks/
cp -r forge/commands/ your-project/.claude/commands/
cp forge/templates/settings.json your-project/.claude/settings.json
```

### 2. Adapt CLAUDE.md

Use `templates/claude-md-template.md` as a starting point. Fill in your stack, modules, and frozen files.

### 3. Write your first .feature files

The PO writes Gherkin specs in `tests/*/Features/`. These are the acceptance criteria for agents.

### 4. Create task files

```bash
# One task per feature, per module
echo "# todo-back-auth-001.md — Implement login" > tasks/todo-back-auth-001.md
```

### 5. Launch

```bash
claude
# Then type: /forge
# Or for continuous: /loop 15m /forge
```

---

## Adapting Forge to your stack

Forge is **stack-agnostic** in its orchestration layer. The examples use .NET + Next.js, but the process works with any stack. You need to adapt:

| What to adapt | Where |
|---|---|
| Build/test commands | `hooks/verify-before-push.sh`, `CLAUDE.md` |
| Test framework | `.feature` location, step definitions format |
| Frontend mock strategy | MSW or equivalent |
| CI pipeline | Your CI/CD tool |
| Frozen files list | `CLAUDE.md` + `hooks/guard-shared.sh` |

The **process** (orchestrator loop, task lifecycle, QA/Designer gates, zero-trust hooks) stays the same regardless of stack.

---

## Contributing

Contributions welcome. Please open an issue before submitting a PR for significant changes.

All contributions are under the Apache License 2.0. See [NOTICE](NOTICE) for attribution requirements.

---

## Author

**Yannis TOCREAU** — Creator and maintainer of Forge.

- GitHub: [@gogetenk](https://github.com/gogetenk)

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Copyright 2026 Yannis TOCREAU. See [NOTICE](NOTICE) for details.

<p align="center">
  <img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Claude_Code-v2.1+-green.svg" alt="Claude Code">
  <img src="https://img.shields.io/badge/Status-The_Forge_Never_Sleeps-orange.svg" alt="Status">
</p>

<h1 align="center">Forge</h1>

<p align="center">
  <strong>The factory that never sleeps.</strong><br>
  While you're away, your agents keep building, testing, fixing, improving.<br>
  You wake up to a better product than the one you left.
</p>

---

<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/6bb29fc9-15b8-4a51-810a-60d77f088e51" />


## The idea

You describe what you want to build. You go to sleep.

While you sleep, a dozen AI agents work in parallel — each in its own isolated workspace, each on its own task. One builds the login. Another builds the dashboard. A third writes the billing module. They don't step on each other. They don't cut corners. They can't — mechanical guardrails make it physically impossible.

Every 15 minutes, an orchestrator wakes up. It checks what's done, what's stuck, what's next. It merges finished work, dispatches new agents, kills the ones going in circles. It never stops.

When you wake up, there are PRs merged, tests green, screenshots taken. The QA agent tested every screen overnight. The Designer agent flagged a button that was 2px off. A dev agent already fixed it.

**The forge never goes out.** When there are no more features to build, agents start testing. When there are no more bugs, they start optimizing. When there's nothing left to optimize, they review each other's code. The fire keeps burning.

That's Forge.

---

## What is it, concretely?

Forge is a **process + tooling framework** for [Claude Code](https://claude.com/claude-code) that orchestrates multiple AI agents to build software in parallel, with zero-trust mechanical guardrails.

```
You describe your project
       |
       v
   /kickoff → PO agent builds your backlog via Q&A
       |  (writes acceptance specs + task files)
       v
   /forge → Orchestrator loop (every 15 min, never stops)
       |
       +-- Agent back-auth --------\
       +-- Agent front-auth --------+-- each in its own
       +-- Agent back-billing ------+-- git worktree
       +-- Agent front-dashboard ---/
       |
       v
   Copilot review → QA (screenshots) → Designer (visual check)
       |
       v
   Auto-merge to develop (CI must stay GREEN)
       |
       v
   No more tasks? → Agents test, optimize, review.
   The forge never sleeps.
```

### Core principles

| Principle | What it means |
|---|---|
| **The forge never sleeps** | Agents always find something to do — build, test, fix, optimize, review |
| **Zero trust** | Every rule enforced by hooks and CI, never by convention. If it's not mechanical, it will be violated |
| **BDD-first** | The PO writes specs in Gherkin before any code. Agents make them pass. That's it |
| **Isolation** | Each agent works in its own git worktree. Impossible to break someone else's work |
| **Fail-fast** | Blocked? Write a question and stop. Never guess, never improvise |

### Numbers (Vetolib MVP — battle-tested)

- **234+ tasks** completed in days, not weeks
- **682 tests** — all green
- **10+ agents** in parallel, zero conflicts
- **46 screens** tested via Playwright overnight
- **0 human lines of code** — only specs and reviews

---

## Getting started

### 1. Install

```bash
git clone https://github.com/gogetenk/forge.git
cd your-project
bash /path/to/forge/bin/forge-init.sh
```

The init script auto-detects your stack, asks a few questions, and sets up everything.

### 2. Describe your project

```bash
claude
/kickoff
```

The PO agent leads a Q&A session. You describe your product in plain language. It produces the full backlog: acceptance specs (`.feature`) and task files (`todo-*.md`) with dependencies.

### 3. Light the forge

```bash
/loop 15m /forge
```

Go grab a coffee. Or go to sleep. The forge takes it from here.

---

## What happens while you sleep

```
 00:00  Orchestrator wakes up. 12 tasks ready. Dispatches 12 agents.
 00:15  8 PRs created. Copilot reviews them. 2 have suggestions → flagged.
 00:30  QA agent tests the 6 merged screens. Takes 47 screenshots.
        Designer agent flags a color inconsistency on the billing page.
 00:45  Orchestrator creates fix task. Dev agent patches it in 3 minutes.
 01:00  All screens green. No more feature tasks. Agents start testing edge cases.
 01:15  QA finds a responsive bug on mobile. Fix task created and dispatched.
 01:30  Zero bugs remaining. Agents review each other's code for DRY violations.
 ...
 07:00  You wake up. 34 tasks done. All tests green. 12 PRs merged.
        The forge kept the fire burning all night.
```

---

## Repository structure

```
forge/
├── bin/
│   └── forge-init.sh              # Interactive setup wizard
├── docs/
│   ├── forge-overview.md          # Full process doc with Mermaid diagrams
│   ├── getting-started.md         # Zero to first build guide
│   ├── troubleshooting.md         # Lessons learned from production
│   └── roadmap.md                 # What's next
├── agents/
│   ├── orchestrator.md            # The conductor — never codes, always watches
│   ├── po.md                      # Product Owner — writes specs, answers questions
│   ├── qa.md                      # QA — Playwright screenshots, behavior validation
│   └── designer.md                # Designer — visual consistency, design system
├── hooks/
│   ├── guard-feature.sh           # Blocks technical jargon in specs
│   ├── guard-shared.sh            # Blocks writes to frozen files
│   └── verify-before-push.sh      # Build + tests must pass before push
├── templates/
│   ├── settings.json              # Claude Code settings with hooks
│   ├── task-template.md           # Task file template
│   └── claude-md-template.md      # Project rules template
├── commands/
│   ├── kickoff.md                 # /kickoff — bootstrap the backlog
│   ├── forge.md                   # /forge — run the orchestrator
│   ├── dev.md                     # /dev — launch a single agent
│   ├── status.md                  # /status — quick factory status
│   └── po.md                      # /po — handle business questions
├── examples/
│   ├── dotnet-nextjs/             # .NET + Next.js (battle-tested)
│   ├── node-react/                # Node.js + React + Cucumber.js
│   ├── python-fastapi/            # Python + FastAPI + behave
│   └── go-htmx/                   # Go + htmx + godog
├── NOTICE                         # Attribution
├── LICENSE                        # Apache 2.0
├── CONTRIBUTING.md
└── README.md
```

---

## Adapting to your stack

Forge is **stack-agnostic**. The orchestration layer (task lifecycle, agent dispatch, QA gates, hooks) works the same regardless of your tech. You adapt:

| What | Where |
|---|---|
| Build/test commands | `hooks/verify-before-push.sh` |
| BDD framework | Reqnroll, Cucumber.js, behave, godog — your pick |
| Frontend mocks | MSW or equivalent |
| Frozen files | `hooks/guard-shared.sh` |

See `examples/` for ready-to-use configs.

---

## Contributing

The forge is open. Contributions welcome — especially stack examples, hook improvements, and battle-tested troubleshooting tips.

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Author

**Yannis TOCREAU** — Creator of Forge.

[@gogetenk](https://github.com/gogetenk)

---

<p align="center">
  <em>The forge never sleeps. Your product gets better every hour, even while you dream.</em>
</p>

---

Apache License 2.0 — Copyright 2026 Yannis TOCREAU. See [NOTICE](NOTICE).

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

<p align="center">
  <img width="512" alt="The Forge" src="https://github.com/user-attachments/assets/6bb29fc9-15b8-4a51-810a-60d77f088e51" />
</p>

<p align="center"><em>Rest here, traveler. The forge keeps burning.</em></p>

---

## The promise

**You describe what you want. You go to sleep. You wake up to a working product.**

That's it. That's Forge.

No micro-managing agents. No babysitting builds. No "let me check if the tests pass." You light the forge, and it burns until there's nothing left to improve. Features get built, tests get written, bugs get found and fixed, UX gets polished — all while you sleep.

The forge **never** goes out:
- No more features to build? Agents start **testing** every screen.
- No more bugs? Agents start **optimizing** performance.
- Nothing to optimize? Agents **review** each other's code.
- Still nothing? They **audit** accessibility, check responsive, validate the design system.

The fire always has fuel.

---

## How it works (30 seconds)

```
Step 1:  You describe your project to the PO agent        →  /kickoff
Step 2:  PO builds the full backlog via Q&A with you       →  .feature specs + task files
Step 3:  You light the forge                               →  /loop 15m /forge
Step 4:  Go to sleep.
```

That's the last thing you do. From here, the forge runs itself:

```
 00:00  Orchestrator wakes up. 12 tasks ready. Dispatches 12 agents.
 00:15  8 PRs created. Copilot reviews them. 2 have suggestions → flagged.
 00:30  QA agent tests 6 merged screens. Takes 47 screenshots.
        Designer agent flags a button 2px off the grid.
 00:45  Orchestrator creates fix task. Dev agent patches it in 3 minutes.
 01:00  All green. Agents start testing edge cases.
 01:15  QA finds a responsive bug on mobile. Fix dispatched.
 01:30  Zero bugs. Agents review each other's code.
 ...
 07:00  You wake up. 34 tasks done. 12 PRs merged. All tests green.
        The forge kept the fire burning all night.
```

---

## Key mechanisms (and why they exist)

### 📋 BDD-first: Gherkin specs are the leash

The PO writes acceptance criteria in Gherkin (`.feature` files) **before any code exists**. Dev agents receive these specs and have one job: make them pass. They can't deviate — if the Gherkin says "the appointment is confirmed", the agent can't decide to return a JSON payload instead. The spec IS the definition of done.

A hook (`guard-feature.sh`) **mechanically blocks** agents from writing technical jargon in specs. Without it, agents drift toward `the response status is 200` instead of `the operation succeeds`. We learned this the hard way — 52 HTTP codes ended up in our Gherkin before we added the hook.

**Problem solved:** AI agents interpret requirements loosely. Gherkin + TDD forces them to implement exactly what was specified, nothing more, nothing less.

### 📁 File-based tasks: faster than any ticket system

Tasks are markdown files. `todo-auth-001.md` → `wip-auth-001.md` → `done-auth-001.md`. A `rename` is the state transition.

Why not Jira/Linear/Trello? Because:
- **Zero network latency** — the filesystem is instant, no API calls
- **Atomic locking** — renaming a file is atomic on any OS. No race conditions
- **Git-native** — tasks are versioned, diffable, searchable with grep
- **Agent-readable** — no OAuth, no SDK, no API wrapper. Just `cat tasks/todo-*.md`
- **Human-readable** — open the folder, see the state. No dashboard needed

**Problem solved:** Agents need fast, reliable, zero-latency task coordination. The filesystem does this better than any SaaS.

### 🔀 Worktree isolation: agents can't break each other

Each agent works in its own `git worktree` — a separate checkout of the repo on its own branch. Agent A building auth can't accidentally overwrite Agent B's billing code. They share the same repo but never touch the same files.

**Problem solved:** 10+ agents writing code simultaneously would create merge hell without isolation.

### 🔒 Zero trust hooks: mechanical, not conventional

Every critical rule has a bash hook that blocks violations **before they happen**:
- Write to a frozen file? → Blocked by `guard-shared.sh`
- Push without passing tests? → Blocked by `verify-before-push.sh`
- Write HTTP codes in a Gherkin spec? → Blocked by `guard-feature.sh`

**Problem solved:** AI agents don't follow conventions reliably. Mechanical blocks are the only reliable enforcement.

### ⚡ MSW-first: frontend doesn't wait for backend

Frontend agents start immediately with Mock Service Worker (MSW) — they build against a fake API. Backend agents build the real API in parallel. When both are done, a "wire" task connects them. This doubles the parallelism.

**Problem solved:** Sequential front-then-back development wastes half the available agents.

---

## Requirements

### What you need

- **[Claude Code CLI](https://claude.com/claude-code)** v2.1.72+ — this is the engine
- **[Claude Max or Team plan](https://claude.com/pricing)** — Forge runs agents continuously, you need a plan with high usage limits. Max ($100/mo) gives you unlimited Claude Code usage. Team ($30/seat/mo) works for smaller projects but will hit rate limits faster with 10+ parallel agents. **Max is strongly recommended for the "forge never sleeps" experience.**
- **Git + GitHub CLI** (`gh`) authenticated
- **A GitHub repo with CI/CD** configured

### Why Claude Max?

Forge dispatches **10+ agents in parallel**, each in its own context window. On a standard plan, you'll hit rate limits within minutes. Claude Max gives you:
- Unlimited Claude Code usage (no rate limits)
- The ability to run `/loop 15m /forge` overnight without interruption
- The full "go to sleep, wake up to a finished product" experience

Without Max, Forge still works — it just pauses when rate-limited and resumes when capacity frees up. The forge dims but doesn't go out.

---

## Getting started

### 1. Install

```bash
git clone https://github.com/gogetenk/forge.git
cd your-project
bash /path/to/forge/bin/forge-init.sh
```

The init script copies the forge structure into your project.

### 2. Kickoff — configure agents and build your backlog

```bash
claude
/kickoff
```

The kickoff runs 5 phases:

1. **Detect** — auto-detects your stack (Node.js, .NET, Python, Go, Rust), build/test commands, module structure, CI/CD
2. **PO Q&A** — you describe your project in plain language, the PO agent asks clarifying questions
3. **Instantiate agents** — templates from `templates/agents/` are customized for your stack and written to `.claude/agents/`
4. **Generate project files** — CLAUDE.md, settings.json, hooks, directories
5. **Build backlog** — `.feature` specs + `todo-*.md` task files with dependency graph

**Don't rush step 2.** The better the PO understands your domain, the better the agents will build it.

> **Manual setup alternative:** If you prefer to configure manually, copy templates from `templates/agents/` to `.claude/agents/`, replace the `{VARIABLES}` with your stack values, and customize `templates/claude-md-template.md` into your `CLAUDE.md`. The orchestrator (`agents/orchestrator.md`) works out of the box — no customization needed.

### 3. Light the forge

```bash
/loop 15m /forge
```

Go grab a coffee. Or go to sleep. The forge takes it from here.

See [`docs/getting-started.md`](docs/getting-started.md) for a full walkthrough with example session.

---

## Autonomous mode: the forge that never sleeps

The real power of Forge is **autonomous continuous operation**. Here's how to set it up:

### The loop

```bash
/loop 15m /forge
```

This runs the full orchestrator cycle every 15 minutes. It auto-expires after 3 days (Claude Code safety limit). To restart:

```bash
/loop 15m /forge   # just run it again
```

### What the orchestrator does each cycle

1. **Checks develop CI** — if RED, everything stops until it's fixed
2. **Scans tasks** — finds `todo-*.md` with satisfied dependencies
3. **Dispatches agents** — max parallelism, each in its own worktree
4. **Monitors WIP** — kills stuck agents after 45 min, retries
5. **Reviews PRs** — reads Copilot comments, dispatches QA + Designer
6. **Merges** — only when all gates pass (CI + Copilot + QA + Design)
7. **Creates wire tasks** — auto-detects when front + back are done
8. **Finds more work** — when tasks run out, creates QA/review/optimization tasks

### The "never sleeps" behavior

When all feature tasks are done, the orchestrator doesn't stop. It:
- Dispatches **QA agents** to test every screen via Playwright (screenshots + video)
- Dispatches **Designer agents** to audit visual consistency
- Creates **fix tasks** from QA/Designer reports and dispatches dev agents
- Runs **code review agents** looking for DRY violations, dead code, security issues
- Audits **accessibility**, responsive design, performance
- The cycle repeats until there's literally nothing left to improve

**You can leave Forge running indefinitely.** It will keep your product getting better.

### Why it works: the reinforcement feedback loop

Forge isn't just "agents running in parallel." The real mechanism is a **self-reinforcing feedback loop** — the same concept behind reinforcement learning, continuous improvement (kaizen), and biological evolution.

```
     Build
      ↓
    Test ← QA agent finds bugs
      ↓
    Fix  ← Dev agent patches
      ↓
   Review ← Designer/Copilot catch regressions
      ↓
   Learn  ← Post-mortem → new hook/rule created
      ↓
    Build  (next cycle, with better guardrails)
```

Each cycle makes the system **structurally better**, not just the product:

- **QA finds a pattern of bugs** (e.g., agents write HTTP codes in specs) → a **hook is created** to block it mechanically → the entire class of bugs disappears forever
- **An agent goes rogue** (spends 45 min stuck) → the orchestrator **learns the timeout** → future stuck agents are killed faster
- **A merge breaks develop** → a **post-mortem** produces a new rule → the rule gets a hook → it can never happen again

This is fundamentally different from a human team, where lessons learned fade over time. In Forge, every lesson becomes a **permanent mechanical constraint**. The system's immune system gets stronger with every failure.

The analogy: traditional development is like manual farming — you plant, tend, harvest, repeat. Forge is like a **self-improving greenhouse** — it grows the crop, monitors for pests, builds better walls when pests get through, and keeps running season after season. You just decide what to grow.

---

## What is it, technically?

Forge is a **process + tooling framework** for Claude Code. It's not a SaaS, not a platform — it's a set of markdown files, bash hooks, and conventions that turn Claude Code into an autonomous development factory.

### Core principles

| Principle | What it means |
|---|---|
| **The forge never sleeps** | Agents always find work — build, test, fix, optimize, review |
| **Zero trust** | Every rule enforced by hooks/CI. Conventions fail with AI agents |
| **BDD-first** | PO writes Gherkin specs. Agents make them pass. Nothing else |
| **Isolation** | Each agent in its own git worktree. Can't break each other's work |
| **Fail-fast** | Blocked? Write a question and stop. Never guess |

### Numbers (Vetolib MVP — battle-tested)

- **234+ tasks** completed in days, not weeks
- **682 tests** — all green
- **10+ agents** in parallel, zero conflicts
- **46 screens** tested via Playwright overnight
- **0 human lines of code** — only specs and reviews

---

## Repository structure

```
forge/
├── bin/
│   └── forge-init.sh              # Interactive setup wizard (auto-detects stack)
├── docs/
│   ├── forge-overview.md          # Full process doc with Mermaid diagrams
│   ├── getting-started.md         # Zero to first build guide
│   ├── lessons-learned.md         # Post-mortems from production sessions
│   ├── troubleshooting.md         # Common issues and fixes
│   └── roadmap.md                 # What's next
├── agents/
│   ├── orchestrator.md            # The conductor — never codes, always watches
│   ├── po.md                      # Product Owner — writes specs, answers questions
│   ├── qa.md                      # QA — Playwright screenshots, behavior validation
│   └── designer.md                # Designer — visual consistency, design system
├── hooks/
│   ├── guard-bdd-first.sh         # Warns when creating handlers without test specs
│   ├── guard-feature.sh           # Blocks technical jargon in specs
│   ├── guard-merge-ci-green.sh    # Blocks merge if CI is RED on target branch
│   ├── guard-shared.sh            # Blocks writes to frozen files
│   ├── guard-wip-features.sh      # Blocks push if @wip features have step defs
│   └── verify-before-push.sh      # Build + tests must pass before push
├── templates/                     # Generated by forge-init.sh
├── commands/                      # /kickoff, /forge, /dev, /status, /po
└── examples/
    ├── dotnet-nextjs/             # .NET + Next.js (battle-tested on Vetolib)
    ├── node-react/                # Node.js + React + Cucumber.js
    ├── python-fastapi/            # Python + FastAPI + behave
    └── go-htmx/                   # Go + htmx + godog
```

---

## Adapting to your stack

Forge is **stack-agnostic**. The orchestration (task lifecycle, agent dispatch, QA gates, hooks) works the same on any stack. You adapt:

| What | Where |
|---|---|
| Build/test commands | `hooks/verify-before-push.sh` |
| BDD framework | Reqnroll, Cucumber.js, behave, godog |
| Frontend mocks | MSW or equivalent |
| Frozen files | `hooks/guard-shared.sh` |

See `examples/` for ready-to-use configs per stack.

---

## FAQ

**Q: Does this actually work?**
A: Yes. Vetolib (a full veterinary clinic management SaaS) was built from scratch using Forge — 234 tasks, 682 tests, 46 screens, production-ready MVP in days. The process documented here is exactly what ran.

**Q: How much does it cost?**
A: Claude Max ($100/mo) for unlimited usage. A full MVP build typically runs for a few days of continuous operation. The ROI vs. hiring developers is significant.

**Q: Can I use it with Cursor / Windsurf / other AI editors?**
A: Forge is built specifically for Claude Code CLI. The agent dispatch, worktree isolation, and hook system are Claude Code features. Other editors would need their own adaptation.

**Q: What if an agent goes rogue?**
A: It can't. Every rule has a mechanical guardrail: hooks block bad writes, CI blocks bad pushes, the orchestrator kills stuck agents after 45 minutes, and the QA/Designer agents catch visual regressions before merge.

**Q: Do I need to know how to code?**
A: You need to understand your product (to write specs with the PO agent) and your stack (to set up CI/CD). You don't need to write code — the agents do that. But you should be able to read code during reviews.

---

## Contributing

The forge is open. Contributions welcome — especially stack examples, hook improvements, and battle-tested troubleshooting tips.

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Author

**Yannis TOCREAU** — Creator of Forge.

[@gogetenk](https://yannis.blog)

---
<img width="1408" height="768" alt="image" src="https://github.com/user-attachments/assets/16e461bd-872e-4d63-8891-3d0f0af8c537" />

<p align="center">
  <em>Rest here, traveler. The forge keeps burning.</em><br>
  <em>Your product gets better every hour, even while you dream.</em>
</p>

---

Apache License 2.0 — Copyright 2026 Yannis TOCREAU. See [NOTICE](NOTICE).

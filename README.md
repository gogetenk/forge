<p align="center">
  <img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Claude_Code-v2.1+-green.svg" alt="Claude Code">
</p>

<h1 align="center">Forge</h1>

<p align="center">
  <strong>An autonomous-agent workflow for Claude Code.</strong><br>
  Markdown files, bash hooks, and conventions that turn Claude Code<br>
  into a continuous build/test/review/merge factory.
</p>

---

<p align="center">
  <img width="512" alt="The Forge" src="https://github.com/user-attachments/assets/6bb29fc9-15b8-4a51-810a-60d77f088e51" />
</p>

<p align="center"><em>Rest here, traveler. The forge keeps burning.</em></p>

---

## Mechanisms — why this works

Forge is not "Claude with extra steps". The properties below are what make the multiplier hold over weeks of continuous operation.

### 1. BDD-first, with mechanical enforcement
The PO writes `.feature` files in natural-language Gherkin **before** any code exists. Dev agents make them pass. A `guard-feature.sh` hook **blocks** technical jargon (HTTP codes, route paths, "JWT", "endpoint") from landing in specs — without it, 52 HTTP codes leaked into our Gherkin in one early session.

### 2. File-based task lifecycle
`todo-{id}.md` → `wip-{id}.md` → `done-{id}.md`. `git mv` is the atomic state transition. No SaaS task tracker, no API latency, no race conditions. Tasks are versioned, diffable, greppable.

### 3. Worktree isolation
Each agent runs in its own `git worktree`. 18 agents writing different parts of the codebase at the same time, zero stomp. Merge conflicts surface explicitly at PR time and are resolved by a dedicated agent (3 conflicts handled in the last batch alone).

### 4. Zero-trust hooks (bash, not convention)
| Hook | Blocks |
|---|---|
| `guard-shared.sh` | Writes to frozen files (`core/`, algo modules) |
| `guard-merge-ci-green.sh` | `gh pr merge` while CI is red |
| `verify-before-push.sh` | `git push` without local tests passing |
| `guard-bdd-first.sh` | New handlers without a spec |
| `guard-wip-features.sh` | Push that leaves `@wip` Gherkin with step defs |

AI agents do not reliably follow conventions. They reliably hit bash exit-1 on hooks.

### 5. MSW-first parallelism
Frontend builds against Mock Service Worker while backend builds the real API. A "wire" task connects them once both `done-*`. Halves the critical path on any front-back feature pair.

### 6. Mandatory Copilot loop
Every PR ships with `--add-reviewer Copilot`. Before merge: read inline comments, dispatch a follow-up agent to apply or refuse them, push, re-check. Every Copilot suggestion is either applied or explicitly refused with a rationale committed to the branch.

### 7. Image-reading rule on issues
Most product bugs are described in a screenshot, not the text. Forge has an explicit rule (CLAUDE.md) requiring agents to download every image attached to an issue (HTML `<img>`, Markdown `![]()`, bare user-attachments URLs, S3 presigned) via `curl -L -H "Authorization: token $(gh auth token)"` and `Read` it before coding. Without this rule, ~20 % of bug fixes ship against the wrong root cause.

### 8. Validation gates for the algorithmic core
A model-validation workflow replays a golden set against a frozen baseline on every algo PR. Any regression on MAPE / p90 / red-zone / per-confidence-band gates blocks the merge. This is the only thing standing between an agent trying to "improve" the algorithm and a silent quality drop in production.

---

## Getting started

```bash
git clone https://github.com/gogetenk/forge.git
cd your-project
bash /path/to/forge/bin/forge-init.sh
claude
/kickoff               # detects stack, runs PO Q&A, generates backlog
/loop 15m /forge       # orchestrator cycle every 15 min
```

`/kickoff` runs 5 phases: detect stack → PO Q&A → instantiate agents → generate project files → build backlog (`.feature` + `todo-*.md` with deps).

Detailed walkthrough: [`docs/getting-started.md`](docs/getting-started.md). Lessons from production sessions: [`docs/lessons-learned.md`](docs/lessons-learned.md).

---

## Requirements

- **[Claude Code CLI](https://claude.com/claude-code)** v2.1+
- **Claude Max** strongly recommended — Forge dispatches 10–20 parallel agents and burns through standard quotas in minutes
- **Git + GitHub CLI** (`gh`) authenticated
- **A GitHub repo with CI/CD** (Actions or equivalent)

---

## Repository structure

```
forge/
├── bin/forge-init.sh         # interactive setup, auto-detects stack
├── agents/                   # orchestrator, po, qa, designer
├── hooks/                    # bash guardrails (BDD, merge, push, frozen files)
├── commands/                 # /kickoff, /forge, /dev, /po, /status
├── templates/                # stack-agnostic agent + CLAUDE.md templates
├── examples/                 # dotnet-nextjs, node-react, python-fastapi, go-htmx
└── docs/                     # overview, getting-started, lessons-learned, troubleshooting
```

---

## Case study — Altitracks

**Altitracks** is a B2C trail-running coaching SaaS (GPX upload → personalised race-day roadbook + nutrition plan). It is the first commercial product built end-to-end with Forge. The numbers below are pulled from the live repository and the production database as of **2026-05-11**.

### Project context

| | |
|---|---|
| Domain | Trail running, predictive race-time + nutrition |
| Stack | FastAPI · React/Vite · Supabase · Docker · GitHub Actions · Hetzner |
| Repo bootstrap | 2026-02-13 |
| Forge introduction | 2026-04-06 (commit `feat(modernization)…`) |
| Observation window | 2026-02-13 → 2026-05-11 (87 calendar days) |

### Throughput

| Metric | Value | Notes |
|---|---:|---|
| Total commits | **570** | `git log --oneline \| wc -l` |
| Commits co-authored by Claude | **224 (39 %)** | `--grep="Co-Authored-By: Claude"` |
| Active development days | **45 / 87** (52 %) | days with ≥ 1 commit |
| Peak day | **57 commits** | 2026-04-14 |
| 11-day burst (Apr 11 → 21) | **308 commits** | 28 commits/day average |
| Net code delta | **+264 317 / −21 889 LOC** | shortstat aggregate over 570 commits |
| Tracked files | **902** | `git ls-files \| wc -l` |
| Lines of Python | **93 812** | 313 `.py` files |
| Lines of JS/JSX | **29 251** | 144 `.js` / `.jsx` files |
| SQL migrations | **30** | `doc/sql/0XX_*.sql`, idempotent, CI-checked monotonicity |
| Test files | **190** | pytest + Playwright |

### Pull-request hygiene

| Metric | Value |
|---|---:|
| PRs opened | **315** |
| PRs merged | **309 (98.1 %)** |
| Average merge latency (recent waves) | < 30 min from agent DONE → squashed merge |
| PRs explicitly addressing Copilot inline comments | **15 commits** (`chore: address Copilot feedback on #N`) |
| Failed deploys requiring hotfix | **2 / 309** (migration-numbering collision, Caddyfile CSP) — both fixed within 1 cycle |

### Issues + bug surface

| Metric | Value | Notes |
|---|---:|---|
| GitHub issues closed | **207** | feature + bug + chore + epic |
| Issues labelled `type: bug` | **45** | ~ 14 % of total work |
| EPICs left open by design | **2** | strategic meta-trackers (algorithm precision, growth roadmap) |
| Open issues at observation date | **4** | 2 EPICs + 1 parked (paywall pre-req) + 1 blocked (dep chain) |

### Quality gates active in CI

| Gate | Purpose |
|---|---|
| `test` | full pytest + vitest suite (≈ 2 850 tests as of last run) |
| `validate-model` | replays #382 golden set (35 races) against a frozen baseline run; blocks any algo PR that worsens MAPE, p90, red-zone, or per-confidence-band gates |
| `check-compose-volumes` | verifies docker-compose volume contracts |
| `test_doc_sql_migrations_idempotent` | enforces monotonic numbering + re-runnable SQL |
| Caddy CSP | locked allowlist, expanded via PR when needed |
| Copilot inline review | every PR; comments are applied or refused with an explicit rationale before merge |

### Product reach (live production)

These numbers come from the Supabase production database at the observation date, **after** the work above shipped.

| Funnel step | Users | % of signup | % of previous step |
|---|---:|---:|---:|
| Sign-up | **316** | 100 % | — |
| Profile created | **268** | 85 % | 85 % |
| Strava connected | **268** | 85 % | **100 %** |
| Calibrations OK | **260** | 82 % | 97 % |
| First analysis | **213** | 67 % | 82 % |
| **Closed loop** (linked actual race) | **78** | **25 %** | **37 %** ← largest drop |

| Aggregate | Value |
|---|---:|
| Races analysed | **563** (247 retrospective + 316 predictive) |
| Calibration runs ingested | **2 993** (95 % high-quality) |
| Strava-connection rate among profiled users | **100 %** (268 / 268) |
| Active leads collected (gated by analysis result) | **137** |
| Paid conversions | **0** (beta gratuite, no paywall yet — by design) |

> **Interpretation.** The hard drop is "first analysis → closed loop = 37 %". 135 users analysed a race but never linked their post-race Strava activity. This is the dominant friction of the learning-loop product, and the next product priority — measurable directly from this funnel, not from intuition.

### Headcount

| Role | Commits | Notes |
|---|---:|---|
| Founder / PO / orchestrator | 401 | two git identities, same human |
| External dev (front + e2e) | 142 | part-time, pre-Forge era + early Forge |
| Claude (via Forge agents) | 224 | co-authored, not a separate commit author |
| GitHub Copilot suggestions applied | 17 | bot-authored commits + 15 follow-up PRs |

**One full-time founder + one part-time dev** produced a 902-file, 123 kLOC, 309-PR codebase with a working multi-region deploy and live users. The 224 Claude co-authors represent the multiplier — about 2× output during the Forge era — without an additional headcount line.

---

## Contributing

Issues and pull requests welcome — particularly stack examples, hook improvements, and post-mortems from production sessions. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Author

**Yannis TOCREAU** — [@gogetenk](https://yannis.blog)

---

<img width="1408" height="768" alt="image" src="https://github.com/user-attachments/assets/16e461bd-872e-4d63-8891-3d0f0af8c537" />

<p align="center">
  <em>Rest here, traveler. The forge keeps burning.</em><br>
  <em>Your product gets better every hour, even while you dream.</em>
</p>

---

Apache License 2.0 — Copyright 2026 Yannis TOCREAU. See [NOTICE](NOTICE).

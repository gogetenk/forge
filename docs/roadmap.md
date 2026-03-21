# Forge Roadmap

> What's next for making Forge production-grade.

## v1.0 — Current (you are here)

- [x] Orchestrator agent with 15-min loop
- [x] QA agent with Playwright screenshots
- [x] Designer agent for visual consistency
- [x] Zero-trust hooks (guard-feature, guard-shared, verify-before-push)
- [x] File-based task system (todo/wip/done)
- [x] PostCompact monitoring for zombie agents
- [x] Worktree isolation with sparse checkout
- [x] Full process documentation with Mermaid diagrams
- [x] Templates for CLAUDE.md, settings, tasks

## v1.1 — Developer Experience

- [ ] **`forge init` CLI** — Interactive setup wizard
  - Detects stack (package.json, *.csproj, go.mod, requirements.txt)
  - Generates CLAUDE.md, settings.json, hooks preconfigured for detected stack
  - Creates directory structure (agents/, tasks/, questions/)
  - Validates GitHub CLI auth and CI pipeline

- [ ] **Stack-specific examples**
  - `examples/dotnet-nextjs/` — .NET + Next.js (battle-tested on Vetolib)
  - `examples/node-react/` — Node.js + React
  - `examples/python-fastapi/` — Python + FastAPI
  - `examples/go-htmx/` — Go + htmx

- [ ] **`forge doctor`** — Validates your Forge setup
  - Checks hooks are executable
  - Checks settings.json is valid
  - Checks CLAUDE.md has required sections
  - Checks GitHub CLI is authenticated
  - Checks CI pipeline exists

## v1.2 — Observability

- [ ] **Dashboard** — Real-time view of factory state
  - Tasks by status (todo/wip/done) with live updates
  - Agent activity timeline
  - PR status and CI results
  - Cost tracking per agent/task
  - Built as a simple web page reading progress.md + git log

- [ ] **Slack/Discord notifications** via HTTP hooks
  - Agent completed/failed
  - PR merged/blocked
  - develop CI status changes
  - PO questions pending

- [ ] **Cost analytics**
  - Token usage per agent, per task, per module
  - Cost trends over time
  - Recommendations for reducing cost (better prompts, smaller tasks)

## v1.3 — Intelligence

- [ ] **Smart task splitting**
  - Orchestrator analyzes large tasks and auto-splits into subtasks
  - Estimates file overlap before dispatch
  - Suggests sequencing vs parallelization

- [ ] **Agent performance profiling**
  - Track which agents succeed vs fail per task type
  - Track compaction frequency as quality signal
  - Auto-kill and re-dispatch underperforming agents

- [ ] **Learning from post-mortems**
  - When a task fails, capture the pattern
  - Add to troubleshooting database
  - Prevent similar failures in future dispatches

## v2.0 — Platform

- [ ] **Multi-repo support** — Forge across microservices
- [ ] **Team collaboration** — Multiple humans + POs on the same factory
- [ ] **Custom agent types** — Define your own specialized agents via frontmatter
- [ ] **Plugin system** — Community hooks and agents

---

## Contributing

If you want to work on any of these items, open an issue first to discuss the approach.
Priority is on v1.1 (developer experience) — making Forge easy to adopt is more important than adding features.

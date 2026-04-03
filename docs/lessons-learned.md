# Lessons Learned

> Key post-mortems from production Forge sessions. Each lesson resulted in a permanent rule or hook.

---

## 1. OutputCache dead code — middleware annotations without registration

**What happened:** An agent added `[OutputCache]` attributes to endpoints, but never registered the OutputCache middleware in the pipeline. The code compiled, passed type checks, but the caching silently did nothing.

**Root cause:** LLMs pattern-match from training data. They know the attribute exists, but don't always verify the middleware registration. No test catches "this annotation does nothing" because the endpoint still works — it just doesn't cache.

**Fix:** Added "wiring verification" as Phase 2.5 in the Evaluator agent. The evaluator now checks that every middleware annotation has a corresponding registration, every DI injection resolves, and every config section is read.

**Rule:** Any annotation/attribute without its corresponding registration is dead code and must be flagged.

---

## 2. Empty scaffold endpoints — compile but do nothing

**What happened:** Dev agents created endpoint files with correct routing, correct DTOs, correct return types — but the handler body was empty or returned a hardcoded value. The endpoints compiled, the integration test scaffold passed (it only checked HTTP 200), but no actual business logic ran.

**Root cause:** Agents sometimes scaffold first and "fill in later" but mark the task as DONE after scaffolding. Without a meaningful integration test, no one catches that the endpoint is hollow.

**Fix:** Added rule: "Each endpoint MUST have at least 1 integration test that verifies actual behavior, not just HTTP status." Empty scaffolds are now treated as bugs, not progress.

**Rule:** An endpoint without a meaningful integration test is an unverified assumption.

---

## 3. @wip tests giving false coverage impression

**What happened:** Feature files were tagged `@wip`, which excluded them from test runs. Step definitions existed and looked complete. The agent reported DONE with "all tests passing" — but the relevant tests weren't running at all. Coverage reports showed the code as covered (by other tests hitting the same paths), masking the gap.

**Root cause:** `@wip` is meant for work-in-progress scenarios. But agents used it to park difficult scenarios and moved on. The orchestrator saw "0 failures" and merged.

**Fix:** Added `guard-wip-features.sh` hook that blocks push if `.feature` files have `@wip` but step definitions exist. Added evaluator rule: "A task cannot be EVAL_PASS if its .feature files are tagged @wip."

**Rule:** Disabled tests with implementations = false coverage. Either enable the test or remove the implementation.

---

## 4. 9-hour stagnation — confusing "audited" with "actioned"

**What happened:** The forge sat idle for 9 hours while 7 audit reports contained 40+ actionable HIGH findings. The orchestrator had run audits, read the reports, and checked them off the 10-source list. But it never created tasks from the findings. It confused "I ran the audit" with "the issues are resolved."

**Root cause:** The anti-stagnation rule said "check 10 sources." The orchestrator interpreted "check" as "look at" rather than "act on." The sources were treated as a one-shot checklist instead of a cyclical process.

**Fix:** Updated the anti-stagnation rule to be explicit: "An audit finding is NOT resolved until: (a) a task is created, (b) the task is dispatched, (c) the fix is merged, (d) a smoke test verifies the fix works." The word "audited" was banned in favor of "actioned."

**Rule:** Auditing is not actioning. Every finding needs a task, a dispatch, a merge, and a verification.

---

## 5. Subagent Bash permission limitations in worktrees

**What happened:** Subagents dispatched into isolated worktrees intermittently lost access to the Bash tool for git commands. The agent could read and write files but couldn't run `git push`, `gh pr create`, or other shell commands. The agent would hang or retry indefinitely.

**Root cause:** Known limitation of the Claude Code worktree isolation model. Tool access can be restricted in subagent contexts depending on the host configuration.

**Fix:** Added rule 7b (subagent tool access fallback): when an agent is blocked on Bash commands, it reports status `BLOCKED` with the exact commands to execute. The orchestrator then runs those commands on the agent's behalf.

**Rule:** Agent prompts must include: "If tool access is denied for git commands, list exact commands and report BLOCKED."

---

## 6. EF Core migration phantom operations

**What happened:** Auto-generated EF Core migrations contained `AlterColumn` statements for columns that had never been created, and `DropTable` for tables that shouldn't be dropped (MassTransit outbox tables). Applying these migrations would fail or corrupt the schema.

**Root cause:** The EF Core model snapshot had diverged from the actual database schema. When the migration generator compared the snapshot to the model, it produced "corrections" for discrepancies that existed only in the snapshot, not in reality.

**Fix:** Added rule 7c (schema migration audit): after every `dotnet ef migrations add`, the agent must read the generated file, check for phantom operations, verify the companion `.Designer.cs` exists, and run `has-pending-model-changes` to confirm no drift.

**Rule:** Never trust auto-generated migrations. Always read and verify them before committing.

---

## 7. Same-entity parallel PRs causing cascading conflicts

**What happened:** Two agents were dispatched in parallel on tasks that both modified the same entity (e.g., adding fields to the same model, both generating migrations). The first PR merged cleanly. The second PR immediately had conflicts — not just in code, but in the migration snapshot, the generated migration files, and the DbContext configuration. Resolving conflicts in migration files is error-prone and often produces invalid migrations.

**Root cause:** The orchestrator's file overlap detection didn't account for generated files (migrations, snapshots) that are created during the task but don't exist at dispatch time.

**Fix:** Added merge strategy for same-file tasks: the orchestrator either (a) merges all worktrees into 1 branch / 1 PR, resolving conflicts locally before push, or (b) sequences the tasks and waits for each merge before dispatching the next. Tasks touching the same entity are never parallelized naively.

**Rule:** Tasks that touch the same entity = sequential dispatch or combined PR. Never parallel with separate PRs.

---

## 8. Never remove @wip tags without running the tests

**What happened:** An agent removed `@wip` tags from feature files to "clean up" the test suite, but did not run the tests first. The underlying scenarios had never been green — step definitions were incomplete or broken. After removing the tags, the tests ran and failed, breaking CI on develop.

**Root cause:** The agent treated `@wip` removal as a cleanup task, not a verification task. Removing `@wip` means "these tests are ready to run" — which is a claim that must be verified.

**Fix:** Added rule: never remove `@wip` without first running the tagged tests locally and confirming GREEN. The `guard-wip-features.sh` hook now also catches this pattern: if step definitions exist for `@wip` scenarios, the push is blocked until the tag is removed AND the tests pass.

**Rule:** Removing `@wip` = asserting the tests pass. Verify before removing.

---

## 9. Never batch-merge 30+ PRs without CI verification between batches

**What happened:** After a productive overnight session, the orchestrator had 30+ green PRs queued. It merged them all in rapid succession without waiting for CI between merges. By the 15th merge, develop was red — a subtle conflict between two PRs that individually passed but together broke the build. The remaining 15+ PRs merged on top of a broken develop, compounding the problem.

**Root cause:** The orchestrator optimized for throughput (merge everything fast) instead of correctness (verify after each merge). The "check develop CI within 2 minutes after each merge" rule existed but was skipped during batch operations.

**Fix:** Merges are now batched in groups of 3-5. After each batch, the orchestrator waits for CI to confirm GREEN before proceeding. If CI fails, remaining merges are paused until the break is fixed.

**Rule:** Merge in small batches (3-5 PRs max), verify CI between batches. Never merge 30+ PRs in a fire-and-forget sequence.

---

## 10. BDD-first must be mechanically enforced, not conventional

**What happened:** Despite the "BDD-first" rule in CLAUDE.md, agents routinely created handlers and services before any test spec existed. They would write the implementation, then write the tests (or skip them). The rule was purely conventional — nothing mechanically stopped an agent from writing code first.

**Root cause:** AI agents follow explicit mechanical constraints (hooks, CI gates) far more reliably than written conventions. A rule in a markdown file is a suggestion; a hook that blocks the action is a law.

**Fix:** Created `guard-bdd-first.sh` hook that warns (or blocks, with `FORGE_BDD_STRICT=1`) when an agent creates a handler/service file without a corresponding test spec in the test directories.

**Rule:** Every critical convention must have a corresponding hook. If a rule is important enough to write down, it's important enough to enforce mechanically.

---

## 11. Evaluator must be mandatory, not optional

**What happened:** The evaluator agent was added as an optional step. Some agents self-reported DONE and the orchestrator merged without evaluation. Four blockers were discovered post-merge: hardcoded values, untranslated strings, wrong API URLs, and missing required fields. All would have been caught by the evaluator.

**Root cause:** When the evaluator was optional, the orchestrator skipped it under time pressure (many PRs queued). The path of least resistance was to trust the dev agent's self-report.

**Fix:** Made evaluator dispatch mandatory in the orchestrator (section 5a). The orchestrator NEVER merges without EVAL_PASS. No exceptions, no shortcuts.

**Rule:** Quality gates must be mandatory, never optional. An optional gate will be skipped under pressure 100% of the time.

---

## 12. Frontend layout PRs must be sequential, not parallel

**What happened:** Three frontend agents were dispatched in parallel on tasks that all modified shared layout files (sidebar, header, navigation). Each agent's changes compiled independently, but merging created cascading conflicts in CSS modules, layout components, and shared state. Resolving conflicts in generated CSS and layout code produced visual regressions.

**Root cause:** The orchestrator's file overlap detection checked source files but missed shared layout components that are implicitly touched by many frontend tasks (global styles, layout wrappers, navigation state).

**Fix:** Frontend tasks that touch layout/navigation/shared UI components are now dispatched sequentially. The orchestrator checks for layout file overlap before parallelizing frontend tasks.

**Rule:** Frontend layout is a shared resource. Layout PRs must be sequential to avoid visual regression conflicts.

---

## 13. When CI quota is exhausted, local verification replaces CI

**What happened:** GitHub Actions minutes were exhausted mid-session. The orchestrator kept merging PRs based on local test results alone, which worked — but then stopped merging entirely when it couldn't verify CI status, leaving 8 green PRs unmerged for hours.

**Root cause:** The orchestrator treated "CI GREEN" as a hard requirement without a fallback. When CI was unavailable (quota exhausted), it had no alternative verification path and entered a waiting loop.

**Fix:** Added fallback rule: when CI is unavailable (quota exhausted, GitHub outage), the orchestrator can merge based on local build+test verification, provided: (a) the full test suite passes locally, (b) the merge is logged as "locally verified, CI unavailable", and (c) CI is re-run on develop as soon as quota is restored.

**Rule:** Local build+test is the primary verification. CI is the safety net. When the safety net is down, the primary verification still works — don't freeze the forge.

---

## 14. Scale parallelism aggressively

**What happened:** Early forge sessions dispatched 1-2 agents at a time, "to be safe." The orchestrator waited for each agent to finish before dispatching the next batch. An overnight session that could have completed 40 tasks only completed 12, because agents spent most of their time waiting on IO (builds, tests, API calls) while CPU and RAM sat idle.

**Root cause:** Conservative parallelism inherited from human intuition — "don't overload the system." But AI agents are IO-bound, not CPU-bound. While one agent waits for `dotnet build`, another can be writing code, another can be running tests, another can be creating a PR. The bottleneck is never the machine — it's the orchestrator's willingness to dispatch.

**Fix:** When CPU/RAM allows, dispatch 5-10 agents in parallel instead of 1-2. The orchestrator should maximize throughput by filling every available slot. Single-agent cycles waste time on IO waits that could overlap.

**Rule:** Maximize parallelism to the hardware limit. Idle agents are wasted capacity. The forge burns brighter with more fire.

---

## 15. Blog index.ts is a merge conflict magnet

**What happened:** Every blog article PR touched the same `index.ts` file (a static array of article metadata). With 3+ agents creating articles in parallel, every second PR had a merge conflict on that single file. Resolving conflicts in a generated index is tedious and error-prone.

**Root cause:** The index file was a manually maintained static array. Every addition required appending to the same array in the same file — a classic merge conflict hotspot when multiple branches modify the same lines.

**Fix:** Generate the index dynamically from the filesystem instead of maintaining a static array. Each article is self-describing (frontmatter or co-located metadata), and the index is built at build time by scanning the directory. No shared mutable file = no conflicts.

**Rule:** Any file that every PR touches is a merge conflict magnet. Replace static registries with dynamic discovery (filesystem scan, convention-based loading, auto-registration).

---

## 16. Snapshot conflicts on same-module parallel PRs

**What happened:** Two agents were dispatched in parallel on different features in the same module. Both added migrations, both modified the EF Core model snapshot. The first PR merged cleanly. The second PR had an unmergeable conflict in the snapshot file — a 5000-line auto-generated file where manual conflict resolution is almost guaranteed to produce a corrupt snapshot.

**Root cause:** EF Core model snapshots are auto-generated and represent the full state of the model at migration time. Two migrations generated from the same base snapshot will produce two divergent snapshots. Unlike code conflicts, snapshot conflicts can't be resolved by picking "both sides" — the snapshot must be regenerated.

**Fix:** Same-module features that touch the DbContext are dispatched sequentially (not in parallel), or consolidated into a single branch and single PR. The orchestrator detects DbContext/migration overlap at dispatch time and prevents parallel execution.

**Rule:** Database migration snapshots are non-mergeable. Same-module DB features must be sequential or combined into one PR.

---

## 17. API overload resilience

**What happened:** During peak usage, the Anthropic API returned 500 (internal error) and 529 (overloaded) responses. Agents that received these errors crashed and lost all work-in-progress — code changes, test results, and context. The orchestrator had no visibility into why an agent disappeared and couldn't distinguish "crashed from API error" from "stuck on a hard problem."

**Root cause:** Agents treated API errors as fatal. There was no retry logic, no checkpoint mechanism, and no way for the orchestrator to detect the failure mode. A transient 529 (which resolves in seconds) caused the same total loss as a permanent failure.

**Fix:** The orchestrator should auto-retry crashed agents with exponential backoff. Agent prompts should include: "If you receive a transient API error, retry up to 3 times with increasing delays before reporting BLOCKED." The orchestrator should also distinguish between agent states: RUNNING, BLOCKED, CRASHED, DONE.

**Rule:** Transient API errors must not cause total work loss. Retry crashed agents automatically — the forge must be resilient to infrastructure hiccups.

---

## 18. Real-world feature discovery

**What happened:** The product backlog was built entirely from competitor analysis and imagination. After visiting a real veterinary clinic, we discovered critical workflows that no competitor had implemented and that no amount of brainstorming would have surfaced: waiting room notifications for pet owners, receptionist-specific queue management, and paper-to-digital transition flows unique to the UAE market.

**Root cause:** AI agents (and humans) can only generate features from patterns they've seen. Real-world observation reveals friction, workarounds, and unspoken needs that don't appear in competitor products or requirement documents.

**Fix:** Before building a new module, visit a real user site (clinic, office, warehouse — whatever the domain). Spend 2-4 hours observing actual workflows. The features that come from observation are the ones that differentiate the product.

**Rule:** The best features come from observation, not imagination. Visit real users before writing specs. The PO agent can structure what you observe, but it can't observe for you.

---

## 19. Orchestrator must NEVER write implementation code

**What happened:** During the NOVA medical SaaS project kickoff, the orchestrator agent directly modified SharedKernel files (Entity.cs, AggregateRoot.cs), created a Migrations project, and edited Aspire configuration. The user had to intervene: "Tu n'es qu'orchestrateur. Tu dispatches, evalues, facilites, arbitres." The orchestrator was doing dev work instead of dispatching.

**Root cause:** The orchestrator saw "simple" foundation changes and shortcut the dispatch process. It rationalized: "this is infrastructure setup, not feature code." But ANY implementation work — even foundation setup — should be dispatched to dev agents. The orchestrator's value is coordination, not coding.

**Fix:** Added explicit rule to orchestrator.md: "You NEVER write implementation code. Even foundation/infrastructure changes are dispatched to dev agents. The only files you create are task files, question files, and progress updates."

**Rule:** The orchestrator writes ZERO lines of implementation code. If it touches a .cs, .ts, .py, .go file — it's wrong. Dispatch a dev agent instead. No exceptions for "simple" changes.

---

## 20. Dispatch test agents in parallel with code agents during large refactors

**What happened:** During a long-to-Guid ID migration affecting all 5 modules, the orchestrator initially dispatched 4 agents for code layers (Domain, Application, Contracts, Api) but forgot the 11 test projects. The user had to remind: "tu n'as pas oublie de dispatch des dizaines d'agents en parallele sur tous les tests?" This delayed the refactor by an entire agent wave.

**Root cause:** The orchestrator focused on "making the code compile" and treated tests as a follow-up step. But in a large refactor, tests are equally impacted and equally parallelizable. Every test project is independent and can have its own agent.

**Fix:** For large cross-cutting refactors, dispatch agents for ALL affected projects simultaneously — code AND tests. Each test project gets its own agent. Don't wait for code agents to finish before starting test agents.

**Rule:** During large refactors, tests are first-class citizens. Dispatch test agents in the SAME wave as code agents, not as a follow-up wave. One agent per test project = maximum parallelism.

---

## 21. Establish branch strategy BEFORE any code changes

**What happened:** The orchestrator started modifying files on the main branch before creating a feature branch. Changes had to be stashed and moved to a new branch after the fact. The user also corrected the initial branch name because the scope was the entire project, not just the current phase.

**Root cause:** The orchestrator was eager to start coding (which it shouldn't have been doing anyway — see lesson 19) and skipped the branching step. Branch strategy should be the FIRST action before any file modifications.

**Fix:** Added to orchestrator cycle: Before dispatching ANY work, verify the branch strategy exists. Create the base feature branch if needed. All agent worktrees branch from this base, not from main.

**Rule:** Branch first, code second. Establish the base branch before ANY file modifications. Name the branch for the full scope of work, not just the current phase.

---

## 22. Domain purity — new infrastructure built from Domain, not adapted from legacy

**What happened:** During analysis of a SQL Server to PostgreSQL migration, the initial approach was to "migrate" the existing infrastructure (stored procedures, ADO.NET patterns, legacy column names). The user corrected: "Le Domain est pur et fait foi. On construit une couche Infrastructure NEUVE basee uniquement sur le Domain." This completely changed the approach — from adapting legacy code to building fresh from the domain model.

**Root cause:** The natural instinct was to preserve and adapt existing code. But when the existing infrastructure is fundamentally different (stored procedures vs EF Core LINQ, SQL Server vs PostgreSQL), adapting carries over unnecessary complexity and legacy patterns. The domain model is the contract — the infrastructure serves it, not the other way around.

**Fix:** When replacing an infrastructure layer, always start from the Domain interfaces and entities. Read only the Domain to understand what persistence is needed. Do NOT read the old Infrastructure as a reference — it will pollute the new design with legacy patterns.

**Rule:** Domain is the source of truth for new infrastructure. Old infra is reference material for understanding what data exists, NOT a template for the new implementation. Build from the contract (Domain interfaces), not from the implementation (old repositories).

---

## 23. "Tests GREEN" does not mean "App works" — live smoke test is mandatory

**What happened:** The orchestrator declared IDLE 15+ consecutive times while 948 automated tests passed. But the app had NEVER been started via Aspire and tested with curl on a live running instance with a fresh database. When the user finally asked "tu as pu faire des tests en faisant curl?", it was revealed that live E2E had never been validated — QA agents had used WebAppFactory (in-process), not a real running instance.

**Root cause:** The orchestrator treated "automated tests GREEN" as equivalent to "everything works." But automated tests run in controlled environments (in-memory, Testcontainers) that bypass real infrastructure: Aspire orchestration, Docker networking, migration timing, container health checks, port binding, auth middleware with real headers. A green test suite proves code correctness, not operational readiness.

**Fix:** Added 3 new sources to the anti-stagnation checklist (#12 live smoke test, #13 Swagger verification, #14 seed data verification). Added absolute rule: "IDLE requires proof — list last live smoke test timestamp, last curl results, last DB verification. If any is missing, NOT IDLE." Added rule: tasks completed with failures in description = NOT completed.

**Rule:** Before declaring IDLE, the orchestrator MUST have started the app on a real instance (Aspire/Docker), curled every endpoint, and verified responses. "Tests pass" is necessary but not sufficient. Live smoke testing is the final gate before IDLE.

---

## 24. Tasks marked "completed" with failures are NOT completed

**What happened:** QA curl tasks were marked "completed" with descriptions like "8/9 FAIL" and "1/5 PASS." The orchestrator treated these as done because the task agent had finished its work. But a task with failures is not done — it needs a fix agent dispatched, retested, and verified GREEN before marking complete.

**Root cause:** Confusion between "agent finished" and "task objective met." An agent reports results; the orchestrator decides if the objective is achieved. If the objective was "all endpoints return 200" and the result is "8 return 500", the task has FAILED, not completed.

**Fix:** Added rule: a task completed with failures = NOT completed. Reopen it, dispatch a fix agent, verify GREEN, THEN mark completed. The orchestrator must verify task outcomes, not just agent completion.

**Rule:** Task completion requires the Definition of Done to be met. Agent completion is not task completion. Failed tests, 500 errors, and partial results mean the task stays open.

---

## 25. Multi-tenancy must be verified in LIVE — unit tests don't catch pooling issues

**What happened:** Multi-tenancy query filters were completely bypassed in the live Aspire instance because DbContext pooling resolves services from the EF Core internal provider (not the app's scoped provider). Unit tests passed because they don't use pooling. Integration tests passed because they replace Aspire's pooled DbContexts with standard non-pooled ones. The data leak was only visible on a real running instance.

**Root cause:** EF Core's `IInfrastructure<IServiceProvider>` returns the EF internal provider when using DbContext pooling. Scoped services (`ICurrentUserContext`) are not available there. The fallback returned `Guid.Empty` which matched the "bypass" sentinel in the query filter.

**Fix:** Resolve scoped services via `IHttpContextAccessor` (singleton, works across scopes) set at app startup. Added mandatory live multi-tenancy test to the orchestrator cycle.

**Rule:** Multi-tenancy MUST be tested on a LIVE instance with real DbContext pooling. Unit/integration tests that replace DbContexts hide pooling-related bugs. Always test: Cabinet A sees only A's data, Cabinet B sees only B's data, unknown cabinet sees nothing.

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

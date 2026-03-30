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

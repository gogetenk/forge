# Troubleshooting

> Lessons learned from production use of Forge on a 234+ task MVP.

## Agents write technical jargon in .feature files

**Symptom:** HTTP codes, API paths, JWT references in Gherkin.

**Root cause:** Without mechanical enforcement, LLMs default to technical language because it's easier to generate than natural language.

**Fix:** The `guard-feature.sh` hook blocks this automatically. If you see it happening, check that the hook is properly configured in `settings.json` under `PreToolUse`.

## Tests pass locally but fail in CI

**Symptom:** Agent commits with green tests, CI goes red.

**Root cause:** Usually environment differences (database, timezone, locale).

**Fix:** Ensure CI uses the same test commands as `verify-before-push.sh`. Add the CI-specific setup to the hook so local and CI environments match.

## WIP tasks stuck for hours

**Symptom:** `wip-*.md` files never transition to `done-*`.

**Root cause:** Agent may be stuck in a loop, or the 45-min timeout isn't triggering because the orchestrator loop isn't running.

**Fix:**
1. Check if `/loop 15m /forge` is running
2. Check `.claude/compact-log.txt` — if the agent compacted 3+ times, it's stuck
3. Manually rename `wip-*.md` back to `todo-*.md` to retry

## Merge conflicts between PRs

**Symptom:** Multiple PRs conflict with each other.

**Root cause:** Agents touching overlapping files. Usually happens with shared types or generated files.

**Fix:**
1. Merge PRs one at a time, smallest first
2. For `.feature.cs` conflicts: accept either version, they regenerate on build
3. For code conflicts: the orchestrator should detect file overlap before dispatching
4. Add overlap detection to task planning

## Agent modifies frozen files

**Symptom:** `guard-shared.sh` blocks the write.

**Fix:** If the modification is legitimate, add `MODIFY_FROZEN: authorized` to the task's `wip-*.md` file and create a `questions/{task-id}.md` for human review.

## Force-push blocked by repo rules

**Symptom:** `git push --force` fails.

**Root cause:** Agent tried to rebase instead of merge.

**Fix:** Always use `git merge origin/develop`, never `git rebase`. This is enforced by convention in CLAUDE.md but should be reinforced in agent prompts.

## Frontend and backend API contract mismatch

**Symptom:** Wire task fails — frontend expects different response format than backend provides.

**Root cause:** MSW mocks diverged from real API during parallel development.

**Fix:** Use Agent Teams for wire tasks so front and back agents can communicate directly about contract mismatches.

## EF Core / ORM tests return empty results

**Symptom:** Tests pass but return no data even though seeds exist.

**Root cause:** Multi-tenant query filters bake tenant ID at model creation time. If the test context ID changes after model creation, filters silently return nothing.

**Fix:** Use a FIXED tenant ID in test context (e.g., `11111111-1111-...`), never `Guid.NewGuid()`.

## Agent cost exceeds budget

**Symptom:** `log-cost.sh` alerts on session > $2.

**Root cause:** Agent exploring too broadly, reading unnecessary files, or stuck in retry loops.

**Fix:**
1. Check compaction log — too many compactions = too much context
2. Make task files more specific (exact file paths, exact scenarios)
3. Use `worktree.sparsePaths` to limit what the agent can see

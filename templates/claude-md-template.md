# CLAUDE.md — Forge Factory Rules

> Read automatically by all agents at startup. Non-negotiable rules.
> When in doubt about a rule → questions/, never improvise.

---

## Stack

| Layer | Technology |
|---|---|
| Backend | {YOUR_BACKEND_STACK} |
| Frontend | {YOUR_FRONTEND_STACK} |
| Tests | {YOUR_TEST_FRAMEWORK} |
| CI/CD | {YOUR_CI_TOOL} |

## Project structure

```
{YOUR_PROJECT_STRUCTURE}
```

---

## Absolute rules

### 1. BDD-first mandatory

```
Step 0: PO writes .feature files BEFORE any implementation
Step 1: Dev agent READS existing .feature — never creates/modifies them
Step 2: Write step definitions → verify RED
Step 3: Implement until GREEN
Step 4: PR only when all Gherkin scenarios are GREEN
```

An agent that opens a PR with red tests = PR rejected automatically.

### 1a. Feature file purity

**.feature files are PO property.** A dev agent never creates or modifies a .feature file.
If a .feature is missing or incomplete → agent blocks and writes to `questions/`.

**.feature files are purely functional — ZERO technical jargon:**

```gherkin
# CORRECT — natural language, user-observable
Given a user with an active account
When the user logs in with valid credentials
Then the user is authenticated

# FORBIDDEN — technical jargon
When I POST /api/v1/auth/login with:    # URL = technical
Then the response status is 200          # HTTP code = technical
And I receive a JWT access token         # JWT = technical
```

**Forbidden patterns** (enforced by `guard-feature.sh` hook):
- HTTP status codes: 200, 201, 400, 401, 403, 404, 409, 422, 500
- API paths: `/api/`, `POST /`, `GET /`
- Technical terms: JWT, token, database, query, SQL, endpoint, header, JSON, HTTP

### 2. Local verification mandatory BEFORE commit/push

**No code leaves the machine without local verification.**

```bash
# CONFIGURE: your build + test commands
{YOUR_BUILD_COMMAND}    # MUST return 0 errors
{YOUR_TEST_COMMAND}     # MUST pass
```

**If a test fails → fix BEFORE committing.**

### 3. Immediate commit after GREEN

**As soon as tests are GREEN → git add + git commit + git push IMMEDIATELY.**
A fix verified locally but not committed does not exist.

### 4. Merge-based sync, not rebase

**When a PR has conflicts with develop, use `git merge origin/develop` instead of `git rebase`.**

### 5. PR hygiene

- **1 task = 1 branch = 1 PR towards `develop`**
- Max ~30 modified files per PR
- Each worktree agent creates its OWN PR
- After each merge → verify develop CI GREEN within 2 minutes

### 6. Isolated scopes

Each agent only touches files in its module. If a cross-module need appears → create `questions/` and block.

### 7. Fail-fast mandatory

Block immediately and create `questions/{task-id}.md` if:
- Edge case not covered by Gherkin
- Business rule ambiguity
- Need to modify frozen files
- Two approaches have failed

### 7a. Circuit breaker — 3 attempts max

An agent debugging a problem has **3 maximum attempts** to resolve it.
After 3 consecutive failures on the same problem:
- **STOP immediately** — do not keep guessing
- Create `questions/{task-id}-debug-{timestamp}.md` documenting:
  - What was tried (the 3 approaches)
  - Results/errors of each attempt
  - Hypothesis on root cause
- Report status `FAILED` and wait for human/PO input

**Why:** an agent looping on a fix consumes context and budget without progressing.

### 7b. Subagent tool access fallback

Subagents in isolated worktrees may lose access to certain tools (e.g., Bash for git commands).
When blocked:
- Report status `BLOCKED` with **exact commands** to execute
- The orchestrator executes the commands on behalf of the agent
- Agent prompts should include: "If tool access is denied for git commands, list exact commands and report BLOCKED."

### 7c. Schema migration audit

After generating any database migration (EF Core, Prisma, Alembic, Knex, etc.), the agent MUST:
1. **Read the generated migration file** and verify it matches intent
2. **Check for phantom operations** (altering columns that were never created, dropping tables that shouldn't be dropped)
3. **Verify companion/metadata files exist** (e.g., `.Designer.cs` for EF Core, snapshot files)
4. **Run the framework's "has pending changes" command** to confirm no drift

**Why:** auto-generated migrations can produce phantom operations when the snapshot diverges from the actual schema.

### 8. Commit convention

```
feat(module): add feature description
fix(module): fix description
test(module): add test description
refactor(module): refactor description
```

### 9. Definition of Done (DOD) mandatory

Every task file (`todo-*.md`) MUST include a `## Definition of Done` section with concrete, verifiable criteria. No subjective criteria ("clean code") — only binary checks the Evaluator agent can verify.

The DOD is the contract between the dev agent and the evaluator. If a criterion is not in the DOD, the evaluator won't check it. If it IS in the DOD, the evaluator WILL check it and FAIL the evaluation if it's not met.

Template:
```
## Definition of Done
- [ ] Build passes (0 errors)
- [ ] Tests pass (0 failures)
- [ ] New handlers have unit tests (>=1 test per handler)
- [ ] No hardcoded strings in UI (all through i18n)
- [ ] data-testid on all interactive elements
- [ ] DTO types match backend contracts
```

---

## Frozen files

Never modify without human arbitration:
- {LIST YOUR FROZEN FILES/DIRECTORIES}

---

## Hooks

| Hook | Trigger | Effect |
|---|---|---|
| `guard-shared.sh` | Write/Edit | Blocks modification of frozen files |
| `guard-feature.sh` | Write/Edit .feature | Blocks technical jargon |
| `verify-before-push.sh` | Bash `git push` | Build + tests MUST pass |

---

## Commands

| Command | Effect |
|---|---|
| `/forge` | Full orchestrator cycle |
| `/loop 15m /forge` | Automatic cycle every 15 min |
| `/status` | Quick status in < 10 lines |
| `/dev tasks/todo-xxx.md` | Launch a dev agent on a task |
| `/po` | Handle pending business questions |

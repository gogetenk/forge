# CLAUDE.md — Forge Factory Rules

> Read automatically by all agents at startup. Non-negotiable rules.
> When in doubt about a rule → questions/, never improvise.

---

## Stack

| Layer | Technology |
|---|---|
| Backend | Go 1.22, Chi/Echo router, sqlc (type-safe SQL), PostgreSQL 16 |
| Frontend | htmx 2.0 + Tailwind CSS (server-rendered with Go templates) |
| Validation | go-playground/validator |
| Tests BDD | godog (Cucumber for Go) |
| Tests Unit | go test + testify |
| Tests E2E | Playwright |
| CI/CD | GitHub Actions |

## Project structure

```
my-app/
├── cmd/
│   └── server/
│       └── main.go                    # Entry point
├── internal/
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── handler.go            # HTTP handlers
│   │   │   ├── service.go            # Business logic
│   │   │   ├── repository.go         # DB access (sqlc-generated)
│   │   │   ├── model.go              # Domain types
│   │   │   └── auth_test.go          # Unit tests
│   │   ├── catalog/
│   │   └── orders/
│   ├── shared/
│   │   ├── db/
│   │   │   ├── db.go                 # Connection pool
│   │   │   └── migrations/           # SQL migration files
│   │   ├── result/
│   │   │   └── result.go             # Result[T] pattern
│   │   ├── middleware/               # Auth, logging, tenancy
│   │   └── config/
│   │       └── config.go             # Env-based config
│   └── platform/
│       ├── router.go                 # Chi/Echo router setup
│       └── server.go                 # HTTP server lifecycle
├── web/
│   ├── templates/                    # Go html/template files
│   │   ├── layouts/
│   │   │   └── base.html
│   │   ├── partials/                 # htmx partial responses
│   │   └── pages/
│   ├── static/
│   │   ├── css/                      # Tailwind output
│   │   └── js/                       # htmx + Alpine.js (if needed)
│   └── embed.go                      # embed.FS for static assets
├── db/
│   ├── queries/                      # sqlc SQL queries
│   │   ├── auth.sql
│   │   ├── catalog.sql
│   │   └── orders.sql
│   ├── migrations/                   # goose / golang-migrate files
│   │   ├── 001_create_users.up.sql
│   │   └── 001_create_users.down.sql
│   └── sqlc.yaml                     # sqlc config
├── tests/
│   ├── features/                     # .feature files (English only)
│   │   ├── auth/
│   │   ├── catalog/
│   │   └── orders/
│   ├── steps/                        # godog step definitions
│   │   └── auth_steps_test.go
│   ├── e2e/                          # Playwright tests
│   └── integration_test.go           # Integration test helpers
├── go.mod
├── go.sum
├── Makefile
├── tailwind.config.js
└── docker-compose.yml                # PostgreSQL for local dev
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

**Backend** — run in order, STOP at first failure:
```bash
golangci-lint run ./...                # Linting — 0 errors
go build ./...                         # Compilation — 0 errors
go test ./internal/... -short          # Unit tests pass (skip integration)
go test ./tests/... -run TestFeatures  # godog BDD tests pass
```

**Frontend assets** — run if Tailwind changed:
```bash
npx tailwindcss -i web/static/css/input.css -o web/static/css/output.css --minify
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

### 8. Commit convention

```
feat(module): add feature description
fix(module): fix description
test(module): add test description
refactor(module): refactor description
```

---

## Stack-specific rules

### Result pattern

Use a generic Result type for all service methods. Never panic for business logic errors.

```go
// shared/result/result.go
package result

type Result[T any] struct {
    Value T
    Error string
    Code  string
    OK    bool
}

func Success[T any](value T) Result[T] {
    return Result[T]{Value: value, OK: true}
}

func Failure[T any](err string, code string) Result[T] {
    return Result[T]{Error: err, Code: code, OK: false}
}
```

```go
// handler.go
func (h *Handler) CreateOrder(w http.ResponseWriter, r *http.Request) {
    result := h.service.Create(r.Context(), dto)
    if !result.OK {
        http.Error(w, result.Error, mapCode(result.Code))
        return
    }
    render.JSON(w, r, result.Value)
}
```

### sqlc — type-safe SQL, no ORM

- Write SQL in `db/queries/*.sql` with sqlc annotations
- Run `sqlc generate` to produce Go code
- Never write raw SQL strings in Go code — always go through sqlc-generated functions

### htmx — server-rendered partials

- Full page loads return complete HTML (base layout + content)
- htmx requests (`HX-Request` header) return only the partial fragment
- Use `hx-swap`, `hx-target`, `hx-trigger` for interactivity — minimal custom JS

### Migrations via goose or golang-migrate

- One `.up.sql` and `.down.sql` per migration
- Sequential numbering (001, 002, ...)
- Never modify an existing migration — create a new one

### Testing strategy

| Layer | Framework | Role |
|---|---|---|
| Unit | go test + testify | Edge cases, validators, service logic. Mocked dependencies. |
| Integration | go test + Testcontainers | Contract testing, handlers against real DB. |
| BDD | godog | Functional scenarios via Gherkin. Runs against real DB. |
| E2E | Playwright | User flows in browser. |

---

## Frozen files

Never modify without human arbitration:
- `internal/shared/db/`
- `internal/shared/middleware/`
- `internal/platform/`
- `docker-compose.yml`

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

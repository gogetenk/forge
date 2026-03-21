# CLAUDE.md — Forge Factory Rules

> Read automatically by all agents at startup. Non-negotiable rules.
> When in doubt about a rule → questions/, never improvise.

---

## Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.12, FastAPI, SQLAlchemy 2.0, Alembic, PostgreSQL 16 |
| Frontend | React 19 (Vite) or htmx (server-rendered with Jinja2) |
| Validation | Pydantic v2 |
| Tests BDD | behave + requests |
| Tests Unit | pytest + pytest-asyncio |
| Tests E2E | Playwright |
| CI/CD | GitHub Actions |

## Project structure

```
my-app/
├── src/
│   ├── app/
│   │   ├── main.py                    # FastAPI app entry point
│   │   ├── config.py                  # Settings (pydantic-settings)
│   │   ├── deps.py                    # Dependency injection
│   │   ├── modules/
│   │   │   ├── auth/
│   │   │   │   ├── router.py          # FastAPI router
│   │   │   │   ├── service.py         # Business logic
│   │   │   │   ├── schemas.py         # Pydantic models (DTOs)
│   │   │   │   ├── models.py          # SQLAlchemy models
│   │   │   │   └── repository.py      # DB access
│   │   │   ├── catalog/
│   │   │   └── orders/
│   │   ├── shared/
│   │   │   ├── db.py                  # SQLAlchemy engine, session
│   │   │   ├── result.py              # Result[T] pattern
│   │   │   ├── base_model.py          # Base SQLAlchemy model
│   │   │   └── middleware/            # Auth, error handling, tenancy
│   │   └── alembic/
│   │       ├── versions/              # Migration files
│   │       └── env.py
│   └── frontend/                      # React (Vite) or templates/ (htmx)
│       ├── src/
│       │   ├── pages/
│       │   ├── components/
│       │   ├── lib/api/
│       │   └── mocks/                 # MSW handlers (React only)
│       └── package.json
├── tests/
│   ├── unit/                          # pytest unit tests
│   │   ├── test_auth_service.py
│   │   ├── test_order_service.py
│   │   └── conftest.py
│   ├── integration/                   # pytest + Testcontainers
│   │   ├── test_auth_api.py
│   │   └── conftest.py
│   ├── features/                      # .feature files (English only)
│   │   ├── auth/
│   │   ├── catalog/
│   │   └── orders/
│   ├── steps/                         # behave step definitions
│   └── environment.py                 # behave hooks
├── pyproject.toml                     # Project config (uv / pip)
├── requirements.txt
├── alembic.ini
└── docker-compose.yml                 # PostgreSQL for local dev
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
ruff check src/                        # Linting — 0 errors
ruff format --check src/               # Formatting — 0 diffs
python -m pytest tests/unit/ -q        # Unit tests pass
python -m pytest tests/integration/ -q # Integration tests pass
```

**BDD** — run after backend passes:
```bash
behave tests/features/                 # All scenarios pass
```

**Frontend** (if React/Vite):
```bash
cd src/frontend && npm run lint        # 0 errors
cd src/frontend && npm run build       # 0 TypeScript errors
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

Use a Result wrapper for all service methods. Never raise exceptions for business logic errors.

```python
# shared/result.py
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")

@dataclass
class Result(Generic[T]):
    ok: bool
    value: T | None = None
    error: str | None = None
    code: str | None = None

    @staticmethod
    def success(value: T) -> "Result[T]":
        return Result(ok=True, value=value)

    @staticmethod
    def failure(error: str, code: str = "error") -> "Result[T]":
        return Result(ok=False, error=error, code=code)
```

```python
# router.py
@router.post("/orders")
async def create_order(dto: CreateOrderSchema, service: OrderService = Depends()):
    result = await service.create(dto)
    if not result.ok:
        raise HTTPException(status_code=map_error_code(result.code), detail=result.error)
    return result.value
```

### Pydantic v2 for all input/output schemas

Every route validates input with Pydantic models. No raw `dict` access on request bodies.

### SQLAlchemy 2.0 style

Use the new 2.0 query style with `select()`, `Session.execute()`, and mapped classes.

### Alembic for migrations

- `alembic revision --autogenerate -m "description"` for new migrations
- Never modify the DB schema outside of Alembic

### Testing strategy

| Layer | Framework | Role |
|---|---|---|
| Unit | pytest + unittest.mock | Edge cases, validators, service logic. Mocked dependencies. |
| Integration | pytest + Testcontainers | Contract testing, API routes against real DB. |
| BDD | behave | Functional scenarios via Gherkin. Runs against real DB. |
| E2E | Playwright | User flows in browser. |

---

## Frozen files

Never modify without human arbitration:
- `src/app/shared/db.py`
- `src/app/shared/middleware/`
- `src/app/config.py`
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

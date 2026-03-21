# CLAUDE.md — Forge Factory Rules

> Read automatically by all agents at startup. Non-negotiable rules.
> When in doubt about a rule → questions/, never improvise.

---

## Stack

| Layer | Technology |
|---|---|
| Orchestration | .NET Aspire 9.x |
| Backend | ASP.NET Core 10, Minimal APIs, EF Core 10 + Npgsql (PostgreSQL 16) |
| Architecture | Modular Monolith (2 assemblies per module: `.Contracts` + runtime) |
| Frontend | Next.js 15 App Router, TypeScript, shadcn/ui, Tailwind CSS |
| Mocking | MSW (Mock Service Worker) — frontend dev without backend |
| Tests BDD | Reqnroll + xUnit + Testcontainers.PostgreSql |
| Tests E2E | Playwright |
| CI/CD | GitHub Actions |

## Project structure

```
MySolution.sln
├── AppHost/                          # .NET Aspire orchestrator
├── ServiceDefaults/                  # OpenTelemetry, health checks
├── MyApp.Api/                        # ASP.NET Core host (Minimal APIs)
├── Modules/
│   ├── Auth/
│   │   ├── MyApp.Auth.Contracts/     # PUBLIC: interfaces, DTOs, events
│   │   └── MyApp.Auth/               # INTERNAL: handlers, DbContext, entities
│   ├── Catalog/
│   │   ├── MyApp.Catalog.Contracts/
│   │   └── MyApp.Catalog/
│   └── Orders/
│       ├── MyApp.Orders.Contracts/
│       └── MyApp.Orders/
├── Shared/
│   ├── MyApp.Shared.Kernel/          # BaseEntity, value objects
│   └── MyApp.Shared.Infrastructure/  # Shared DB infrastructure
├── Tests/
│   ├── MyApp.Tests.Unit/             # xUnit + NSubstitute (no Testcontainers)
│   ├── MyApp.Tests.Integration/      # xUnit + Testcontainers (contract testing)
│   └── MyApp.Tests.Acceptance/       # Reqnroll + Testcontainers (BDD)
│       ├── Features/                 # .feature files (English only)
│       ├── StepDefinitions/
│       └── Support/
└── src/
    └── frontend/                     # Next.js 15 app
        ├── src/
        │   ├── app/                  # App Router pages
        │   ├── components/           # React components (shadcn/ui)
        │   ├── lib/api/              # API client (fetch-based)
        │   └── mocks/               # MSW handlers
        ├── tests/                   # Playwright E2E tests
        ├── package.json
        └── tsconfig.json
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
dotnet build MyApp.sln -c Release                          # MUST return 0 errors
dotnet test Tests/MyApp.Tests.Unit/ --no-build -c Release   # MUST pass
dotnet test Tests/MyApp.Tests.Integration/ --no-build -c Release  # MUST pass
```

**Frontend** — run in order, STOP at first failure:
```bash
cd src/frontend && npm run lint    # 0 errors (warnings OK)
cd src/frontend && npm run build   # 0 TypeScript errors
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

### Ardalis.Result everywhere

Every method that can fail returns `Result<T>` or `Result`. Zero exceptions for business control flow.

```csharp
// Domain
public static Result<Order> Create(...) { ... }

// Handler
public async Task<Result<OrderDto>> Handle(...) { ... }

// Endpoint — Minimal API only
group.MapPost("/", async (CreateOrderCommand cmd, ISender sender) =>
    (await sender.Send(cmd)).ToMinimalApiResult());
```

### 2 assemblies per module — strict isolation

- `.Contracts` is public. Runtime assembly is entirely `internal`.
- A module NEVER references another module's runtime — only `.Contracts`.
- Inter-module communication: `.Contracts` interfaces or MediatR notifications.

### Minimal APIs only — no Controllers

```csharp
// FORBIDDEN
[ApiController]
public class OrderController : ControllerBase { ... }
```

### MSW — Mock Service Worker (frontend)

- All frontend tasks start with MSW handlers — backend does not need to exist
- `lib/api/*.ts` uses the same `fetch` in dev (MSW-intercepted) and prod (real API)
- Zero conditional code `if (process.env.NODE_ENV === 'development')` in components

### Testing strategy — hourglass model

| Layer | Framework | Role |
|---|---|---|
| TU (Unit) | xUnit + NSubstitute | Edge cases, validators, domain logic. All mocked. |
| TI (Integration) | xUnit + Testcontainers | Contract testing, wiring, 1 per endpoint. No business logic. |
| TF (Functional) | Reqnroll + Testcontainers | BDD via Gherkin. Pure functional, zero technical jargon. |

---

## Frozen files

Never modify without human arbitration:
- `Shared/MyApp.Shared.Kernel/`
- `Shared/MyApp.Shared.Infrastructure/`
- `AppHost/Program.cs`
- `MyApp.Api/Program.cs`

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

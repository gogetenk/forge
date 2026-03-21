# Forge — AI-Powered Development Factory

> Process d'orchestration multi-agents pour construire un MVP avec Claude Code.
>
> **Zero trust envers les agents : chaque regle est appliquee par un mecanisme, jamais par une convention.**

---

## Pourquoi Forge ?

Developper un MVP, c'est des dizaines de modules a construire en parallele. Un seul dev (humain ou IA) met des semaines. Plusieurs agents IA sans cadre = chaos (conflits, specs ignorees, bugs invisibles).

**Forge** resout ca : un orchestrateur distribue le travail a des agents isoles, chacun livre une PR, et des garde-fous mecaniques empechent toute derive. L'humain garde le controle sur les specs et les reviews, jamais sur le code.

### Pour quel type de projet

- **MVP / v1** avec modules independants parallelisables
- **Stack bien definie** — conventions claires, pas d'improvisation
- **PO disponible** pour ecrire les specs Gherkin
- **CI/CD en place**

Pas fait pour : du legacy sans tests, de la R&D exploratoire, ou un projet solo.

### Chiffres (Vetolib MVP)

- **234+ taches** traitees en quelques jours
- **682 tests** (unitaires + integration + acceptance) — tous verts
- **10+ agents** en parallele sans conflit

---

## Vue d'ensemble

```mermaid
graph TD
    H[Humain - PO / Tech Lead] -->|/forge ou /loop 15m /forge| O[Orchestrateur]

    O -->|dispatch worktree| A1[Agent back-auth]
    O -->|dispatch worktree| A2[Agent front-auth]
    O -->|dispatch worktree| A3[Agent back-agenda]
    O -->|dispatch worktree| A4[Agent front-agenda]
    O -->|dispatch worktree| A5[Agent back-billing]

    A1 -->|PR| D[develop]
    A2 -->|PR| D
    A3 -->|PR| D
    A4 -->|PR| D
    A5 -->|PR| D

    D --> CI[CI / CD]
    CI -->|status| O
```

> **Takeaway :** Un orchestrateur qui ne code jamais, N agents isoles qui ne font que coder — separation totale des responsabilites.

---

## BDD-first : les Gherkin avant le code

Le PO ecrit les `.feature` (Gherkin) **avant** tout dev. L'agent les recoit et n'a qu'un objectif : les faire passer au vert.

```mermaid
sequenceDiagram
    participant PO as PO / Humain
    participant T as Fichier tache
    participant A as Agent Dev
    participant GH as GitHub

    PO->>PO: Ecrit les .feature (Gherkin)
    PO->>T: Cree todo-back-auth-001.md
    Note over T: contient les scenarios Gherkin
    A->>T: Lit la tache + .feature
    A->>A: Ecrit les step definitions
    A->>A: Run tests → RED
    A->>A: Implemente le code
    A->>A: Run tests → GREEN
    A->>A: Build + lint + tests unitaires
    A->>GH: PR (uniquement si tout est GREEN)
```

```gherkin
Feature: Appointment booking

  Scenario: Owner books an appointment for their pet
    Given an owner with a registered pet "Luna"
    And a veterinarian with available slots on Sunday
    When the owner books a 30-minute consultation for "Luna"
    Then the appointment is confirmed
    And the owner receives a confirmation
```

- Le `.feature` est la **spec vivante** — si un scenario n'est pas couvert, c'est un bug
- L'agent ne peut pas devier : son seul critere de succes est que les tests passent
- **L'agent ne cree et ne modifie JAMAIS un .feature** — propriete exclusive du PO
- Un hook (`guard-feature.sh`) **bloque mecaniquement** toute ecriture de jargon technique dans un .feature

### Zero trust : pourquoi le hook est necessaire

Sans garde-fou mecanique, les agents derivent. Ils ecrivent `the response status is 200` au lieu de `the operation succeeds`. On s'est retrouve avec 52 status codes HTTP dans nos Gherkin. Le hook rend ca physiquement impossible.

**Principe fondamental de Forge : si une regle n'est pas appliquee par un mecanisme, elle sera violee.** Les conventions ne suffisent pas avec des agents IA. Chaque regle critique a son hook, son check CI, ou son blocage automatique.

```mermaid
flowchart LR
    F[".feature existe deja"] --> S["Ecrire step definitions"]
    S --> R["Run → RED"]
    R --> I["Implementer le code"]
    I --> G["Run → GREEN"]
    G --> V["Build + lint + tests"]
    V --> C["Commit + PR"]
```

> **Takeaway :** Le PO definit le comportement en Gherkin, l'agent le fait passer au vert — zero interpretation, zero derive.

---

## Sequence globale d'une feature

```mermaid
sequenceDiagram
    participant PO as PO
    participant O as Orchestrateur
    participant B as Agent Backend
    participant F as Agent Frontend
    participant QA as Agent QA
    participant DS as Agent Designer
    participant GH as GitHub

    PO->>PO: Ecrit .feature + cree taches
    PO->>O: /forge

    O->>O: Check develop CI GREEN

    par Backend + Frontend en parallele
        O->>B: dispatch todo-back-auth + .feature
        O->>F: dispatch todo-front-auth (MSW)
    end

    B->>B: TDD sur les Gherkin
    F->>F: Dev avec mocks MSW

    B->>GH: PR backend
    F->>GH: PR frontend

    GH->>GH: Copilot review automatique
    O->>O: Lire commentaires Copilot
    alt Suggestions pertinentes
        O->>PO: "PR #X a des suggestions Copilot"
        PO->>GH: Apply suggestions
    end

    par QA + Designer en parallele (PR frontend)
        O->>QA: Valider les .feature via Playwright
        QA->>QA: Screenshots + video de chaque scenario
        QA->>GH: QA Report + screenshots
        O->>DS: Verifier coherence visuelle
        DS->>DS: Screenshots desktop/mobile/tablette
        DS->>GH: Design Review + captures
    end

    alt QA_DONE + DESIGN_OK
        O->>GH: merge PR
    else QA_FAILED ou DESIGN_ISSUE
        O->>B: retour au dev avec rapport
    end

    O->>O: Detecte done-back + done-front
    O->>O: Cree todo-wire-auth
    O->>GH: PR wire (branchement MSW → API reelle)

    O->>O: Verifie develop CI GREEN
```

> **Takeaway :** Front et back en parallele, puis QA et Designer valident avant le merge — rien n'arrive dans develop sans preuve fonctionnelle et visuelle.

---

## La boucle (toutes les 15 min)

```mermaid
flowchart TD
    START["/loop 15m /forge"] --> CHECK{"0. develop CI ?"}
    CHECK -->|RED| FIX[Dispatcher agent fix — tout bloque]
    FIX --> STOP([Fin du cycle])
    CHECK -->|GREEN| SCAN["1. Scanner tasks/*.md
    questions/*.md, disputes.md"]
    SCAN --> DISPATCH["2. Dispatcher agents
    sur les todo-* prets"]
    DISPATCH --> WIRE["3. Detecter taches wire
    a creer automatiquement"]
    WIRE --> TIMEOUT["4. Timeout WIP > 45 min
    remettre en todo"]
    TIMEOUT --> COPILOT["5a. Lire reviews Copilot
    sur chaque PR ouverte"]
    COPILOT --> COPILOTCHECK{"Suggestions
    pertinentes ?"}
    COPILOTCHECK -->|Oui| NOTIFY["Notifier humain :
    Apply suggestions sur GitHub"]
    NOTIFY --> STOP
    COPILOTCHECK -->|Non| QADESIGN["5b. QA + Designer
    sur PRs DEV_DONE"]
    QADESIGN --> MERGE["5c. Merger PRs
    QA_DONE + DESIGN_OK"]
    MERGE --> POSTMERGE{"develop CI
    apres merge ?"}
    POSTMERGE -->|RED| FIX
    POSTMERGE -->|GREEN| PROGRESS["6. Ecrire progress.md"]
    PROGRESS --> STOP
```

> **Takeaway :** La boucle tourne seule — l'humain n'intervient que sur les specs et les reviews.

---

## Systeme de taches file-based

Chaque tache est un fichier Markdown dans `tasks/`. Renommer le fichier = changer d'etat. Pas de base de donnees, juste le filesystem.

```mermaid
stateDiagram-v2
    [*] --> todo : tache creee par le PO
    todo --> wip : claim (rename par orchestrateur)
    wip --> done : PR merged
    wip --> todo : timeout 45 min (retry)
    done --> [*]
```

```markdown
# todo-back-auth-001.md — Implement login endpoint

**Dependances** : done-scaffold-000
**Skills** : ardalis-result, cqrs-mediatr, aspnet-minimal-api

## Gherkin
Scenario: Valid credentials grant access
  Given a registered user with email "vet@clinic.ae"
  When the user logs in with valid credentials
  Then the user is successfully authenticated

## Criteres de completion
[] Reqnroll scenarios GREEN
[] Tests unitaires + integration GREEN
[] PR creee vers develop
```

```mermaid
graph LR
    S[scaffold-000] --> BA[back-auth-001]
    FS[front-scaffold-000] --> FA["front-auth-001 (MSW)"]
    BA --> WA[wire-auth-001]
    FA --> WA
```

> **Takeaway :** Un rename de fichier remplace un board de tickets — simple, versionne dans git, lisible par tous.

---

## Isolation par worktree

Chaque agent travaille dans un git worktree isole. Il ne voit que les fichiers de son module.

```mermaid
graph TD
    REPO["Repo principal — orchestrateur"] --- W1["worktree back-auth
    branche: feat/back-auth-001"]
    REPO --- W2["worktree front-auth
    branche: feat/front-auth-001"]
    REPO --- W3["worktree back-agenda
    branche: feat/back-agenda-003"]

    W1 -->|PR| D[develop]
    W2 -->|PR| D
    W3 -->|PR| D
```

- `sparsePaths` : seuls les dossiers necessaires sont checkout
- 1 tache = 1 branche = 1 PR (max ~30 fichiers)
- Merge only, jamais rebase (force-push interdit)

> **Takeaway :** Les worktrees isolent les agents comme des conteneurs — impossible qu'un agent casse le travail d'un autre.

---

## QA + Designer : double validation avant merge

```mermaid
flowchart LR
    PR["PR prete"] --> QA["Agent QA
    Tests fonctionnels
    Screenshots par scenario"]
    PR --> D["Agent Designer
    Coherence visuelle
    Desktop / Mobile / Tablette"]
    QA --> V{"Verdict"}
    D --> V
    V -->|QA_DONE + DESIGN_OK| MERGE[Merge]
    V -->|Echec| FIX[Retour au dev]
```

- **Agent QA** : execute les tests Playwright headless, prend des screenshots de chaque scenario, compare le comportement a l'ecran aux .feature du PO
- **Agent Designer** : verifie le design system (shadcn/ui, tokens CSS, responsive), detecte les regressions visuelles

> **Takeaway :** Le QA verifie que ca marche, le Designer verifie que ca ressemble a ce qui est attendu — deux filets complementaires.

---

## Garde-fous (zero trust)

| Mecanisme | Declencheur | Effet |
|---|---|---|
| Gherkin obligatoire | Avant tout dev | Pas de .feature = pas de code |
| `guard-feature.sh` | Ecriture dans un .feature | Bloque le jargon technique |
| `verify-before-push.sh` | `git push` | Build + tests doivent passer |
| `guard-shared.sh` | Ecriture dans `Shared/` | Bloque — fichiers geles |
| Copilot review | PR ouverte | Review automatique avant merge |
| Agent QA | PR `DEV_DONE` | Tests Playwright + screenshots |
| Agent Designer | PR frontend `DEV_DONE` | Coherence design system |
| `PostCompact` hook | Compaction contexte | Detection agents zombies |
| WIP timeout | Cycle orchestrateur | Remet en todo apres 45 min |
| `log-cost.sh` | Fin de session | Alerte si > $2 par session |

> **Takeaway :** Aucune regle ne repose sur la bonne volonte d'un agent. Chaque regle a un mecanisme qui l'applique.

---

## Commandes

| Commande | Quand | Effet |
|---|---|---|
| `/kickoff` | Debut de projet | Le PO agent construit le backlog complet via Q&A |
| `/forge` | En continu | Cycle orchestrateur complet |
| `/loop 15m /forge` | En continu | Cycle auto toutes les 15 min (expire apres 3j) |
| `/status` | A tout moment | Etat rapide en < 10 lignes |
| `/dev tasks/todo-xxx.md` | Manuel | Lancer un agent dev sur une tache |
| `/po` | Quand bloque | Traiter les questions metier en attente |

---

## Principes

1. **L'orchestrateur ne code jamais** — il coordonne, dispatch, merge, surveille
2. **BDD-first** — les .feature existent AVANT le code, c'est le contrat de l'agent
3. **Zero trust** — chaque regle est appliquee par un hook, un check CI, ou un blocage automatique
4. **Parallelisme maximum** — autant d'agents que de taches pretes, front et back en parallele
5. **MSW-first** — le frontend n'attend jamais le backend
6. **Isolation par worktree** — chaque agent dans son conteneur git
7. **Atomicite file-based** — rename de fichier = transition d'etat
8. **develop GREEN = invariant** — si CI est RED, tout est bloque
9. **1 tache = 1 branche = 1 PR** — squash merge, max ~30 fichiers
10. **Fail-fast** — en cas de doute, l'agent se bloque et ecrit dans `questions/`

---

*Copyright 2026 Yannis TOCREAU. Tous droits reserves.*
*Ce document et le process Forge qu'il decrit sont la propriete intellectuelle de Yannis TOCREAU. Toute reproduction, distribution ou utilisation commerciale, en tout ou partie, est interdite sans autorisation ecrite prealable.*

# todo-{module}-{id}.md — {Short description}

**Dependencies**: done-{dependency-1}, done-{dependency-2}
**Skills**: {list of skills to read}

## Objective
{Clear, concise description of what needs to be built}

## Gherkin
{Copy the .feature scenarios that this task must make pass}

```gherkin
Scenario: {scenario name}
  Given {precondition}
  When {action}
  Then {expected outcome}
```

## Definition of Done
- [ ] Build passes (0 errors)
- [ ] Acceptance test scenarios GREEN
- [ ] Unit + integration tests GREEN
- [ ] {Add task-specific criteria here}
- [ ] PR created towards develop

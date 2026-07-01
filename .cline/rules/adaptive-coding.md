# Adaptive coding workflow

Optimize for correct useful code per token.

## Default path

- Use the current Cline session for small, local, low-risk tasks.
- Do not load broad repository context unless it is needed for correctness.
- Prefer targeted reads/searches and user-provided paths.
- Keep summaries and handoffs compact.

## Escalate to Agent Teams when

- the task needs broad exploration before implementation;
- the change spans multiple files or subsystems;
- implementation and review should be independent;
- the task may span multiple turns or sessions;
- the same failure pattern repeats.

## Use reviewer when

- a meaningful implementation diff exists;
- behavior, tests, scripts, config loading, security, or public UX changed;
- implementation deviates from the plan;
- the user explicitly asks for review.

## Use oracle only when

- reviewer escalates a strategic issue;
- the same failure signature repeats;
- API, schema, state, IAM, security, data model, or long-lived architecture decisions are involved;
- two plausible approaches have unclear trade-offs.

Do not use oracle for routine implementation judgment.

## Handoff format

When delegating, include only:

1. goal;
2. acceptance criteria;
3. relevant paths;
4. constraints;
5. commands to run;
6. expected report format.

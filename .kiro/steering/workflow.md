---
inclusion: always
---

# Workflow

## Exploration

1. Identify the affected layer. Read only its steering file and relevant target files.
2. Read the relevant Gherkin acceptance criteria before implementation.
3. Prefer `grep` and symbol searches over opening entire files.
4. For large files, inspect only relevant functions and surrounding context.
5. Reuse information already available in context. Never re-read files unnecessarily.
6. Explore only enough to understand the requirements, dependencies, conventions, and affected components.
7. Avoid exhaustive repository searches, unrelated investigations, and speculative troubleshooting.
8. Inspect existing scripts and tooling before attempting alternative commands or approaches.

## Repository Findings

- Use `repo-findings.md` for reusable repository-specific discoveries.
- Read existing findings before repeating repository exploration.
- Record only findings that are useful across multiple tasks.
- Update existing findings rather than duplicating information.
- Do not record temporary observations, exploration logs, or task-specific reasoning.
- Creating `repo-findings.md` is optional. Do not create it for findings that have no future value.

## Implementation

1. Establish the implementation scope before editing.
2. For multi-file changes, prepare a plan of no more than five bullets.
3. Wait for approval on cross-layer changes.
4. Prefer the smallest diff that satisfies the requirements.
5. Avoid unrelated refactoring, renaming, and reformatting.
6. Do not repeatedly reconsider an established implementation decision without new evidence.

## Context Efficiency

- Prioritize implementation over unnecessary exploration and narration.
- Do not explain internal reasoning or narrate every tool invocation.
- Do not repeat findings already communicated.
- Investigate unexpected errors only enough to establish their cause, relevance, and impact.
- Do not investigate unrelated baseline failures.
- Stop exploring when sufficient information exists to implement safely.

## Completion

1. Follow the verification rules in `testing.md`.
2. Report files changed, tests run, results, and relevant blockers.
3. Distinguish pre-existing failures from regressions.
4. Do not repeat implementation details already evident from the changes.
5. Ask one focused question when blocked. Never guess at scene or resource wiring.

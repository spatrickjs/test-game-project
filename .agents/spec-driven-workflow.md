# Spec-driven workflow

Use the repository's existing `.kiro/specs/<feature>/{requirements,design,tasks}.md` convention and Gherkin acceptance criteria in `features/`. This file defines process; [architecture.md](architecture.md) owns constraints and [testing-guidelines.md](testing-guidelines.md) owns all test execution timing.

## 1. Analyze requirements

Read the task, relevant Gherkin, matching specification, and affected implementation. Use [repo-findings.md](../repo-findings.md) to locate entry points. Separate requested behavior, verified current behavior, and unresolved questions. Existing menu and fence specifications are the starting points for those features; do not infer completion from task checkboxes.

## 2. Plan before implementation

State acceptance criteria, non-goals, affected layers/files, dependencies, and final verification in at most five bullets for multi-file work. For a new feature, prepare requirements, design, and tasks in the existing spec structure; small fixes may use the explicit request as their specification.

Implement only approved scope. A clear user instruction to implement a supplied specification already supplies approval. If approval is absent or behavior is ambiguous, present the concrete unresolved decision before dependent implementation. Preserve the existing cross-layer approval requirement; do not request approval again for an already-authorized design. Material departures require an updated specification and approval.

## 3. Implement the approved tasks

Follow task dependencies and existing abstractions; update acceptance criteria when approved requirements change. Keep requirement-to-task/test traceability. Write required tests alongside the changes; execute them according to the timing rule in testing-guidelines. Avoid unrelated refactors and document any remaining scene-authoring dependency rather than guessing wiring.

## 4. Final verification and handoff

Once all implementation tasks are complete, perform the single final verification phase defined in testing-guidelines. Compare results with each acceptance criterion; do not mark unverified behavior complete. Report changed files, verification results, and remaining gaps. Update task status and affected context facts without copying implementation details into multiple steering files.

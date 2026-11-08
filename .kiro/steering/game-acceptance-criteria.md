---
inclusion: auto
name: game-acceptance-criteria
description: Use when analyzing, designing, implementing, or testing game features. Ensures implementation follows the Gherkin acceptance criteria.
---

# Game Acceptance Criteria

The project uses Gherkin feature files to define expected game behavior.

## Rules

1. Always consult the relevant Gherkin feature file before implementing a feature.
2. Treat Gherkin scenarios as acceptance criteria.
3. Do not introduce functionality that contradicts existing scenarios.
4. Identify missing, ambiguous, or conflicting requirements before implementation.
5. Ensure every Gherkin scenario has a corresponding implementation or test.
6. Update the Gherkin file when requirements change.

## Feature References

Main Menu:
#[[file:features/main_menu.feature]]

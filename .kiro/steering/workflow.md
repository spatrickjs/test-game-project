---
inclusion: always
---
# Workflow (context-efficient)

1. Identify layer. Read only that layer's steering file and the target file.
2. Prefer `grep`/symbol search over opening files. Open ranges, not whole files.
3. Large files (`field_world_view.gd`, `farming_controller.gd`, `field_prototype_presenter.gd`): read the needed function only.
4. Do not re-read files already in context.
5. Plan in <=5 bullets before multi-file edits. Wait for approval on cross-layer changes.
6. Smallest diff. No refactors, renames, or reformatting outside the task.
7. After edits, run only the tests for the touched layer (see testing.md). Run the full suite once before finishing.
8. Report: files changed, tests run, result. No restating code.
9. Ask one question when blocked; do not guess at scene/resource wiring.
10. Keep steering files short. Move detail into fileMatch files, not `always` ones.

## Art and visual mappings

When a task requires mapping art tiles to code (e.g. connection mask → atlas coords), ask the user rather than pixel-analysing the PNG. Isometric art fails pixel analysis because the central post/base occupies all quadrants.

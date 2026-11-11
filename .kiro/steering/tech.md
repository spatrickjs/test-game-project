---
inclusion: always
---
# Tech and conventions

- Godot 4.7, typed GDScript. Every var, param, return typed.
- Validate-don't-throw: `validate() -> PackedStringArray`; empty means valid. Failures set `last_error`.
- Copy-on-stage: mutate a copy, validate, then commit. Failed operations leave no partial state (grid, RNG, counters, clock).
- Exports assigned in Inspector. No hardcoded node paths. Presenters/views expose `validate_configuration()`.
- `_connect_once` for signals; reconnect must not duplicate intents.
- Enum numeric values are save-stable. Never reorder; only append.
- Seeded RNG streams stay independent (simulation, activation, decoration). Do not share.
- Never edit `.tscn` or `.tres` by hand. User authors scenes in the Editor.
- Do not add `localStorage`-style globals/autoloads without asking.

---
inclusion: always
---
# Product

Turn-based isometric farming sim. Plant crops, manage soil, contain disease spread, harvest.

- Crops: sugarcane, rice, corn. Terrain: dry soil, paddy mud, grass.
- Player acts via a farmer action queue; turns are manual ("End Turn"). No timers drive simulation.
- Win: Meet harvest quota within x amount of turns (`GameStateManager`). Else game over.
- Disease: SIR, SEIR, stochastic CA models. Rice Blast is the playtest disease; others are drafts with shared toy parameters.
- Menu: main, settings (save/revert/dirty), about, play (continue gated on save).
- Parameters are fictional gameplay tuning, not calibrated science. Do not present them as such.

# Seed inoculation

Implemented with the user-approved fictional gameplay settings on 2026-11-10.

Select **Inoculate**, then click or drag across living planted crops. The farmer applies treatment on arrival. Moisture must be at least 0.3. Protection reduces recipient transmission by 25% before maturity and 15% at maturity across SIR, SEIR, and CA. It does not cure existing infection. Reapplication replaces the bonus and refreshes the three-turn duration without stacking.

Protection applies during each of the next three successful transitions, then expires. Movement preserves treatment; harvesting/removal clears it. Failed turns preserve protection, RNG state, diagnostic counters, and clock. The inspector shows active status, remaining turns, and current bonus. Press **O** to toggle the crop status overlay; a cyan ring identifies protected crops.

`FarmingController.inoculation_profile` exposes duration, moisture bounds, growing/mature bonuses, and dry/humid weather decay. Decay linearly interpolates between those endpoints using the turn's relative humidity and subtracts from the bonus after transmission. Both endpoints default to zero. Values are game tuning, not agricultural advice.

The saved scene remains 9x9. Logic acceptance fixtures use 9x6. `tools/setup_inoculation.gd` adds/wires the new button and cursor through the editor; `tools/bake_ui_to_scene.gd` also supports rebuilding the control. Do not rerun broad field setup tools merely to launch the game.

## Verification

The registered suite was run once with:

```powershell
python tools/run_tests.py --godot 'C:\Program Files\Godot\godot.exe.exe'
```

The initial inoculation fixture had a floating-point boundary error and was corrected. Follow-up checks used the same runner with `--test tests/logic/seed_inoculation_test.gd --test tests/presentation/seed_inoculation_ui_test.gd`.

- Logic/simulation check: strict PASS, covering application, rejection, queue commit/reservations/stale arrivals/cancellation, maturity, copy isolation, crop transfer/reset/harvest, duration, weather decay, reapplication, rollback, coefficient caps, and all three model callers.
- UI assertions: `SEED_INOCULATION_UI_PASS`, covering saved wiring, queued farmer arrival, inspector feedback, overlay snapshots/toggling, and expiration refresh. The strict UI result remains FAIL because scene loading emits terrain TileSetAtlasSource errors. These diagnostics are not suppressed.
- Rendered OpenGL check: captured `.godot/inoculation_preview.png` for inspection. Physical Android interaction remains untested.
- The full suite is not green. Existing checks also report terrain atlas diagnostics and assertions involving disease presets, scene configuration, crop animation speeds, camera behavior, terrain preview, and background independence. Authored terrain and crop artwork were not retuned to satisfy those checks.

T8 remains open until strict scene verification and device checks are resolved. Historical test counts are not current verification evidence.

# Steps 4.3 / 4.3B: camera and input continuation

Recorded 2026-11-05 (Asia/Shanghai). This guide documents implemented behavior, not a new implementation proposal.

## Runtime contract

- `FieldWorldView.frame_field()` retains the original field-framing calculation. It captures that zoom as `min_zoom` and that position as the default center. `max_zoom` is 2.5 times the default by default.
- Camera panning is constrained to the world rectangle visible in the original overview. Per-axis allowed center offset is `viewport_size / 2 * (1 / min_zoom - 1 / current_zoom)`. At minimum zoom the camera is explicitly restored to the exact default center.
- Mouse wheel and two-finger pinch zoom preserve the world point beneath the cursor or pinch midpoint before bounds clamping. Pinch also follows midpoint translation. Single-finger and left-mouse drag pan inversely with zoom.
- A 10 px displacement threshold distinguishes taps from drags. Stationary mouse clicks and single-finger taps emit tile intent on release. Dragging, multi-touch, cancellation, or crossing UI suppresses that intent.
- World input uses `_unhandled_input`, not `_input`. Registered GUI controls cancel world gestures. Explicit touch rectangle checks cover disabled mouse emulation; blocked fingers remain quarantined until released. Focus loss, disabling interaction, and reframing clear gesture state.
- Viewport resizing re-establishes the overview and resets zoom/pan. It does not preserve an inspection position across resize.
- The persistent bottom-right `HUD/CameraZoomButton` toggles between 1.8 times overview zoom and full overview. Its caption is `Zoom in` or `Reset view`. This is the chosen one-handed alternative to double-tap; single taps are not delayed.
- The new button adapts bottom/right insets to Android's reported safe area. This is not a redesign of the entire HUD for every device or orientation.
- Interactive HUD panels/buttons stop mouse input and disable wheel pass-through. Existing game-state ownership and turn order are unchanged.

## Files and saved wiring

- `src/presentation/world/field_world_view.gd`: camera math, gestures, UI input guards, `camera_view_changed` signal.
- `src/presentation/world/field_prototype_presenter.gd`: exported `camera_zoom_button`, signal wiring, caption refresh, registration of UI roots.
- `src/presentation/ui/camera_zoom_button.gd`: safe-area adjustment for the new button.
- `tools/bake_ui_to_scene.gd`: persistent button creation/ownership/binding and HUD blocking settings, with existing Undo/Redo workflow.
- `field_prototype.tscn`: serialized through the normal Godot editor setup; main-scene UID preserved. Reload an already open scene before testing.
- `tools/setup_field_tools.gd`: existing setup entry point ran the updated baker and saved the scene. No raw scene/resource text was patched.
- `tests/presentation/camera_zoom_test.gd` and `camera_ux_test.gd`: registered in `tools/run_tests.py`. The scene-integration test now expects the HUD panel to stop input, reflecting the requested UI contract.

## Verification and outstanding checks

All eleven strict tests passed after Step 4.3B, including native viewport event injection, both touch-emulation settings, UI-first/world-first mixed gestures, all four pan limits, focal offsets, reset, and resize.

A later two-line rename changed `_is_over_ui(position)` to `_is_over_ui(screen_pos)` to avoid `SHADOWED_VARIABLE_BASE_CLASS`. Fresh editor diagnostics were clear. The full suite then passed ten of eleven: the crop-visual test reported 30 failures. A controlled comparison reproduced exactly those failures with the original parameter name, then restored the fix. Camera tests passed. See `PROJECT_HANDOFF.md` for concurrent crop-animation work; do not claim the latest entire suite is green.

Physical Android testing remains outstanding, particularly one/two-handed gestures, notch/navigation insets, UI overlap, and orientation changes. The connector can read project metadata but last reported no tracked active process, so the live editor Output panel was not verified.

No tests were rerun for this documentation refresh.

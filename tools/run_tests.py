"""Run every executable test in fresh Godot processes; fail on engine errors."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True)
parser.add_argument("--test", action="append", help="Run only this registered test (repeatable)")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
logs = root / ".godot"
tests = [
    "tests/presentation/infection_alert_test.gd",
    "tests/logic/field_prototype_smoke.gd",
    "tests/logic/disease_activation_test.gd",
    "tests/logic/disease_catalog_test.gd",
    "tests/logic/playable_disease_catalog_test.gd",
    "tests/logic/field_scene_integration.gd",
    "tests/logic/simulation_scaffold_test.gd",
    "tests/logic/disease_playtest_test.gd",
    "tests/simulation/epidemiology_models_test.gd",
    "tests/simulation/transmission_modifiers_test.gd",
    "tests/presentation/tile_inspector_builder_editor_test.gd",
    "tests/presentation/crop_growth_visuals_test.gd",
    "tests/logic/field_management_test.gd",
    "tests/presentation/camera_zoom_test.gd",
    "tests/presentation/camera_ux_test.gd",
    "tests/simulation/crop_growth_test.gd",
    "tests/simulation/scoring_model_test.gd",
    "tests/logic/weather_soil_tools_test.gd",
    "tests/presentation/terrain_preview_editor_test.gd",
    "tests/presentation/terrain_preview_runtime_test.gd",
    "tests/presentation/grass_overlay_test.gd",
    "tests/logic/queued_field_actions_test.gd",
    "tests/logic/action_bar_test.gd",
    "tests/presentation/hoe_and_shovel_test.gd",
    "tests/logic/scoring_test.gd",
    "tests/presentation/background_layers_test.gd",
    "tests/logic/fence_treatment_test.gd",
    "tests/logic/fence_treatment_property_test.gd",
    "tests/simulation/fence_containment_test.gd",
    "tests/simulation/fence_connections_test.gd",
    "tests/presentation/fence_presentation_test.gd",
    "tests/presentation/fence_autotiling_test.gd",
    "tests/menu/settings_state_unit_test.gd",
    "tests/menu/settings_state_property_test.gd",
    "tests/menu/navigation_controller_property_test.gd",
    "tests/menu/save_game_controller_property_test.gd",
    "tests/logic/treatment_test.gd",
    "tests/logic/treatment_gherkin_test.gd",
    "tests/logic/treatment_property_test.gd",
    "tests/logic/treatment_integration_test.gd",
    "tests/presentation/treatment_panel_test.gd",
]
if args.test:
    unknown = set(args.test) - set(tests)
    if unknown:
        parser.error("Unregistered tests: " + ", ".join(sorted(unknown)))
    tests = [test for test in tests if test in args.test]
failed = False
for test in tests:
    command = [args.godot, "--headless", "--path", str(root),
               "--script", "res://" + test, "--log-file", str(logs / (Path(test).stem + ".log"))]
    environment = os.environ.copy()
    environment.pop("GODOT_EDITOR_TEST", None)
    environment.pop("GODOT_PLAYTEST_SETUP", None)
    environment.pop("GODOT_CROP_VISUAL_SETUP", None)
    environment.pop("GODOT_FIELD_TOOLS_SETUP", None)
    environment.pop("GODOT_MANUAL_WORLD_SETUP", None)
    environment.pop("GODOT_ACTIVATION_SETUP", None)
    environment.pop("GODOT_CATALOG_SETUP", None)
    environment.pop("GODOT_DRAFT_DISEASE_PLAYTEST_SETUP", None)
    environment.pop("GODOT_SHADOW_SETUP", None)
    environment.pop("GODOT_LIGHTING_SETUP", None)
    environment.pop("GODOT_FENCE_TOOL_SETUP", None)
    if test.endswith("editor_test.gd"):
        command = [args.godot, "--headless", "--path", str(root), "--editor",
                   "--log-file", str(logs / (Path(test).stem + ".log"))]
        environment["GODOT_EDITOR_TEST"] = "terrain_preview" if "terrain_preview" in test else "tile_inspector_builder"
    try:
        result = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        print("FAIL " + test + " (timed out; inspect .godot log)")
        failed = True
        continue
    output = result.stdout + result.stderr
    diagnostics = [line for line in output.splitlines()
                   if any(token in line for token in ("ERROR:", "WARNING:", "FAIL:"))]
    passed = result.returncode == 0 and "_PASS" in output and not diagnostics
    print(("PASS " if passed else "FAIL ") + test)
    for line in diagnostics:
        print("  " + line)
    failed |= not passed
sys.exit(1 if failed else 0)

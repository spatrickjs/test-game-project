extends "res://tests/logic/seed_inoculation_test.gd"

func _run() -> void:
	await _scene_tests()
	if failures.is_empty():
		print("SEED_INOCULATION_UI_PASS")
	quit(0 if failures.is_empty() else 1)

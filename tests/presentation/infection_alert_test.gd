extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var alert: Node2D = preload("res://src/presentation/world/infection_alert_overlay.gd").new()
	root.add_child(alert)
	alert.set_process(false)
	var snapshot: FieldGridState = FieldGridState.new()
	snapshot.initialize(1, 1, AbioticState.new())
	var cell: FieldCellState = snapshot.get_cell(Vector2i.ZERO)
	cell.has_crop = true
	cell.infected_fraction = 0.2
	alert.show_snapshot(snapshot)
	alert.set_alerts_enabled(true)
	alert._process(0.0)
	var success: bool = alert._visible_seconds == 5.0 and alert._beep.playing and alert.is_flash_visible()
	await create_timer(0.25).timeout
	alert._process(0.5)
	success = success and not alert.is_flash_visible()
	alert._process(0.5)
	success = success and alert.is_flash_visible()
	alert._process(4.0)
	success = success and alert._visible_seconds == 0.0
	alert.show_snapshot(snapshot)
	alert._process(9.9)
	success = success and alert._visible_seconds == 0.0
	alert._process(0.2)
	await create_timer(0.25).timeout
	success = success and alert._visible_seconds == 5.0 and alert.is_flash_visible()
	cell.infected_fraction = 0.0
	alert.show_snapshot(snapshot)
	success = success and alert._visible_seconds == 0.0 and not alert._beep.playing
	alert._process(20.0)
	success = success and alert._visible_seconds == 0.0
	cell.infected_fraction = 0.2
	alert.show_snapshot(snapshot)
	alert.set_alerts_enabled(false)
	alert._process(20.0)
	success = success and alert._visible_seconds == 0.0
	var crops: CropDatabase = CropDatabase.new()
	var crop: CropData = CropData.new()
	crop.crop_type = cell.crop_type
	crops.crops.append(crop)
	cell.soil = SoilState.new()
	cell.soil.moisture = crop.growth_profile.moisture_minimum
	alert.show_snapshot(snapshot, crops)
	success = success and alert._dry_crops.is_empty()
	cell.soil.moisture -= 0.01
	alert.show_snapshot(snapshot, crops)
	success = success and alert._dry_crops.has(Vector2i.ZERO) and alert._infected.has(Vector2i.ZERO)
	cell.infected_fraction = 0.0
	alert.show_snapshot(snapshot, crops)
	alert.set_alerts_enabled(true)
	alert._process(20.0)
	await create_timer(0.25).timeout
	success = success and alert.is_flash_visible()
	alert._process(5.0)
	alert._process(9.9)
	success = success and not alert.is_flash_visible()
	alert._process(0.2)
	await create_timer(0.25).timeout
	success = success and alert.is_flash_visible()
	cell.soil.moisture = crop.growth_profile.moisture_minimum
	alert.show_snapshot(snapshot, crops)
	success = success and alert._dry_crops.is_empty() and not alert.is_flash_visible()
	cell.soil.moisture = 0.0
	cell.has_crop = false
	alert.show_snapshot(snapshot, crops)
	success = success and alert._dry_crops.is_empty()
	crop = null
	crops = null
	alert.free()
	cell = null
	snapshot = null
	await create_timer(0.1).timeout
	await process_frame
	await process_frame
	print("INFECTION_ALERT_PASS" if success else "FAIL: Infection alert timing or lifecycle")
	quit(0 if success else 1)

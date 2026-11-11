extends Node2D
## Presentation-only reminders. Timing never advances the simulation.

const ALERT_DURATION: float = 5.0
const COOLDOWN_DURATION: float = 10.0
const FLASH_INTERVAL: float = 0.5

var terrain_layer: TileMapLayer
var _infected: Array[Vector2i] = []
var _dry_crops: Array[Vector2i] = []
var _enabled: bool = false
var _visible_seconds: float = 0.0
var _cooldown_seconds: float = 0.0
var _beep: AudioStreamPlayer


func _ready() -> void:
	z_index = 100
	_beep = AudioStreamPlayer.new()
	_beep.volume_db = -18.0
	if AudioServer.get_bus_index("SFX") >= 0:
		_beep.bus = "SFX"
	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(4410 * 2)
	for index: int in range(4410):
		var envelope: float = sin(PI * float(index) / 4410.0)
		var value: int = int(sin(TAU * 880.0 * float(index) / 22050.0) * envelope * 16000.0)
		samples.encode_s16(index * 2, value)
	sound.data = samples
	_beep.stream = sound
	add_child(_beep)


func show_snapshot(snapshot: FieldGridState, crops: CropDatabase = null) -> void:
	_infected.clear()
	_dry_crops.clear()
	if snapshot != null:
		for y: int in range(snapshot.height):
			for x: int in range(snapshot.width):
				var cell: FieldCellState = snapshot.get_cell(Vector2i(x, y))
				if cell != null and cell.has_crop and cell.infected_fraction > 0.0:
					_infected.append(cell.coordinates)
				if cell == null or not cell.has_crop or cell.soil == null or crops == null:
					continue
				var crop: CropData = crops.get_crop(cell.crop_type)
				if crop != null and crop.growth_profile != null and cell.soil.moisture < crop.growth_profile.moisture_minimum:
					_dry_crops.append(cell.coordinates)
	if _infected.is_empty() and _dry_crops.is_empty():
		_visible_seconds = 0.0
		if _beep != null:
			_beep.stop()
	queue_redraw()


func set_alerts_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_visible_seconds = 0.0
		if _beep != null:
			_beep.stop()
	queue_redraw()


func _process(delta: float) -> void:
	if not _enabled:
		return
	_cooldown_seconds = maxf(0.0, _cooldown_seconds - delta)
	if _visible_seconds > 0.0:
		_visible_seconds = maxf(0.0, _visible_seconds - delta)
		queue_redraw()
	if (not _infected.is_empty() or not _dry_crops.is_empty()) and _cooldown_seconds <= 0.0:
		_visible_seconds = ALERT_DURATION
		_cooldown_seconds = ALERT_DURATION + COOLDOWN_DURATION
		_beep.play()
		queue_redraw()


func is_flash_visible() -> bool:
	return _enabled and _visible_seconds > 0.0 and int((ALERT_DURATION - _visible_seconds) / FLASH_INTERVAL) % 2 == 0


func _draw() -> void:
	if not is_flash_visible() or terrain_layer == null:
		return
	var font: Font = ThemeDB.fallback_font
	for coordinates: Vector2i in _infected:
		var center: Vector2 = to_local(terrain_layer.to_global(terrain_layer.map_to_local(coordinates))) + Vector2(0, -72)
		draw_circle(center, 16.0, Color(0.22, 0.08, 0.02, 0.95))
		draw_circle(center, 13.0, Color(1.0, 0.75, 0.12))
		draw_string(font, center + Vector2(-5, 9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.25, 0.06, 0.02))
	for coordinates: Vector2i in _dry_crops:
		var center: Vector2 = to_local(terrain_layer.to_global(terrain_layer.map_to_local(coordinates))) + Vector2(0, -72)
		if _infected.has(coordinates):
			center.x += 36.0
		draw_circle(center, 16.0, Color(0.02, 0.12, 0.24, 0.95))
		var drop: PackedVector2Array = PackedVector2Array([
			center + Vector2(0, -12), center + Vector2(8, -1),
			center + Vector2(10, 4), center + Vector2(8, 9),
			center + Vector2(4, 12), center + Vector2(-4, 12),
			center + Vector2(-8, 9), center + Vector2(-10, 4),
			center + Vector2(-8, -1)
		])
		draw_colored_polygon(drop, Color(0.15, 0.7, 1.0))
		draw_circle(center + Vector2(-3, 4), 2.5, Color(0.75, 0.95, 1.0))

@tool
extends RefCounted
## Editor-time image processing. Original PNGs are never changed.

const STAGE_SCALE: Array[float] = [0.35, 0.60, 0.85, 1.0]
const MATURE_HEIGHT_RATIO: float = 2.8
const PADDING: int = 4


static func normalize(source: Image, tile_size: Vector2i, stage: int, shared_height: float = -1.0, artwork_scale: float = 1.0) -> Image:
	return normalize_strip([source], tile_size, stage, shared_height, artwork_scale)


## Normalizes 1 or more animation frames into a horizontal sprite strip using a
## locked union bounding box so roots never jitter or shift between frames.
static func normalize_strip(frames: Array[Image], tile_size: Vector2i, stage: int, shared_height: float = -1.0, artwork_scale: float = 1.0) -> Image:
	if frames.is_empty() or stage < 0 or stage > 3 or tile_size.x < 1 or tile_size.y < 1:
		return null
	var cleaned_frames: Array[Image] = []
	var union_bounds: Rect2i = Rect2i()
	for idx: int in range(frames.size()):
		var frame: Image = frames[idx]
		if frame == null or frame.is_empty():
			return null
		var cleaned: Image = _visible_art(frame)
		var bounds: Rect2i = cleaned.get_used_rect()
		if not bounds.has_area():
			return null
		cleaned_frames.append(cleaned)
		union_bounds = bounds if idx == 0 else union_bounds.merge(bounds)

	var max_width: int = maxi(2, int(round(float(tile_size.x) * 0.95)))
	var mature_height: float = float(tile_size.y) * MATURE_HEIGHT_RATIO
	var target_height: float = minf(mature_height, shared_height) if shared_height > 0.0 else mature_height
	var scale_factor: float = minf(float(max_width) / union_bounds.size.x, target_height / union_bounds.size.y) * STAGE_SCALE[stage] * artwork_scale

	var width: int = maxi(2, int(floor(float(union_bounds.size.x) * scale_factor / 2.0)) * 2)
	var height: int = maxi(2, int(floor(float(union_bounds.size.y) * scale_factor / 2.0)) * 2)

	var cell_width: int = int(ceil(float(max_width + PADDING * 2) / 2.0)) * 2
	var cell_height: int = int(ceil((mature_height + PADDING * 2) / 2.0)) * 2
	var strip_canvas: Image = Image.create(cell_width * cleaned_frames.size(), cell_height, false, Image.FORMAT_RGBA8)
	strip_canvas.fill(Color.TRANSPARENT)

	for idx: int in range(cleaned_frames.size()):
		var trimmed: Image = cleaned_frames[idx].get_region(union_bounds)
		trimmed.convert(Image.FORMAT_RGBA8)
		trimmed.resize(width, height, Image.INTERPOLATE_LANCZOS)
		var dest_x: int = idx * cell_width + int(cell_width / 2.0) - int(width / 2.0)
		var dest_y: int = cell_height - PADDING - height
		strip_canvas.blit_rect(trimmed, Rect2i(Vector2i.ZERO, Vector2i(width, height)), Vector2i(dest_x, dest_y))

	return strip_canvas


static func single_cell_size(tile_size: Vector2i) -> Vector2i:
	var max_width: int = maxi(2, int(round(float(tile_size.x) * 0.95)))
	var mature_height: float = float(tile_size.y) * MATURE_HEIGHT_RATIO
	var cell_width: int = int(ceil(float(max_width + PADDING * 2) / 2.0)) * 2
	var cell_height: int = int(ceil((mature_height + PADDING * 2) / 2.0)) * 2
	return Vector2i(cell_width, cell_height)


## All four stages share one height budget, including the mature image's
## width constraint. A broad mature crown must not be shorter than stage 2.
static func shared_mature_height(sources: Array[Image], tile_size: Vector2i) -> float:
	if sources.size() != 4:
		return -1.0
	var height: float = float(tile_size.y) * MATURE_HEIGHT_RATIO
	var max_width: float = float(maxi(2, int(round(float(tile_size.x) * 0.95))))
	for stage: int in range(4):
		var bounds: Rect2i = _visible_art(sources[stage]).get_used_rect()
		if not bounds.has_area():
			return -1.0
		height = minf(height, max_width * float(bounds.size.y) / float(bounds.size.x))
	return height


## Ignore nearly transparent export residue and isolated tiny specks.
static func _visible_art(source: Image) -> Image:
	var working: Image = source.duplicate() as Image
	working.convert(Image.FORMAT_RGBA8)
	var longest: int = maxi(working.get_width(), working.get_height())
	if longest > 1024:
		var ratio: float = 1024.0 / float(longest)
		working.resize(maxi(1, int(working.get_width() * ratio)), maxi(1, int(working.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var width: int = working.get_width()
	var height: int = working.get_height()
	var data: PackedByteArray = working.get_data()
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(width * height)
	var components: Array[PackedInt32Array] = []
	var largest: int = 0
	for pixel: int in range(width * height):
		if data[pixel * 4 + 3] < 13:
			data[pixel * 4 + 3] = 0
			continue
		if visited[pixel] != 0:
			continue
		var component: PackedInt32Array = PackedInt32Array([pixel])
		visited[pixel] = 1
		var cursor: int = 0
		while cursor < component.size():
			var current: int = component[cursor]
			cursor += 1
			var x: int = current % width
			var y: int = int(current / float(width))
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or nx >= width or ny < 0 or ny >= height:
						continue
					var neighbor: int = ny * width + nx
					if visited[neighbor] == 0 and data[neighbor * 4 + 3] >= 13:
						visited[neighbor] = 1
						component.append(neighbor)
		largest = maxi(largest, component.size())
		components.append(component)
	for component: PackedInt32Array in components:
		if component.size() < maxi(4, int(largest * 0.005)):
			for pixel: int in component:
				data[pixel * 4 + 3] = 0
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


static func root_origin(normalized: Image, cell_width: int = -1) -> Vector2i:
	var target_width: int = cell_width if cell_width > 0 else normalized.get_width()
	var first_cell: Image = normalized.get_region(Rect2i(0, 0, target_width, normalized.get_height()))
	var used: Rect2i = first_cell.get_used_rect()
	return Vector2i(
		used.position.x + int(used.size.x / 2.0) - int(target_width / 2.0),
		used.end.y - int(normalized.get_height() / 2.0)
	)

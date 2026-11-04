@tool
extends RefCounted
## Editor-time image processing. Original PNGs are never changed.

const STAGE_SCALE: Array[float] = [0.35, 0.60, 0.85, 1.0]
const MATURE_HEIGHT_RATIO: float = 2.8
const PADDING: int = 4


static func normalize(source: Image, tile_size: Vector2i, stage: int, shared_height: float = -1.0, artwork_scale: float = 1.0) -> Image:
	if source == null or source.is_empty() or stage < 0 or stage > 3 or tile_size.x < 1 or tile_size.y < 1:
		return null
	var cleaned: Image = _visible_art(source)
	var bounds: Rect2i = cleaned.get_used_rect()
	if not bounds.has_area():
		return null
	var trimmed: Image = cleaned.get_region(bounds)
	trimmed.convert(Image.FORMAT_RGBA8)
	var max_width: int = maxi(2, int(round(float(tile_size.x) * 0.95)))
	var mature_height: float = float(tile_size.y) * MATURE_HEIGHT_RATIO
	var target_height: float = minf(mature_height, shared_height) if shared_height > 0.0 else mature_height
	# Fit into the mature envelope FIRST, then apply the stage multiplier to
	# both dimensions. Trimming or a width limit must not cancel stage scaling.
	var scale_factor: float = minf(float(max_width) / bounds.size.x, target_height / bounds.size.y) * STAGE_SCALE[stage] * artwork_scale
	# Even dimensions allow exact integer bottom-center anchoring in TileData.
	var width: int = maxi(2, int(floor(float(bounds.size.x) * scale_factor / 2.0)) * 2)
	var height: int = maxi(2, int(floor(float(bounds.size.y) * scale_factor / 2.0)) * 2)
	trimmed.resize(width, height, Image.INTERPOLATE_LANCZOS)
	var resized_bounds: Rect2i = trimmed.get_used_rect()
	if not resized_bounds.has_area():
		return null
	# Fixed, even canvas for all stages; only artwork changes size.
	var canvas_width: int = int(ceil(float(max_width + PADDING * 2) / 2.0)) * 2
	var canvas_height: int = int(ceil((mature_height + PADDING * 2) / 2.0)) * 2
	var canvas: Image = Image.create(canvas_width, canvas_height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var destination: Vector2i = Vector2i(
		int(canvas_width / 2.0) - int(resized_bounds.size.x / 2.0),
		canvas_height - PADDING - resized_bounds.size.y
	)
	canvas.blit_rect(trimmed, resized_bounds, destination)
	return canvas


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


## Ignore nearly transparent export residue and isolated tiny specks. These
## otherwise make get_used_rect include empty space below the actual roots.
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


static func root_origin(normalized: Image) -> Vector2i:
	var used: Rect2i = normalized.get_used_rect()
	# Draw position = cell center - texture_size/2 - texture_origin.
	# Therefore this places the visible bottom-center exactly at cell center
	# (within half a pixel for an odd visible width).
	return Vector2i(
		used.position.x + int(used.size.x / 2.0) - int(normalized.get_width() / 2.0),
		used.end.y - int(normalized.get_height() / 2.0)
	)

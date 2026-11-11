@tool
class_name FenceVisual
extends Resource
## Rendering identifiers for the 16-tile fence atlas. Logic and Data never see it.
## The map layer and the HUD button icon both read this one resource.
## Each entry in tile_mapping is [source_id, atlas_coords, alternative_tile] keyed by
## the 4-bit connection mask (0–15). Mask 0 is the isolated post tile, used as the HUD icon.

## Legacy single-tile fields kept for backwards compatibility with existing scenes;
## they are unused once tile_mapping is populated.
@export var source_id: int = -1
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0

## 16-entry mask→tile mapping. Key: int mask 0–15. Value: Array [source_id, atlas_coords, alternative].
## Populated by setup_fence_tool.gd; empty means autotiling is not yet configured.
@export var tile_mapping: Dictionary = {}


## Returns the [source_id, atlas_coords, alternative_tile] array for the given mask,
## or null when the mapping is absent. Null-safe.
func get_tile_for_mask(mask: int) -> Array:
	var key: int = mask & 0xF
	if tile_mapping.has(key):
		return tile_mapping[key] as Array
	return []


## Reports missing source, non-atlas source, or missing tile/alternative for every mask entry.
## Falls back to validating the legacy single-tile fields when tile_mapping is empty.
## When tile_mapping is populated, also checks that source_id is valid (if not -1).
func validate(tile_set: TileSet) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if tile_set == null:
		errors.append("FenceVisual: tile_set is required.")
		return errors
	if tile_mapping.is_empty():
		# Legacy path: validate the single tile.
		return _validate_single(tile_set)
	# When mapping is populated, also validate the legacy source_id if set.
	if source_id >= 0 and not tile_set.has_source(source_id):
		errors.append("FenceVisual: source %d is not registered." % source_id)
		return errors
	for raw_key: Variant in tile_mapping.keys():
		var key: int = int(raw_key)
		if key < 0 or key > 15:
			errors.append("FenceVisual: mapping key %d is out of range [0,15]." % key)
			continue
		var entry: Array = tile_mapping[raw_key] as Array
		if entry == null or entry.size() < 3:
			errors.append("FenceVisual: mapping[%d] must be [source_id, atlas_coords, alternative]." % key)
			continue
		var sid: int = int(entry[0])
		var coords: Vector2i = entry[1] as Vector2i
		var alt: int = int(entry[2])
		if not tile_set.has_source(sid):
			errors.append("FenceVisual: mapping[%d]: source %d not registered." % [key, sid])
			continue
		var source: TileSetAtlasSource = tile_set.get_source(sid) as TileSetAtlasSource
		if source == null:
			errors.append("FenceVisual: mapping[%d]: source %d is not an atlas." % [key, sid])
			continue
		if not source.has_tile(coords):
			errors.append("FenceVisual: mapping[%d]: atlas tile %s is missing." % [key, str(coords)])
			continue
		if source.get_alternative_tiles_count(coords) <= alt:
			errors.append("FenceVisual: mapping[%d]: alternative %d missing for tile %s." % [key, alt, str(coords)])
	if tile_mapping.size() < 16:
		errors.append("FenceVisual: tile_mapping has %d entries; 16 required (masks 0–15)." % tile_mapping.size())
	return errors


## Cuts an AtlasTexture for mask 0 (post). Falls back to legacy atlas_coords when mapping absent.
func make_icon(tile_set: TileSet) -> Texture2D:
	if tile_set == null:
		return null
	if tile_mapping.is_empty():
		return _make_icon_legacy(tile_set)
	var entry: Array = get_tile_for_mask(0)
	if entry.is_empty():
		return null
	var sid: int = int(entry[0])
	var coords: Vector2i = entry[1] as Vector2i
	if not tile_set.has_source(sid):
		return null
	var source: TileSetAtlasSource = tile_set.get_source(sid) as TileSetAtlasSource
	if source == null or not source.has_tile(coords):
		return null
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = source.texture
	icon.region = source.get_tile_texture_region(coords)
	return icon


## Legacy single-tile validate.
func _validate_single(tile_set: TileSet) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not tile_set.has_source(source_id):
		errors.append("FenceVisual: source %d is not registered." % source_id)
		return errors
	var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		errors.append("FenceVisual: source %d is not an atlas." % source_id)
		return errors
	if not source.has_tile(atlas_coords):
		errors.append("FenceVisual: atlas tile %s is missing." % str(atlas_coords))
		return errors
	if source.get_alternative_tiles_count(atlas_coords) <= alternative_tile:
		errors.append("FenceVisual: alternative %d is missing for tile %s." % [alternative_tile, str(atlas_coords)])
	return errors


## Legacy make_icon path.
func _make_icon_legacy(tile_set: TileSet) -> Texture2D:
	if not tile_set.has_source(source_id):
		return null
	var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or not source.has_tile(atlas_coords):
		return null
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = source.texture
	icon.region = source.get_tile_texture_region(atlas_coords)
	return icon

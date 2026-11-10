@tool
class_name FenceVisual
extends Resource
## Rendering identifiers for the single fence atlas tile. Logic and Data never see it.
## The map layer and the HUD button icon both read this one resource.

@export var source_id: int = -1
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0


## Reports missing source, non-atlas source, or missing tile/alternative.
func validate(tile_set: TileSet) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if tile_set == null:
		errors.append("FenceVisual: tile_set is required.")
		return errors
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


## Cuts an AtlasTexture from the same atlas region as the map tile.
func make_icon(tile_set: TileSet) -> Texture2D:
	if tile_set == null or not tile_set.has_source(source_id):
		return null
	var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or not source.has_tile(atlas_coords):
		return null
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = source.texture
	icon.region = source.get_tile_texture_region(atlas_coords)
	return icon

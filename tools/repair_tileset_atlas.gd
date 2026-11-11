@tool
extends EditorScript
## One-time repair for the external terrain TileSet used by World/Terrain,
## BackgroundTerrain, Foliage, and GrassOverlayLayer in field_prototype.tscn.
## Run via the test_harness plugin in EDITOR headless mode (see plugin.gd,
## GODOT_TILESET_REPAIR), not via --script, so the editor's resource saver
## preserves the .tres UID. Uses serialization only; never hand-edits the .tres.
##
## Problem: the saved tile_set.tres serializes atlas tiles at coords Godot
## rejects at load ("Cannot create tile...outside the texture"). Those rejected
## entries survive as non-enumerable "zombie" data: get_tile_id() does not list
## them, so a plain resave writes them back unchanged. They print ERROR at every
## load, failing any test that loads the scene.
##
## Fix: rebuild each TileSetAtlasSource fresh and copy only the enumerable
## (valid) tiles plus their properties (texture_origin and the layer-0 occluder
## — the only per-tile properties this file uses). Zombies drop because they are
## never enumerated. Source ids are preserved (remove + add back with the same
## id). Tile data is snapshotted first; the fresh source is attached to the
## TileSet before tiles are created so each fresh TileData allocates the
## TileSet's occluder layer(s) and set_occluder(0) stays in bounds.

const TILESET_PATH: String = "res://assets/art/tilesets/terrain/resource/tile_set.tres"


func _run() -> void:
	await run_setup()


func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	for frame: int in range(10):
		await tree.process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame

	var uid_before: int = ResourceLoader.get_resource_uid(TILESET_PATH)
	var tile_set: TileSet = ResourceLoader.load(TILESET_PATH, "TileSet") as TileSet
	if tile_set == null:
		push_error("repair_tileset_atlas: could not load TileSet at " + TILESET_PATH)
		return 1
	var rebuilt: int = 0
	var tiles_kept: int = 0
	for i: int in range(tile_set.get_source_count()):
		var source_id: int = tile_set.get_source_id(i)
		var atlas: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas == null:
			continue
		# Snapshot the enumerable (valid) tiles and their data before rebuilding.
		var infos: Array = []
		for t: int in range(atlas.get_tiles_count()):
			var coord: Vector2i = atlas.get_tile_id(t)
			var base: TileData = atlas.get_tile_data(coord, 0)
			var info: Dictionary = {
				"coord": coord,
				"origin": base.texture_origin if base != null else Vector2i.ZERO,
				"occ": base.get_occluder(0) if base != null else null,
				"alts": [],
			}
			for a: int in range(atlas.get_alternative_tiles_count(coord)):
				var alt_id: int = atlas.get_alternative_tile_id(coord, a)
				if alt_id == 0:
					continue
				var ad: TileData = atlas.get_tile_data(coord, alt_id)
				(info["alts"] as Array).append({
					"alt_id": alt_id,
					"origin": ad.texture_origin if ad != null else Vector2i.ZERO,
					"occ": ad.get_occluder(0) if ad != null else null,
				})
			infos.append(info)
		# Build a fresh source and attach it to the TileSet before creating tiles.
		var fresh: TileSetAtlasSource = TileSetAtlasSource.new()
		fresh.resource_name = atlas.resource_name
		fresh.texture = atlas.texture
		fresh.texture_region_size = atlas.texture_region_size
		tile_set.remove_source(source_id)
		tile_set.add_source(fresh, source_id)
		for info: Dictionary in infos:
			var coord: Vector2i = info["coord"]
			fresh.create_tile(coord)
			if not fresh.has_tile(coord):
				push_error("repair_tileset_atlas: could not recreate tile %s on source %d" % [str(coord), source_id])
				continue
			var d: TileData = fresh.get_tile_data(coord, 0)
			if d != null:
				d.texture_origin = info["origin"]
				var occ: OccluderPolygon2D = info["occ"]
				if occ != null:
					d.set_occluder(0, occ)
			for alt: Dictionary in info["alts"]:
				var alt_id: int = alt["alt_id"]
				fresh.create_alternative_tile(coord, alt_id)
				var ad: TileData = fresh.get_tile_data(coord, alt_id)
				if ad != null:
					ad.texture_origin = alt["origin"]
					var aocc: OccluderPolygon2D = alt["occ"]
					if aocc != null:
						ad.set_occluder(0, aocc)
			tiles_kept += 1
		print("source %d (%s): kept %d tile(s)" % [source_id, atlas.resource_name, infos.size()])
		rebuilt += 1
	var err: Error = ResourceSaver.save(tile_set, TILESET_PATH)
	if err != OK:
		push_error("repair_tileset_atlas: ResourceSaver failed with error %d" % err)
		return 1
	EditorInterface.get_resource_filesystem().scan()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	var uid_after: int = ResourceLoader.get_resource_uid(TILESET_PATH)
	if uid_after != uid_before:
		push_error("repair_tileset_atlas: TileSet UID changed %d -> %d" % [uid_before, uid_after])
		return 1
	print("repair_tileset_atlas: rebuilt %d source(s), kept %d valid tile(s); re-saved %s (uid preserved)" % [rebuilt, tiles_kept, TILESET_PATH])
	return 0

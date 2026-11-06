# Editing background scenery

**Current saved setup:** the playable field and editor preview are **9×9**. Automatic grass generation is disabled, including the editor backdrop preview. Paint your surroundings on `BackgroundTerrain` and `BackgroundDecorations`, leaving logical coordinates **X 0–8 / Y 0–8** clear for the playable field. Keep `TerrainPreview → Preview Enabled` on to see the field while designing. Unpainted surroundings show the viewport background color.

The unused `AutomaticGrassBackground` node has been removed from the manual scene. Under `World`, the two authored layers and `TerrainPreview` are listed first. Inspector node descriptions identify editing layers versus runtime-generated nodes. Optional automatic-fill code remains available for separately configured scenes, but requires an assigned generated TileMapLayer.

Reload `field_prototype.tscn` in Godot after this update. Under `World`:

| Node | Purpose | Editing |
|---|---|---|
| `BackgroundTerrain` | Your grass, paths, water and other ground designs | Paint tiles in the editor |
| `BackgroundDecorations` | Your trees, fences, rocks, buildings and other scenery | Paint tiles or add Sprite2D / scene children |
| `Terrain` | Runtime-generated playable farm plots | Configure through FarmingController; manual tiles are replaced |

## Paint ground scenery

1. Select `World/BackgroundTerrain` in the Scene tree.
2. Use the TileMap painting panel to choose a tile and paint around the playable field preview.
3. To add artwork, select this layer's TileSet and add an atlas source using your texture. Configure its tile regions and texture origin, then paint those tiles.
4. Save the scene with Ctrl+S and run the game to check the result.

Both editable layers start empty and have independent copies of the existing terrain TileSet. Their starting tiles are available immediately. Editing these TileSet definitions does not modify the playable terrain definitions. Texture image files themselves are still shared assets; editing an image file changes every place using that image.

## Place decorations

Select `World/BackgroundDecorations` to paint decorative tiles. For standalone images or reusable scenes, add Sprite2D children or instantiate scenes under it, assign textures, and position them in the 2D editor. For tall props, align their origin to the ground contact point and enable Y sorting within any nested scene that needs it.

Automatic grass, authored ground and playable terrain share the same Z index and Y sorting. This allows foreground ground tiles to cover the soil side faces of tiles behind them, so thick tiles form continuous ground instead of a raised floating island. Automatic grass skips coordinates covered by authored ground. Decorative props share the crop/farmer tier above ground; crop shadows remain below that tier and selection highlights above it. Paintable background positions never become farming targets.

When explicitly enabled, automatic grass fills unpainted surroundings during gameplay. Its optional editor preview uses transient tiles that are never serialized. **Background Preview Padding** controls that editor border (default ten tiles). The playable preview follows field size and terrain configuration independently of automatic filling. No new art is painted automatically into the editable layers.

## Preservation and verification

`FieldWorldView` only clears and repaints the playable Terrain and AutomaticGrassBackground. Framing, resizing, crop actions, terrain conversions and turns leave the two editable scenery layers and their children untouched. Automatic background geometry follows the existing camera overview footprint and does not affect camera bounds or the farming simulation.

`tools/setup_field_tools.gd` creates missing layers and saves them through Godot Editor APIs. Existing background tiles, TileSets, transforms and children are preserved on reruns.

The background-layer regression test passes, including preservation through refresh/reframe and a Godot save/reload round trip, independent TileSets, logical-grid isolation, and protection against assigning an authored layer as the automatic fill target. Both camera regression tests also pass. The full runner now includes eighteen tests; these targeted results do not replace the previously documented full-suite limitations or physical mobile testing.

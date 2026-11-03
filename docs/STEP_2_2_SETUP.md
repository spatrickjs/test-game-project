# Step 2.2 setup

## Image measurements

Files inspected: assets/art/tilesets/terrain/dry_soil.png.png,
grass.png.png, and paddy_mud.png.png. Each source is 3500 x 3500.

The inspected import sidecars currently contain process/size_limit=0.
Set Process > Size Limit to 512 and click Reimport for each texture.
The values below assume a 512 x 512 imported texture, not the full source.

| Setting | Dry soil | Paddy mud | Grass |
| --- | --- | --- | --- |
| Shared TileSet tile_size | (276, 140) | (276, 140) | (276, 140) |
| Atlas texture_region_size | (512, 512) | (512, 512) | (512, 512) |
| TileData texture_origin | (4, -14) | (4, -14) | (4, -14) |
| atlas_coords | (0, 0) | (0, 0) | (0, 0) |
| alternative_tile | 0 | 0 | 0 |

Use each source's actual source ID; these IDs are not inferred from filenames.
Set Tile Shape to Isometric and Tile Layout to Diamond Right.
Create one tile per atlas source, not many small slices.

These are fitted integer grid settings, not proof of exact seamless artwork.
At 512 resolution, alpha scanlines at y=242 span x=122..398 in all
three images (threshold 128/255, longest contiguous run).
The dry/mud upper tips begin near y=172; grass blades protrude near y=168.
The ground's front corner is visually near y=312, whereas the bottom
of the raised soil block is near y=336. Do not use the full block height
or the grass overhang as the ground footprint.

The nominal fitted diamond uses corners (260,172), (398,242),
(260,312), (122,242). Its center is (260,242), so the origin relative
to the 512-square texture center is (260,242)-(256,256)=(4,-14).
Actual drawn corners and edges are slightly asymmetric and irregular.
Filtering can also shift partially transparent boundaries by a pixel.
Exact seamless tiling would require artwork normalization; no original PNGs
were modified. Raised side faces and stray edge pixels may remain visible.

## Scene tree and script attachments

Build this visually; no raw scene or resource text is required.

```text
FieldPrototype (Node) — field_prototype_presenter.gd
  FarmingController (Node) — farming_controller.gd
  TurnController (Node) — turn_controller.gd
  World (Node2D) — field_world_view.gd
	Terrain (TileMapLayer)
	CropOverlay (Node2D) — crop_debug_overlay.gd
	Camera2D (Camera2D)
  HUD (CanvasLayer)
	Panel (PanelContainer)
	  Margin (MarginContainer)
		Controls (VBoxContainer)
		  TurnLabel (Label)
		  SelectedCropLabel (Label)
		  CropButtons (HBoxContainer)
			SugarcaneButton (Button)
			RiceButton (Button)
			CornButton (Button)
		  NextTurnButton (Button)
		  StatusLabel (Label)
```

Save through Godot as res://src/presentation/world/field_prototype.tscn.
Keep World, Terrain, CropOverlay and Camera2D transforms unrotated with
unit scale; Camera2D zoom is calculated by the view.
Place the HUD panel at the top left, with width about 360 pixels.
Give StatusLabel sufficient width to wrap. The default camera reserves
180 viewport pixels at the top; increase World.hud_reserved_height if needed.
Run the current scene with F6.

## Inspector assignments

| Node | Export | Assign |
| --- | --- | --- |
| FieldPrototype | farming_controller | FarmingController |
| FieldPrototype | turn_controller | TurnController |
| FieldPrototype | world_view | World |
| FieldPrototype | hud_panel | HUD/Panel |
| FieldPrototype | turn_label, selected_crop_label, status_label | Matching Label nodes |
| FieldPrototype | sugarcane_button, rice_button, corn_button, next_turn_button | Matching Button nodes |
| FarmingController | crop_database | CropDatabase containing three CropData definitions |
| FarmingController | terrain_database | TerrainDatabase containing three TerrainData definitions |
| FarmingController | initial_soil | A valid SoilState; it is copied per plantable cell |
| FarmingController | initial_abiotic | A valid AbioticState |
| TurnController | farming_controller | FarmingController |
| World | terrain_layer | World/Terrain |
| World | crop_overlay | World/CropOverlay |
| World | camera | World/Camera2D |
| World | visual_map | TerrainTileVisualMap containing three TerrainTileVisual entries |
| CropOverlay | terrain_layer | World/Terrain |
| Terrain | tile_set | Your Editor-authored isometric TileSet |

Create Resource instances through the Inspector. The definition scripts alone
do not populate catalogs. Give every crop and terrain a nonblank display_name.
For a visible growth demonstration, set each crop growth_ticks to 3 or more;
these are prototype settings, not research-calibrated growth durations.

Terrain configuration:
- DRY_SOIL: is_plantable=true; allowed_crops=[SUGARCANE, CORN].
- PADDY_MUD: is_plantable=true; allowed_crops=[RICE].
- GRASS: is_plantable=false; allowed_crops=[].

Each visual entry sets terrain_type plus the actual TileSet source_id,
atlas_coords=(0,0), and alternative_tile=0. Default source_id=-1 is invalid
until assigned. Texture paths and atlas IDs never enter the Logic Layer.

All signals are connected by the presenter during startup. Do not also
connect them in the Node Signals dock. The presenter initializes the field
after connecting listeners, and reports missing references/configuration.

## Behavior

- Default 9x6 grid: columns 0-2 dry soil, 3-5 paddy mud, 6-8 grass.
- Select a crop, then click/tap a tile. Occupied and incompatible tiles reject
  planting without advancing time or altering state.
- Each Next Turn advances growth once, capped at growth_ticks.
- SC/RI/CO abbreviations identify crops. Gold indicates maturity.
- No harvesting, disease progression, automatic clock, pan, or pinch zoom.
- Rendering uses detached snapshots. Growth batches refresh once per turn.
- Native mouse/touch is handled in _unhandled_input; emulated duplicates
  are ignored. HUD buttons consume input.

## Verification

Godot --check-only completed with exit code 0 for all seven scripts.
tests/logic/field_prototype_smoke.gd produced FIELD_PROTOTYPE_SMOKE_PASS,
covering layout, planting restrictions, snapshot independence, turn count,
growth cap, maturity, and missing-TileSet validation.
The environment still emits a log-file creation error. Captured process
output confirms the smoke test actually ran; logging is separate.
Scene rendering and physical-device touch still require Editor/device checks.

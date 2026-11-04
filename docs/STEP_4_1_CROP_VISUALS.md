# Step 4.1: static crop growth visuals

Implemented 2026-11-04. Rice, corn, and sugarcane each have four separate
TileSet atlas sources on the persistent `World/Crops` TileMapLayer.

## Stage contract

`CropData.growth_ticks` is the existing duration; no second duration is added.
For positive duration, Presentation uses the approved mapping:

| Progress | Stage |
| --- | --- |
| 0 <= progress < 1/3 | 0: Seedling |
| 1/3 <= progress < 2/3 | 1: Vegetative |
| 2/3 <= progress < 1 | 2: Reproductive |
| elapsed >= growth_ticks | 3: Mature |

New plants show Seedling immediately. Short durations can skip intermediate
stages. Rice's four-tick duration displays stages `0, 0, 1, 2, 3` from planting
through maturity; corn and sugarcane's five-tick duration displays
`0, 0, 1, 1, 2, 3`. Artwork never advances logical growth.

## Boundaries and authoring

The approved exception places `growth_stage_source_ids: Array[int]` and
`growth_stage_atlas_coords: Array[Vector2i]` on CropData. Both default to four
entries and are independently duplicated by `copy()`. These are Presentation
metadata; Data's gameplay validation, Game Logic and Simulation do not interpret
them. FieldWorldView validates four entries, source existence, and atlas tiles.
Unconfigured definitions default to source ID -1 and remain usable for pure
logic/simulation tests. A scene with an assigned crop layer requires valid visual
mappings for its catalog.

The Presenter already refreshes detached snapshots after planting, clearing and
completed turns. FieldWorldView paints the crop layer and clears obsolete tiles.
It never modifies authoritative crop state. Scenes without a crop layer retain
the earlier debug overlay path. In the saved prototype that overlay is hidden;
it can be enabled in the Editor for debugging.

`tools/setup_crop_growth_visuals.gd` is an EditorScript. Open the prototype,
open the script, and run it with Ctrl+Shift+X. It **saves** the scene and three
crop resources through Godot APIs, preserving the scene UID. It is not an Undo
operation. It refuses an unrelated node named World/Crops and reuses generated
sources on subsequent runs. No runtime asset loads were introduced.

The setup now reads original PNG bytes and delegates image processing to
`tools/crop_texture_normalizer.gd`; it does not rely on the old 256px imports.
Original PNGs remain unchanged. Derived, compressed Godot ImageTexture `.res`
files live in `assets/art/tilesets/crops/normalized/` and are registered with the
editor filesystem before saving scene references. Include these generated
resources when transferring/exporting the project. Existing atlas source IDs
are retained by matching their resource names.

Normalization works on an RGBA image capped at 1024 pixels on its longest side.
It removes alpha below 13/255 and disconnected islands smaller than 0.5% of the
largest connected component (minimum four pixels). This eliminates faint export
residue and the isolated fragment below Sugarcane Stage 2 that otherwise expands
`get_used_rect()` and makes the roots float. The resulting visible bounds are
trimmed and proportionally resized with Lanczos filtering.

All four images of each crop share one mature-height budget, limited by 2.8 times
tile height and the broadest image fitting within 95% of tile width. This avoids
a broad mature crown becoming shorter than a narrow earlier stage. Each trimmed
image fits that shared height, preserving its aspect ratio. A final stage multiplier
of 35%, 60%, 85% or 100% is then applied to BOTH dimensions. Applying the
multiplier after fitting prevents width limits or trimming from undoing the
smaller seedling scale. Saved textures are checked for increasing stage heights
and ratios relative to their own crop's mature height. All stages share a
270 x 400 transparent canvas for the current 276 x 140 terrain tiles. The
visible base sits four pixels above the canvas bottom. TileData.texture_origin
is derived from the final visible bottom-center minus half the canvas size, so
the base draws at the exact logical tile center (at most half a pixel of
horizontal quantization for odd visible widths). The former +14 offset is gone.
Re-running setup regenerates these visual settings; edit the normalizer constants
to make persistent scale changes.

The dedicated TileSet copies the terrain's isometric geometry; crop and terrain
layers share the same transform, with crops above terrain and Y-sorted.

Corn and Sugarcane Stage 0 have an additional 0.5 artwork multiplier in setup.
It halves both drawn dimensions via Image.resize before canvas placement, giving
those seedlings approximately 17.5% of mature height. Rice retains 35%; stages
1-3 retain their existing sizes. The 270 x 400 canvas remains unchanged and the
texture origin is recomputed from the final visible root bounds.

Headless setup uses the normal editor lifecycle:

```powershell
$env:GODOT_CROP_VISUAL_SETUP = '1'
# Run Godot --headless --editor --path <project>, with an absolute --log-file.
# Clear the flag before normal editor use.
Remove-Item Env:GODOT_CROP_VISUAL_SETUP
```

The strict runner strips this setup flag from test environments.

## Verification

`python tools/run_tests.py --godot <godot-executable>` now runs nine tests (including the subsequent Step 4.2 field-management test).
The added `tests/presentation/crop_growth_visuals_test.gd` covers exact third
boundaries, 100%-only maturity, one-tick duration, invalid duration fallback,
serialized ownership and all twelve sources, planting and Next Turn rendering,
independent copies, invalid mappings, and clearing stale crop tiles.
It also tests padding/speck-independent normalization, empty-image rejection,
consistent canvas sizes, readable artwork bounds and bottom-center root alignment
for all twelve saved atlas textures.

For rendered QA, run that script without `--headless`, passing `-- --capture`.
It captures planting and turns 1-5 to `.godot/crop_visual_*.png` without saving
playtest changes to the scene or resources. The D3D12 Mobile rendered run passed.
Existing integration tests cover UI click routing, inspector refresh and closure.

# Scenery shadows

Configured 2026-11-07. Presentation only; no collision, navigation or simulation changes.

- `World/Lighting/SoftLight` casts shadows with PCF5 filtering, Filter Smooth 1.5, and occluder mask layer 2. Adjust its Shadow Color alpha for strength, Energy for light contribution, and Position for shadow direction. Shadows are deliberately subtle under the ambient and sunlight fill.
- `Sunlight` stays unshadowed. Godot's directional 2D shadows extend infinitely; the point light limits the effect to its texture footprint.
- Four existing `foliage` atlas tiles and the existing `tree` atlas tile have simplified, at-most-eight-vertex occluders in TileSet occlusion layer 0 (light mask 2). Painting additional copies automatically uses those polygons.
- New artwork needs an occluder in the TileSet editor. Edit polygons under Occlusion Layer 0, following the artwork, including its texture origin. These are light occluders, not physics polygons. Animated tiles currently use a static outline.
- `tools/setup_scenery_shadows.gd` can be run as an EditorScript to generate missing base-tile polygons for atlas sources named `foliage` or `tree`. It preserves existing polygons, but reapplies the default light settings. Other source names and alternative tiles require manual configuration. Fence, terrain and crop sources are intentionally excluded.

Verified scene save and desktop OpenGL rendering without engine errors. Mobile performance has not been measured.

# Design

TileInspectorView owns configurable width, height, tile gap, screen margin, and opening duration. The presenter converts the selected tile and visible HUD controls into inspector canvas coordinates each frame. A pure placement calculation compares available sides and obstacle overlap, with a bottom panel fallback.

A shared inspector theme styles existing authored controls at runtime. ProgressBar retains the exact snapshot value while an input-transparent child animates its fill. Existing exported references and gameplay data ownership remain in place.

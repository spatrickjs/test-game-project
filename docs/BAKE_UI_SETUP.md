# Persistent field UI

1. Stop playtesting and open `field_prototype.tscn` as the active scene.
2. Open `res://tools/bake_ui_to_scene.gd` in the Script Editor (do not attach it to a node).
3. Run the EditorScript with File > Run / Ctrl+Shift+X.
4. Save the scene with Ctrl+S. Ownership and exported references are serialized by Godot.
5. Edit `HUD/Panel` and `HUD/TileInspectorPanel` in the local Scene Tree and 2D viewport.

The baker creates missing controls, repairs ownership on its expected hierarchy, wires the presenter and inspector exports, and shows the inspector for editing. Existing positions, sizes, themes, and nonempty captions are preserved. Reruns reuse nodes; the operation supports Undo/Redo. Nested scene children and incompatible node types are rejected instead of overwritten. Optional DiseaseDatabase and existing Logic/World references are preserved.

The legacy inspector builder delegates to this complete baker.

Runtime scripts only connect signals, manage interaction state, and update displayed data. The inspector hides at game startup and opens when a cell is inspected. Layout, wrapping, minimum sizes, and themes are authored on the scene controls. Containers still arrange their children normally: change container settings and child size flags rather than dragging container-managed children.

The current saved HUD panel has a large authored rectangle. Resize/reanchor it in the Editor to the desired footprint; runtime no longer shrinks it. For responsive screens, configure anchors and offsets on both top-level panels. Progress bars should keep a 0–100 range because displayed values are percentages.

The script intentionally leaves saving to Ctrl+S so existing unsaved scene edits remain reviewable. No raw `.tscn` or `.tres` text is written.

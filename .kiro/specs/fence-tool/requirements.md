# Requirements Document

## Introduction

The Fence Treatment Method lets the player fence off a field tile to contain vector-borne disease spread. A fenced tile is converted to grass with no soil and carries a fence object. It cannot host crops or be planted. The Shovel destroys the fence.

Fencing is a queued farmer action, like Plant, Shovel, Harvest and Water Bucket. It takes effect when the farmer arrives, does not advance the turn, and follows the project's four-layer architecture (Data, Simulation, Logic, Presentation).

Behavioral scenarios are in `fence_treatment.feature` (same folder).

## Glossary

- **Fence**: a per-tile object stored as `FieldCellState.has_fence`.
- **Fenced_Tile**: a cell with `has_fence == true`.
- **Fence_Tool**: HUD toggle button that sets presenter mode `TOOL_FENCE`.
- **Shovel**: existing HUD tool (`TOOL_REMOVE`).
- **Farmer**: `FarmerAgent`; arrival commits a queued action.
- **FarmingController**: Logic node that owns mutable field state.
- **Field_Action**: `FieldAction` task description queued in `FarmingController`.

## Requirements

### Requirement 1: Queue a fence action

**User Story:** As a player, I want to select tiles with the Fence tool, so that the farmer builds fences there.

#### Acceptance Criteria

1. WHEN the player selects the Fence_Tool, THE Presenter SHALL enter `TOOL_FENCE` mode, clear any plant or inspect selection, and show eligible tiles highlighted.
2. WHEN the player clicks or drag-selects tiles in `TOOL_FENCE` mode, THE FarmingController SHALL enqueue one `FENCE` Field_Action per eligible tile.
3. THE FarmingController SHALL accept a `FENCE` action on any empty in-field tile that is not already fenced and has no queued action. This covers empty dry soil, paddy mud, and grass. Planted tiles are rejected regardless of crop disease status.
4. IF the target is outside the field, THEN THE FarmingController SHALL reject the action with "Choose a tile inside the field."
5. IF the target is already reserved by a queued action, THEN THE FarmingController SHALL reject the action with "This plot already has a queued action."
6. IF the target is already fenced, THEN THE FarmingController SHALL reject the action.
7. WHEN a `FENCE` action is enqueued, THE FarmingController SHALL NOT change any cell state.
8. WHILE a fence action is queued, THE Presenter SHALL show the tile as queued and block End Turn.

### Requirement 2: Fence an empty tile

**User Story:** As a player, I want to fence an empty tile, so that it is removed from the playable crop area.

#### Acceptance Criteria

1. WHEN the farmer arrives at a queued `FENCE` target that is an empty tile, THE FarmingController SHALL set `has_fence` to true, set terrain to `GRASS`, and set soil to null.
2. THE FarmingController SHALL emit `cell_changed` once for that tile after the change is committed.
3. THE FarmingController SHALL emit `action_finished` with `success == true`.

### Requirement 3: Reject occupied tiles

Fencing must not destroy planted crops.

1. Reject FENCE on any tile with a crop with "Remove or harvest the crop before placing a fence."
2. Preserve crop, disease, soil, terrain, and score; do not enqueue the rejected action.
3. Revalidate at arrival and cancel if the target has become occupied.

### Requirement 4: Fenced tile invariants

**User Story:** As a developer, I want fenced cells to always be valid, so that other systems can rely on them.

#### Acceptance Criteria

1. THE FieldCellState SHALL store `has_fence`, defaulting to false.
2. THE FieldCellState `validate()` SHALL report an error WHEN `has_fence` is true and any of the following hold: terrain is not `GRASS`, soil is not null, `has_crop` is true, `has_active_disease` is true.
3. THE FieldCellState `copy()` SHALL copy `has_fence`.
4. THE FieldGridQueries `validate_terrain_assignments()` SHALL report an error for a fenced cell on non-grass terrain.
5. THE `reset_crop_state()` method SHALL NOT change `has_fence`.
6. THE value of `FieldActionKind.FENCE` SHALL be 8 and `REMOVE_FENCE` SHALL be 9. Existing enum values SHALL be unchanged.

### Requirement 5: Fenced tile restrictions

**User Story:** As a player, I want fenced tiles to be unusable for farming, so that fences have a cost.

#### Acceptance Criteria

1. IF a plant, move-crop destination, water-bucket, or dig action targets a Fenced_Tile, THEN THE FarmingController SHALL reject it.
2. IF a water or fertilize action targets a Fenced_Tile, THEN THE FarmingController SHALL reject it with "Choose a tile with soil."
3. IF a harvest or remove-crop action targets a Fenced_Tile, THEN THE FarmingController SHALL reject it.
4. WHEN a rejected action is attempted, THE FarmingController SHALL leave all cell state unchanged and set `last_error`.
5. IF an action's target changes while the farmer is walking, THEN THE FarmingController SHALL cancel it with "The plot changed while the farmer was walking; action cancelled."

### Requirement 6: Destroy a fence with the Shovel

**User Story:** As a player, I want to remove a fence with the Shovel, so that I can reuse the tile.

#### Acceptance Criteria

1. WHEN the Shovel is active and the player selects a Fenced_Tile, THE Presenter SHALL create a `REMOVE_FENCE` action.
2. WHEN the farmer arrives at a queued `REMOVE_FENCE` target, THE FarmingController SHALL set `has_fence` to false and leave terrain `GRASS` and soil null.
3. THE FarmingController SHALL accept `REMOVE_FENCE` only for a Fenced_Tile.
4. WHEN a fence has been destroyed, THE FarmingController SHALL accept `DIG_GRASS` on that tile and produce dry soil with soil copied from `initial_soil`.
5. WHEN a Shovel drag starts on a Fenced_Tile, THE FieldWorldView SHALL select only tiles with the same action kind, so crop and grass tiles are not selected.
6. THE FarmingController SHALL emit `cell_changed` once after `REMOVE_FENCE` commits.

### Requirement 7: Disease containment

**User Story:** As a player, I want fences to stop disease from using fenced tiles, so that I can protect other crops.

#### Acceptance Criteria

1. THE SimulationController SHALL NOT treat a Fenced_Tile as a host. It SHALL NOT receive infection or compartment changes.
2. THE SimulationController SHALL NOT count a Fenced_Tile as a source of disease pressure for neighbors.
3. WHEN a crop with an active disease is fenced, THE FarmingController SHALL clear the active disease identity, so `validate_turn` reports no errors from that tile.
4. THE DiseaseActivationController SHALL NOT select a Fenced_Tile for an automatic introduction.
5. THE Seed Infection action SHALL be unavailable for a Fenced_Tile.
6. THE fence SHALL NOT change dispersal geometry. `GridNeighborhood` SHALL be unchanged.

### Requirement 8: Time and transactions

**User Story:** As a player, I want fencing to be free of time cost and safe against errors, so that the game stays consistent.

#### Acceptance Criteria

1. THE FarmingController SHALL NOT advance the turn index or the weather when a fence action commits.
2. THE FarmingController SHALL build the new state on a copied grid, validate it, and only then commit.
3. IF validation fails, THEN THE FarmingController SHALL leave state unchanged and return a failure with `last_error` set.
4. WHEN a fenced grid is advanced by `advance_simulated_turn()`, THE FarmingController SHALL keep the fence and the grid SHALL validate without errors.
5. WHEN `cancel_actions()` is called, THE FarmingController SHALL clear queued fence actions without committing them.

### Requirement 9: Presentation

**User Story:** As a player, I want to see fences and their status, so that I know which tiles are blocked.

#### Acceptance Criteria

1. THE FieldFenceOverlay SHALL draw a fence on every Fenced_Tile using terrain-layer geometry and no art assets.
2. THE FieldFenceOverlay SHALL update when the field is rendered or a snapshot is refreshed, and SHALL clear fences on tiles that lose them.
3. THE FieldWorldView SHALL NOT render grass tufts on a Fenced_Tile.
4. THE TileInspectorView SHALL show "Terrain: Grass (fenced)" for a Fenced_Tile.
5. THE HUD SHALL provide a Fence_Tool toggle button wired through the Inspector, with a 44 px minimum height.
6. THE Fence_Tool button SHALL be disabled WHEN the game is not in the PLAYING state.
7. THE Presentation layer SHALL NOT mutate cell state. It SHALL read detached snapshots and send intents only.
8. IF the FieldFenceOverlay is not assigned, THEN THE FieldWorldView SHALL render without fences and without errors.

### Requirement 10: Session lifecycle

**User Story:** As a player, I want a new game to start with no fences.

#### Acceptance Criteria

1. WHEN `initialize_field()` runs, THE FarmingController SHALL create cells with `has_fence == false`.
2. WHEN Play Again is pressed, THE FieldFenceOverlay SHALL show no fences.

### Requirement 11: Architecture and testing

**User Story:** As a developer, I want the feature to follow existing project conventions.

#### Acceptance Criteria

1. THE Data layer SHALL hold only the enum values and the cell field. THE Logic layer SHALL own all fence rules.
2. THE scene wiring SHALL be done by an editor script that uses Godot APIs, not raw `.tscn` edits, and SHALL preserve scene UIDs.
3. THE feature SHALL add headless tests registered in `tools/run_tests.py`, each printing a `_PASS` marker.
4. THE existing test suite SHALL continue to pass.

## Assumptions and Open Questions

- A fence is a tile-level object. It does not block dispersal between other tiles, because `GridNeighborhood` says grass does not obstruct dispersal. Barrier behavior would be a separate requirement.
- Fencing an already-grass tile is allowed. If it should not be, remove that case from Requirement 1.3.
- Fence artwork is procedural for now. A TileSet-based layer can replace it later.

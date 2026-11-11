class_name TreatmentController
extends Resource
## Orchestrates treatment enqueue, preview, and commit through the farmer walker.
## Owns the TreatmentState and references a TreatmentConfig for definitions.
## Extends Resource (not RefCounted) so FieldPrototypePresenter can @export it
## in the Inspector; Resource retains reference-counted ownership semantics.

## Cell classification during preview/commit.
enum Classification { MATCH, MISMATCH, NOOP }

## Per-cell preview result.
class CellPreview:
	var cell: Vector2i = Vector2i.ZERO
	var classification: int = Classification.MATCH

var treatment_config: TreatmentConfig = null
var treatment_state: TreatmentState = TreatmentState.new()
var disease_database: DiseaseDatabase = null
## Available resource budget; -1 = unlimited (no resource system in current game).
var resource_budget: int = -1
var last_error: String = ""


## Maps a FieldActionKind to its treatment_id.
static func kind_to_treatment_id(kind: int) -> StringName:
	match kind:
		SimulationEnums.FieldActionKind.APPLY_FUNGICIDE:
			return &"fungicide"
		SimulationEnums.FieldActionKind.APPLY_BACTERICIDE:
			return &"bactericide"
		SimulationEnums.FieldActionKind.APPLY_PROTECTANT:
			return &"protectant"
		SimulationEnums.FieldActionKind.APPLY_ENHANCER:
			return &"enhancer"
		SimulationEnums.FieldActionKind.APPLY_INSECTICIDE:
			return &"insecticide"
	return &""


## Returns the FieldActionKind for a treatment_id, or -1 if not found.
static func treatment_id_to_kind(treatment_id: StringName) -> int:
	match treatment_id:
		&"fungicide":
			return SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
		&"bactericide":
			return SimulationEnums.FieldActionKind.APPLY_BACTERICIDE
		&"protectant":
			return SimulationEnums.FieldActionKind.APPLY_PROTECTANT
		&"enhancer":
			return SimulationEnums.FieldActionKind.APPLY_ENHANCER
		&"insecticide":
			return SimulationEnums.FieldActionKind.APPLY_INSECTICIDE
	return -1


## Validation for enqueue: checks cooldown, cost, queue cap, bounds.
func can_enqueue(treatment_id: StringName, target: Vector2i, grid: FieldGridState, queued_count: int) -> String:
	if treatment_config == null:
		return "Treatments are not configured."
	var data: TreatmentData = treatment_config.get_data(treatment_id)
	if data == null:
		return "Unknown treatment: %s" % String(treatment_id)
	if not data.validate().is_empty():
		return "Treatment definition is invalid."
	# Cooldown check
	var cd: int = treatment_state.get_cooldown(treatment_id)
	if cd > 0:
		return "%s is on cooldown for %d more turn(s)." % [data.display_name, cd]
	# Cost check
	if resource_budget >= 0 and data.cost > resource_budget:
		return "Not enough resources for %s." % data.display_name
	# Queue cap
	if queued_count >= treatment_config.max_queued_per_turn:
		return "Treatment queue is full (%d/%d)." % [queued_count, treatment_config.max_queued_per_turn]
	# Bounds check
	if grid == null or not grid.is_in_bounds(target):
		return "Choose a tile inside the field."
	return ""


## Classifies a single cell for a treatment.
func classify_cell(data: TreatmentData, cell: FieldCellState) -> int:
	if cell == null or not cell.has_crop:
		return Classification.NOOP
	# Insecticide: requires vector-borne disease
	if data.requires_vector_borne:
		if not cell.has_active_disease:
			return Classification.NOOP
		var disease: DiseaseData = _lookup_disease(cell)
		if disease != null and disease.is_vector_borne:
			return Classification.MATCH
		return Classification.MISMATCH
	match data.applies_to:
		TreatmentData.AppliesTo.INFECTED:
			if not cell.has_active_disease:
				return Classification.NOOP
			var disease: DiseaseData = _lookup_disease(cell)
			if disease == null or not _category_matches(data, disease):
				return Classification.MISMATCH
			return Classification.MATCH
		TreatmentData.AppliesTo.HEALTHY_OR_PRE_INFECTION:
			if not cell.has_active_disease:
				return Classification.MATCH
			var disease: DiseaseData = _lookup_disease(cell)
			if disease == null or not _category_matches(data, disease):
				return Classification.MISMATCH
			return Classification.NOOP
		TreatmentData.AppliesTo.ANY:
			return Classification.MATCH
	return Classification.MISMATCH


## Previews the classification of each affected cell.
func preview(treatment_id: StringName, target: Vector2i, grid: FieldGridState) -> Array[CellPreview]:
	var result: Array[CellPreview] = []
	if treatment_config == null or grid == null:
		return result
	var data: TreatmentData = treatment_config.get_data(treatment_id)
	if data == null:
		return result
	for cell_coords: Vector2i in _affected_cells(data, target, grid):
		var p: CellPreview = CellPreview.new()
		p.cell = cell_coords
		p.classification = classify_cell(data, grid.get_cell(cell_coords))
		result.append(p)
	return result


## Shared validation for the FarmingController.action_error path.
func action_error(action: FieldAction) -> String:
	if treatment_config == null:
		return "Treatments are not configured."
	var treatment_id: StringName = kind_to_treatment_id(action.kind)
	var data: TreatmentData = treatment_config.get_data(treatment_id)
	if data == null:
		return "Unknown treatment for action kind %d." % action.kind
	# Bounds check is already done by FarmingController; validate target is in grid.
	return ""


## Commits a treatment action when the farmer arrives. Re-validates, classifies,
## creates/refreshes effects, spends cost, starts cooldown, logs usage and mistakes.
## Returns true on success (even if all cells mismatch), false on re-validation failure.
func commit_treatment(action: FieldAction, grid: FieldGridState, turn: int) -> bool:
	last_error = ""
	if treatment_config == null or grid == null:
		last_error = "Treatments are not configured."
		return false
	var treatment_id: StringName = kind_to_treatment_id(action.kind)
	var data: TreatmentData = treatment_config.get_data(treatment_id)
	if data == null:
		last_error = "Unknown treatment for action kind %d." % action.kind
		return false
	# Re-validate cooldown (could have changed since enqueue)
	var cd: int = treatment_state.get_cooldown(treatment_id)
	if cd > 0:
		last_error = "%s is on cooldown." % data.display_name
		return false
	# Re-validate cost
	if resource_budget >= 0 and data.cost > resource_budget:
		last_error = "Not enough resources for %s." % data.display_name
		return false
	# Compute affected cells
	var cells: Array[Vector2i] = _affected_cells(data, action.target, grid)
	# Classify each cell and apply effects
	var potency: float = _compute_potency(data, action.target, grid, turn)
	for cell_coords: Vector2i in cells:
		var cell: FieldCellState = grid.get_cell(cell_coords)
		if cell == null or not cell.has_crop:
			continue
		var cls: int = classify_cell(data, cell)
		match cls:
			Classification.MATCH:
				var effect: TreatmentEffect = TreatmentEffect.new()
				effect.treatment_id = treatment_id
				effect.cell = cell_coords
				effect.remaining_turns = data.duration_turns
				effect.potency = potency
				effect.applied_turn = turn
				treatment_state.put_effect(effect)
			Classification.MISMATCH:
				var disease: DiseaseData = _lookup_disease(cell)
				var disease_id: int = int(disease.disease_id) if disease != null else -1
				treatment_state.log_mistake(treatment_id, disease_id, cell_coords, turn)
			Classification.NOOP:
				pass  # No effect, no mistake
	# Spend cost
	if resource_budget >= 0:
		resource_budget -= data.cost
	# Start cooldown
	if data.cooldown_turns > 0:
		treatment_state.set_cooldown(treatment_id, data.cooldown_turns)
	# Log usage for resistance
	if data.resistance_group != TreatmentData.ResistanceGroup.NONE:
		treatment_state.log_usage(data.resistance_group, turn)
	# Log enhancer use for diminishing returns
	if treatment_id == &"enhancer":
		treatment_state.log_enhancer_use(action.target, turn)
	return true


## Advances the treatment state at end of turn.
func advance_turn(turn: int) -> void:
	if treatment_config != null and treatment_state != null:
		treatment_state.advance_turn(turn, treatment_config.resistance_window_turns)


## Computes the potency for a treatment at a given target and turn.
func _compute_potency(data: TreatmentData, target: Vector2i, grid: FieldGridState, turn: int) -> float:
	if data.treatment_id == &"enhancer":
		return TreatmentResolver.enhancer_potency(target, treatment_state, treatment_config, turn)
	if data.resistance_group != TreatmentData.ResistanceGroup.NONE:
		return TreatmentResolver.resistance_potency(data.resistance_group, treatment_state, treatment_config, turn)
	return 1.0


## Returns the current resistance potency for a group (for UI display).
func get_resistance_potency(resistance_group: int, turn: int) -> float:
	if treatment_config == null or resistance_group == TreatmentData.ResistanceGroup.NONE:
		return 1.0
	return TreatmentResolver.resistance_potency(resistance_group, treatment_state, treatment_config, turn)


## Returns the number of uses in the current window for a group (for UI display).
func get_resistance_usage(resistance_group: int, turn: int) -> int:
	if treatment_config == null or resistance_group == TreatmentData.ResistanceGroup.NONE:
		return 0
	return treatment_state.usage_count(resistance_group, treatment_config.resistance_window_turns, turn)


## Returns the cooldown turns remaining for a treatment (for UI display).
func get_cooldown(treatment_id: StringName) -> int:
	return treatment_state.get_cooldown(treatment_id)


## Returns the affected cells for a treatment (area or single cell).
func _affected_cells(data: TreatmentData, target: Vector2i, grid: FieldGridState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if data.target_mode == TreatmentData.TargetMode.CELL_OR_AREA:
		# CELL_OR_AREA: single cell (player chooses; area is an option in UI)
		if grid.is_in_bounds(target):
			result.append(target)
		return result
	# AREA: square of area_radius, clipped to grid
	var r: int = data.area_radius
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			var coords: Vector2i = target + Vector2i(dx, dy)
			if grid.is_in_bounds(coords):
				result.append(coords)
	return result


## Looks up the DiseaseData for a cell's active disease.
func _lookup_disease(cell: FieldCellState) -> DiseaseData:
	if disease_database == null or not cell.has_active_disease:
		return null
	return disease_database.get_disease(cell.active_disease_id)


## Checks if the treatment's allowed_categories includes the disease's category.
func _category_matches(data: TreatmentData, disease: DiseaseData) -> bool:
	if disease == null:
		return false
	if data.allowed_categories.is_empty():
		return true  # Empty = any category allowed
	return data.allowed_categories.has(int(disease.disease_category))

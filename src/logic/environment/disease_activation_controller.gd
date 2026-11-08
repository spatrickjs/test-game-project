class_name DiseaseActivationController
extends Node
## Plans against detached snapshots. Only a successful full turn commits history.

signal introduction_committed(disease_id: SimulationEnums.DiseaseId, coordinates: Vector2i, completed_turn: int)

class Result:
	extends RefCounted
	var next_state: DiseaseActivationState
	var request: DiseaseActivationRequest
	var errors: PackedStringArray = PackedStringArray()

@export var policy: DiseaseActivationPolicy
@export var debug_introductions: bool = true
var last_summary: String = ""
var _state: DiseaseActivationState

func reset_session() -> void:
	_state = _initial_state()
	last_summary = ""

func _initial_state() -> DiseaseActivationState:
	var state: DiseaseActivationState = DiseaseActivationState.new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = policy.random_seed if policy != null else 0
	state.rng_state = random.state
	return state

func get_state_snapshot() -> DiseaseActivationState:
	return _initial_state() if _state == null else _state.copy()

func evaluate(grid: FieldGridState, diseases: DiseaseDatabase, completed_turn: int, active_filter: int = -1, allow_introduction: bool = true) -> Result:
	var result: Result = Result.new()
	result.next_state = get_state_snapshot()
	if policy == null:
		result.errors.append("Assign an activation policy.")
		return result
	if not policy.enabled:
		return result
	result.errors.append_array(policy.validate())
	result.errors.append_array(result.next_state.validate())
	if grid == null or diseases == null or completed_turn < 1:
		result.errors.append("Activation requires a grid, catalog, and positive completed turn.")
		return result
	for disease_id: SimulationEnums.DiseaseId in policy.allowed_disease_ids:
		if diseases.get_disease(disease_id) == null:
			result.errors.append("Allowed disease %d is not registered." % disease_id)
	if not result.errors.is_empty():
		return result
	if result.next_state.cooldown_remaining > 0:
		result.next_state.cooldown_remaining -= 1
		return result
	if not allow_introduction or completed_turn < policy.first_eligible_turn or result.next_state.introductions_committed >= policy.max_introductions_per_session:
		return result
	# Retained identities count, including recovered crops. Do not create competition.
	var board_ids: Array[SimulationEnums.DiseaseId] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell: FieldCellState = grid.get_cell(Vector2i(x, y))
			if cell.has_crop and cell.has_active_disease and not board_ids.has(cell.active_disease_id):
				board_ids.append(cell.active_disease_id)
	if board_ids.size() > 1:
		return result
	if result.next_state.has_selected_disease and not board_ids.is_empty() and board_ids[0] != result.next_state.selected_disease_id:
		return result
	var eligible_ids: Array[SimulationEnums.DiseaseId] = []
	var eligible_cells: Dictionary[int, Array] = {}
	for disease_id: SimulationEnums.DiseaseId in policy.allowed_disease_ids:
		if active_filter != -1 and disease_id != active_filter:
			continue
		if result.next_state.has_selected_disease and disease_id != result.next_state.selected_disease_id:
			continue
		if not board_ids.is_empty() and disease_id != board_ids[0]:
			continue
		var disease: DiseaseData = diseases.get_disease(disease_id)
		var coordinates: Array[Vector2i] = []
		for y: int in range(grid.height):
			for x: int in range(grid.width):
				var cell: FieldCellState = grid.get_cell(Vector2i(x, y))
				if is_eligible(cell, disease):
					coordinates.append(cell.coordinates)
		if not coordinates.is_empty():
			eligible_ids.append(disease_id)
			eligible_cells[disease_id] = coordinates
	if eligible_ids.is_empty():
		return result
	eligible_ids.sort()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.state = result.next_state.rng_state
	if not result.next_state.has_selected_disease:
		result.next_state.selected_disease_id = eligible_ids[random.randi_range(0, eligible_ids.size() - 1)]
		result.next_state.has_selected_disease = true
	var succeeds: bool = policy.chance_per_eligible_turn >= 1.0
	if policy.chance_per_eligible_turn > 0.0 and policy.chance_per_eligible_turn < 1.0:
		succeeds = random.randf() < policy.chance_per_eligible_turn
	if succeeds:
		var cells: Array = eligible_cells[result.next_state.selected_disease_id]
		result.request = DiseaseActivationRequest.new()
		result.request.disease_id = result.next_state.selected_disease_id
		result.request.coordinates = cells[random.randi_range(0, cells.size() - 1)]
		result.next_state.introductions_committed += 1
		result.next_state.cooldown_remaining = policy.cooldown_turns
	result.next_state.rng_state = random.state
	return result

static func is_eligible(cell: FieldCellState, disease: DiseaseData) -> bool:
	return cell != null and disease != null and cell.has_crop and cell.soil != null and cell.crop_type == disease.target_crop and cell.validate().is_empty() and not cell.has_active_disease and cell.susceptible_fraction == 1.0 and cell.exposed_fraction == 0.0 and cell.infected_fraction == 0.0 and cell.recovered_immune_fraction == 0.0 and cell.dead_fraction == 0.0

## Called by FarmingController after field validation and commit, without emitting.
func commit_state(next_state: DiseaseActivationState) -> void:
	_state = next_state.copy()

## Called only after the turn clock has committed as well.
func report_committed(request: DiseaseActivationRequest, completed_turn: int) -> void:
	if request == null:
		return
	last_summary = "Game introduction turn %d: disease %d at %s." % [completed_turn, request.disease_id, request.coordinates]
	if debug_introductions:
		print(last_summary)
	introduction_committed.emit(request.disease_id, request.coordinates, completed_turn)

class_name TurnController
extends Node
## Manual discrete clock. No frame callback or timer drives simulation.

signal turn_completed(turn_index: int)

@export var farming_controller: FarmingController
@export var weather_manager: WeatherManager
@export var disease_activation_controller: DiseaseActivationController
## Optional for isolated Logic callers; assigned in the playable scene.
@export var game_state_manager: GameStateManager
## Empty catalog supports authoring; explicitly null is a configuration error.
@export var disease_database: DiseaseDatabase = DiseaseDatabase.new()
## RefCounted dependency: may be injected from code, not a scene node.
var simulation_controller: SimulationController = SimulationController.new()

var turn_index: int = 0
var last_error: String = ""
var _advancing: bool = false


func reset_clock() -> void:
	if not _advancing:
		if farming_controller != null:
			farming_controller.vector_activation = disease_activation_controller
			farming_controller.vector_diseases = disease_database
			farming_controller.vector_simulation = simulation_controller
		turn_index = 0
		last_error = ""
		if disease_activation_controller != null:
			disease_activation_controller.reset_session()


func try_set_algorithm_override(value: int) -> bool:
	if _advancing or farming_controller == null or not farming_controller.is_initialized() or simulation_controller == null:
		last_error = "Initialize the field before selecting an algorithm."
		return false
	var previous: int = simulation_controller.algorithm_override
	simulation_controller.algorithm_override = value
	simulation_controller.crop_database = farming_controller.crop_database
	var errors: PackedStringArray = simulation_controller.validate_turn(farming_controller.get_grid_snapshot(), disease_database)
	if not errors.is_empty():
		simulation_controller.algorithm_override = previous
		last_error = "\n".join(errors)
		return false
	last_error = ""
	return true


func advance_turn() -> bool:
	if game_state_manager != null and not game_state_manager.is_playing():
		last_error = "Start a game before advancing turns."
		return false
	if _advancing:
		return false
	if farming_controller == null or not farming_controller.is_initialized():
		last_error = "Assign and initialize the FarmingController first."
		return false
	if simulation_controller == null or disease_database == null:
		last_error = "Assign a simulation controller and disease catalog."
		return false
	var errors: PackedStringArray = disease_database.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return false
	_advancing = true
	var allow_introduction: bool = game_state_manager == null or turn_index + 1 < game_state_manager.turn_limit
	if not farming_controller.advance_simulated_turn(simulation_controller, disease_database, weather_manager, turn_index, disease_activation_controller, allow_introduction):
		last_error = farming_controller.last_error
		_advancing = false
		return false
	turn_index += 1
	last_error = ""
	if game_state_manager != null:
		game_state_manager.check_turn_limit(turn_index)
	if disease_activation_controller != null:
		disease_activation_controller.report_committed(farming_controller.last_turn_introduction, turn_index)
	turn_completed.emit(turn_index)
	_advancing = false
	return true

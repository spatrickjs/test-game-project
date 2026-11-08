extends RefCounted
## Isolates older gameplay tests from authored terrain and random encounters.
## Never saves or modifies shared resources.

static func prepare(scene: FieldPrototypePresenter, plantable_bands: bool = true) -> void:
	if plantable_bands:
		scene.farming_controller.terrain_bands = [SimulationEnums.TerrainType.DRY_SOIL, SimulationEnums.TerrainType.PADDY_MUD, SimulationEnums.TerrainType.GRASS]
	var activation: DiseaseActivationController = scene.turn_controller.disease_activation_controller
	if activation != null and activation.policy != null:
		activation.policy = activation.policy.duplicate() as DiseaseActivationPolicy
		activation.policy.enabled = false
	if scene.game_state_manager != null:
		scene.game_state_manager.turn_limit = 10000
		scene.game_state_manager.harvest_goal = 10000

static func start(scene: FieldPrototypePresenter) -> void:
	scene._on_start_pressed()

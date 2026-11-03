class_name DiseaseData
extends Resource
## Shared configuration; treat as read-only during simulation.
## Defaults are authoring placeholders, not empirically calibrated values.

@export_group("Identity")
@export var disease_id: SimulationEnums.DiseaseId = SimulationEnums.DiseaseId.RSSI
@export var display_name: String = ""
@export var target_crop: SimulationEnums.CropType = SimulationEnums.CropType.SUGARCANE

@export_group("Algorithm")
## The benchmark runner may override this without mutating the resource.
@export var default_algorithm: SimulationEnums.SimulationAlgorithm = SimulationEnums.SimulationAlgorithm.SPATIAL_SIR

@export_group("Compartment Rates")
## Rates use inverse simulation-time units, initially one time unit per tick.
## They are not probabilities and may exceed 1.0.
@export var beta: float = 0.0
@export var sigma: float = 0.0
@export var gamma: float = 0.0
## Zero keeps RECOVERED_IMMUNE permanent; positive values permit waning.
## DEAD never returns to susceptible.
@export var xi: float = 0.0
## Conditional probability that removal results in DEAD.
@export_range(0.0, 1.0, 0.01) var mortality_probability: float = 0.0

@export_group("Spatial Neighborhood")
## Manhattan radius for VON_NEUMANN_4; Chebyshev radius for MOORE_8.
## Both exclude the center tile.
@export var neighborhood_type: SimulationEnums.NeighborhoodType = SimulationEnums.NeighborhoodType.MOORE_8
@export var dispersal_radius: int = 1
## Future kernel: exp(-distance_decay * euclidean_distance_in_tiles).
@export var distance_decay: float = 0.0

@export_group("Optional Rules")
## Inside these intervals, disease pressure increases. Empty arrays are neutral.
@export var abiotic_trigger_rules: Array[AbioticRule] = []
## Healthy/resistant intervals: either deficiency or excess can increase susceptibility.
@export var nutrient_susceptibility_rules: Array[NutrientRule] = []


## Reports invalid configuration without mutation.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if display_name.strip_edges().is_empty():
		errors.append("display_name must not be blank.")
	if not SimulationEnums.DiseaseId.values().has(disease_id):
		errors.append("disease_id has an invalid identifier.")
	if not SimulationEnums.CropType.values().has(target_crop):
		errors.append("target_crop has an invalid identifier.")
	if not SimulationEnums.SimulationAlgorithm.values().has(default_algorithm):
		errors.append("default_algorithm has an invalid identifier.")
	if not SimulationEnums.NeighborhoodType.values().has(neighborhood_type):
		errors.append("neighborhood_type has an invalid identifier.")
	if SimulationEnums.DiseaseId.values().has(disease_id):
		if target_crop != _expected_target_crop():
			errors.append("target_crop does not match disease_id.")
	if dispersal_radius < 1:
		errors.append("dispersal_radius must be at least 1 tile.")
	_validate_nonnegative("beta", beta, errors)
	_validate_nonnegative("sigma", sigma, errors)
	_validate_nonnegative("gamma", gamma, errors)
	_validate_nonnegative("xi", xi, errors)
	_validate_nonnegative("distance_decay", distance_decay, errors)
	if is_nan(mortality_probability) or is_inf(mortality_probability):
		errors.append("mortality_probability must be finite.")
	elif mortality_probability < 0.0 or mortality_probability > 1.0:
		errors.append("mortality_probability must be in [0.0, 1.0].")
	var seen_factors: Array[SimulationEnums.AbioticFactor] = []
	for index: int in range(abiotic_trigger_rules.size()):
		var rule: AbioticRule = abiotic_trigger_rules[index]
		if rule == null:
			errors.append("abiotic_trigger_rules[%d] must not be null." % index)
			continue
		for error: String in rule.validate():
			errors.append("abiotic_trigger_rules[%d]: %s" % [index, error])
		if seen_factors.has(rule.factor):
			errors.append("abiotic_trigger_rules[%d] duplicates factor %d." % [index, rule.factor])
		else:
			seen_factors.append(rule.factor)
	var seen_nutrients: Array[SimulationEnums.NutrientType] = []
	for index: int in range(nutrient_susceptibility_rules.size()):
		var rule: NutrientRule = nutrient_susceptibility_rules[index]
		if rule == null:
			errors.append("nutrient_susceptibility_rules[%d] must not be null." % index)
			continue
		for error: String in rule.validate():
			errors.append("nutrient_susceptibility_rules[%d]: %s" % [index, error])
		if seen_nutrients.has(rule.nutrient):
			errors.append("nutrient_susceptibility_rules[%d] duplicates nutrient %d." % [index, rule.nutrient])
		else:
			seen_nutrients.append(rule.nutrient)
	return errors


## Deep-copies schema values, preserving invalid values and null entries.
func copy() -> DiseaseData:
	var result: DiseaseData = DiseaseData.new()
	result.disease_id = disease_id
	result.display_name = display_name
	result.target_crop = target_crop
	result.default_algorithm = default_algorithm
	result.beta = beta
	result.sigma = sigma
	result.gamma = gamma
	result.xi = xi
	result.mortality_probability = mortality_probability
	result.neighborhood_type = neighborhood_type
	result.dispersal_radius = dispersal_radius
	result.distance_decay = distance_decay
	for rule: AbioticRule in abiotic_trigger_rules:
		if rule == null:
			result.abiotic_trigger_rules.append(null)
		else:
			result.abiotic_trigger_rules.append(rule.copy())
	for rule: NutrientRule in nutrient_susceptibility_rules:
		if rule == null:
			result.nutrient_susceptibility_rules.append(null)
		else:
			result.nutrient_susceptibility_rules.append(rule.copy())
	return result


func _validate_nonnegative(
	property_name: String,
	value: float,
	errors: PackedStringArray
) -> void:
	if is_nan(value) or is_inf(value):
		errors.append("%s must be finite." % property_name)
	elif value < 0.0:
		errors.append("%s must be nonnegative." % property_name)


## Static catalog consistency, not epidemiological behavior.
## Called only after disease_id has passed enum validation.
func _expected_target_crop() -> SimulationEnums.CropType:
	match disease_id:
		SimulationEnums.DiseaseId.RSSI, SimulationEnums.DiseaseId.SUGARCANE_SMUT, SimulationEnums.DiseaseId.LEAF_SCALD:
			return SimulationEnums.CropType.SUGARCANE
		SimulationEnums.DiseaseId.RICE_TUNGRO, SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT, SimulationEnums.DiseaseId.RICE_BLAST:
			return SimulationEnums.CropType.RICE
		SimulationEnums.DiseaseId.COMMON_CORN_RUST, SimulationEnums.DiseaseId.PHILIPPINE_DOWNY_MILDEW, SimulationEnums.DiseaseId.EAR_ROT:
			return SimulationEnums.CropType.CORN
	push_error("Cannot resolve target crop for invalid disease_id.")
	return SimulationEnums.CropType.SUGARCANE

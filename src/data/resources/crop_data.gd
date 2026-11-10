class_name CropData
extends Resource
## Shared configuration; treat as read-only during simulation.
## Defaults are authoring placeholders, not empirically calibrated values.

@export_group("Identity")
@export var crop_type: SimulationEnums.CropType = SimulationEnums.CropType.SUGARCANE
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Growth and Immunity")
@export var growth_ticks: int = 1
## Null disables soil stress, preserving legacy growth behavior.
@export var growth_profile: CropGrowthProfile = CropGrowthProfile.new()
@export_range(0.0, 1.0, 0.01) var base_immunity: float = 0.5

@export_group("Growth Visuals (Presentation Only)")
## Seedling, Vegetative, Reproductive, Mature. -1 means not authored yet.
## Logic and Simulation must not interpret these TileSet identifiers.
@export var growth_stage_source_ids: Array[int] = [-1, -1, -1, -1]
@export var growth_stage_atlas_coords: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
## Generic diseased fallback, parallel to growth stages; -1 means not authored.
## Per-disease visuals in disease_visuals take precedence over this fallback.
@export var disease_stage_source_ids: Array[int] = [-1, -1, -1, -1]
@export var disease_stage_atlas_coords: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
## Per-disease visual sets. Checked before the generic fallback above.
## Add as many as needed; unlisted diseases fall back to the generic diseased look.
@export var disease_visuals: Array[DiseaseVisualSet] = []

@export_group("Optional Rules")
## Outside these intervals, crop stress increases. Empty arrays are neutral.
@export var abiotic_tolerance_rules: Array[AbioticRule] = []
## Healthy/resistant intervals: either deficiency or excess can increase stress.
@export var nutrient_requirement_rules: Array[NutrientRule] = []


## Reports invalid configuration without mutation.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if display_name.strip_edges().is_empty():
		errors.append("display_name must not be blank.")
	if not SimulationEnums.CropType.values().has(crop_type):
		errors.append("crop_type has an invalid identifier.")
	if growth_ticks < 1:
		errors.append("growth_ticks must be at least 1.")
	if is_nan(base_immunity) or is_inf(base_immunity):
		errors.append("base_immunity must be finite.")
	elif base_immunity < 0.0 or base_immunity > 1.0:
		errors.append("base_immunity must be in [0.0, 1.0].")
	if growth_profile != null:
		for error: String in growth_profile.validate():
			errors.append("growth_profile: " + error)
	var seen_factors: Array[SimulationEnums.AbioticFactor] = []
	for index: int in range(abiotic_tolerance_rules.size()):
		var rule: AbioticRule = abiotic_tolerance_rules[index]
		if rule == null:
			errors.append("abiotic_tolerance_rules[%d] must not be null." % index)
			continue
		for error: String in rule.validate():
			errors.append("abiotic_tolerance_rules[%d]: %s" % [index, error])
		if seen_factors.has(rule.factor):
			errors.append("abiotic_tolerance_rules[%d] duplicates factor %d." % [index, rule.factor])
		else:
			seen_factors.append(rule.factor)
	var seen_nutrients: Array[SimulationEnums.NutrientType] = []
	for index: int in range(nutrient_requirement_rules.size()):
		var rule: NutrientRule = nutrient_requirement_rules[index]
		if rule == null:
			errors.append("nutrient_requirement_rules[%d] must not be null." % index)
			continue
		for error: String in rule.validate():
			errors.append("nutrient_requirement_rules[%d]: %s" % [index, error])
		if seen_nutrients.has(rule.nutrient):
			errors.append("nutrient_requirement_rules[%d] duplicates nutrient %d." % [index, rule.nutrient])
		else:
			seen_nutrients.append(rule.nutrient)
	return errors


## Deep-copies schema values, preserving invalid values and null entries.
func copy() -> CropData:
	var result: CropData = CropData.new()
	result.crop_type = crop_type
	result.display_name = display_name
	result.description = description
	result.growth_ticks = growth_ticks
	result.growth_profile = growth_profile.copy() if growth_profile != null else null
	result.base_immunity = base_immunity
	result.growth_stage_source_ids = growth_stage_source_ids.duplicate()
	result.growth_stage_atlas_coords = growth_stage_atlas_coords.duplicate()
	result.disease_stage_source_ids = disease_stage_source_ids.duplicate()
	result.disease_stage_atlas_coords = disease_stage_atlas_coords.duplicate()
	result.disease_visuals = []
	for visual_set: DiseaseVisualSet in disease_visuals:
		if visual_set == null:
			result.disease_visuals.append(null)
		else:
			result.disease_visuals.append(visual_set.copy())
	for rule: AbioticRule in abiotic_tolerance_rules:
		if rule == null:
			result.abiotic_tolerance_rules.append(null)
		else:
			result.abiotic_tolerance_rules.append(rule.copy())
	for rule: NutrientRule in nutrient_requirement_rules:
		if rule == null:
			result.nutrient_requirement_rules.append(null)
		else:
			result.nutrient_requirement_rules.append(rule.copy())
	return result


## Resolves the TileSet source ID and atlas coordinate for a diseased crop at
## the given growth stage. Checks per-disease visual sets first, then the
## generic diseased fallback. Returns [source_id, atlas_coord] if authored,
## or null if not (caller should fall back to the healthy sprite).
func get_disease_visual(disease_id: int, stage: int) -> Variant:
	# Per-disease lookup
	for visual_set: DiseaseVisualSet in disease_visuals:
		if visual_set != null and visual_set.disease_id == disease_id:
			if stage >= 0 and stage < visual_set.stage_source_ids.size() and visual_set.stage_source_ids[stage] >= 0:
				var coord: Vector2i = Vector2i.ZERO
				if stage < visual_set.stage_atlas_coords.size():
					coord = visual_set.stage_atlas_coords[stage]
				return [visual_set.stage_source_ids[stage], coord]
			break
	# Generic fallback
	if stage >= 0 and stage < disease_stage_source_ids.size() and disease_stage_source_ids[stage] >= 0:
		var coord: Vector2i = Vector2i.ZERO
		if stage < disease_stage_atlas_coords.size():
			coord = disease_stage_atlas_coords[stage]
		return [disease_stage_source_ids[stage], coord]
	return null

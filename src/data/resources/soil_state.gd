class_name SoilState
extends Resource
## Passive per-tile soil data. Create a distinct instance for each tile.
## Nutrients describe normalized availability, not crop-specific sufficiency.
## Defaults are authoring placeholders, not agronomic recommendations.

@export_group("Macronutrients")
@export_range(0.0, 1.0, 0.01) var nitrogen: float = 0.5
@export_range(0.0, 1.0, 0.01) var phosphorus: float = 0.5
@export_range(0.0, 1.0, 0.01) var potassium: float = 0.5

@export_group("Micronutrients")
@export_range(0.0, 1.0, 0.01) var boron: float = 0.5
@export_range(0.0, 1.0, 0.01) var chlorine: float = 0.5
@export_range(0.0, 1.0, 0.01) var copper: float = 0.5
@export_range(0.0, 1.0, 0.01) var iron: float = 0.5
@export_range(0.0, 1.0, 0.01) var manganese: float = 0.5
@export_range(0.0, 1.0, 0.01) var molybdenum: float = 0.5
@export_range(0.0, 1.0, 0.01) var nickel: float = 0.5
@export_range(0.0, 1.0, 0.01) var zinc: float = 0.5

@export_group("Hydration")
## Local normalized moisture; distinct from field-wide atmospheric humidity.
@export_range(0.0, 1.0, 0.01) var moisture: float = 0.5

@export_group("Soil Chemistry")
@export_range(0.0, 14.0, 0.01) var soil_ph: float = 7.0


## Invalid enum identifiers report an error and return NAN.
func get_macro_nutrient(nutrient: SimulationEnums.MacroNutrient) -> float:
	match nutrient:
		SimulationEnums.MacroNutrient.NITROGEN:
			return nitrogen
		SimulationEnums.MacroNutrient.PHOSPHORUS:
			return phosphorus
		SimulationEnums.MacroNutrient.POTASSIUM:
			return potassium
	push_error("Unknown macro nutrient identifier: %d" % nutrient)
	return NAN


## Assigns the supplied value unchanged. Call validate() before using the state.
func set_macro_nutrient(nutrient: SimulationEnums.MacroNutrient, value: float) -> void:
	match nutrient:
		SimulationEnums.MacroNutrient.NITROGEN:
			nitrogen = value
		SimulationEnums.MacroNutrient.PHOSPHORUS:
			phosphorus = value
		SimulationEnums.MacroNutrient.POTASSIUM:
			potassium = value
		_:
			push_error("Unknown macro nutrient identifier: %d" % nutrient)



## Invalid enum identifiers report an error and return NAN.
func get_micro_nutrient(nutrient: SimulationEnums.MicroNutrient) -> float:
	match nutrient:
		SimulationEnums.MicroNutrient.BORON:
			return boron
		SimulationEnums.MicroNutrient.CHLORINE:
			return chlorine
		SimulationEnums.MicroNutrient.COPPER:
			return copper
		SimulationEnums.MicroNutrient.IRON:
			return iron
		SimulationEnums.MicroNutrient.MANGANESE:
			return manganese
		SimulationEnums.MicroNutrient.MOLYBDENUM:
			return molybdenum
		SimulationEnums.MicroNutrient.NICKEL:
			return nickel
		SimulationEnums.MicroNutrient.ZINC:
			return zinc
	push_error("Unknown micro nutrient identifier: %d" % nutrient)
	return NAN


## Assigns the supplied value unchanged. Call validate() before using the state.
func set_micro_nutrient(nutrient: SimulationEnums.MicroNutrient, value: float) -> void:
	match nutrient:
		SimulationEnums.MicroNutrient.BORON:
			boron = value
		SimulationEnums.MicroNutrient.CHLORINE:
			chlorine = value
		SimulationEnums.MicroNutrient.COPPER:
			copper = value
		SimulationEnums.MicroNutrient.IRON:
			iron = value
		SimulationEnums.MicroNutrient.MANGANESE:
			manganese = value
		SimulationEnums.MicroNutrient.MOLYBDENUM:
			molybdenum = value
		SimulationEnums.MicroNutrient.NICKEL:
			nickel = value
		SimulationEnums.MicroNutrient.ZINC:
			zinc = value
		_:
			push_error("Unknown micro nutrient identifier: %d" % nutrient)


## Unified selector bridge. Invalid identifiers report an error and return NAN.
func get_nutrient(nutrient: SimulationEnums.NutrientType) -> float:
	match nutrient:
		SimulationEnums.NutrientType.NITROGEN:
			return get_macro_nutrient(SimulationEnums.MacroNutrient.NITROGEN)
		SimulationEnums.NutrientType.PHOSPHORUS:
			return get_macro_nutrient(SimulationEnums.MacroNutrient.PHOSPHORUS)
		SimulationEnums.NutrientType.POTASSIUM:
			return get_macro_nutrient(SimulationEnums.MacroNutrient.POTASSIUM)
		SimulationEnums.NutrientType.BORON:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.BORON)
		SimulationEnums.NutrientType.CHLORINE:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.CHLORINE)
		SimulationEnums.NutrientType.COPPER:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.COPPER)
		SimulationEnums.NutrientType.IRON:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.IRON)
		SimulationEnums.NutrientType.MANGANESE:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.MANGANESE)
		SimulationEnums.NutrientType.MOLYBDENUM:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.MOLYBDENUM)
		SimulationEnums.NutrientType.NICKEL:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.NICKEL)
		SimulationEnums.NutrientType.ZINC:
			return get_micro_nutrient(SimulationEnums.MicroNutrient.ZINC)
	push_error("Unknown nutrient identifier: %d" % nutrient)
	return NAN


## Assigns unchanged through the existing typed nutrient accessors.
func set_nutrient(nutrient: SimulationEnums.NutrientType, value: float) -> void:
	match nutrient:
		SimulationEnums.NutrientType.NITROGEN:
			set_macro_nutrient(SimulationEnums.MacroNutrient.NITROGEN, value)
		SimulationEnums.NutrientType.PHOSPHORUS:
			set_macro_nutrient(SimulationEnums.MacroNutrient.PHOSPHORUS, value)
		SimulationEnums.NutrientType.POTASSIUM:
			set_macro_nutrient(SimulationEnums.MacroNutrient.POTASSIUM, value)
		SimulationEnums.NutrientType.BORON:
			set_micro_nutrient(SimulationEnums.MicroNutrient.BORON, value)
		SimulationEnums.NutrientType.CHLORINE:
			set_micro_nutrient(SimulationEnums.MicroNutrient.CHLORINE, value)
		SimulationEnums.NutrientType.COPPER:
			set_micro_nutrient(SimulationEnums.MicroNutrient.COPPER, value)
		SimulationEnums.NutrientType.IRON:
			set_micro_nutrient(SimulationEnums.MicroNutrient.IRON, value)
		SimulationEnums.NutrientType.MANGANESE:
			set_micro_nutrient(SimulationEnums.MicroNutrient.MANGANESE, value)
		SimulationEnums.NutrientType.MOLYBDENUM:
			set_micro_nutrient(SimulationEnums.MicroNutrient.MOLYBDENUM, value)
		SimulationEnums.NutrientType.NICKEL:
			set_micro_nutrient(SimulationEnums.MicroNutrient.NICKEL, value)
		SimulationEnums.NutrientType.ZINC:
			set_micro_nutrient(SimulationEnums.MicroNutrient.ZINC, value)
		_:
			push_error("Unknown nutrient identifier: %d" % nutrient)


## Reports invalid values without mutating this resource.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_validate_range("nitrogen", nitrogen, 0.0, 1.0, errors)
	_validate_range("phosphorus", phosphorus, 0.0, 1.0, errors)
	_validate_range("potassium", potassium, 0.0, 1.0, errors)
	_validate_range("boron", boron, 0.0, 1.0, errors)
	_validate_range("chlorine", chlorine, 0.0, 1.0, errors)
	_validate_range("copper", copper, 0.0, 1.0, errors)
	_validate_range("iron", iron, 0.0, 1.0, errors)
	_validate_range("manganese", manganese, 0.0, 1.0, errors)
	_validate_range("molybdenum", molybdenum, 0.0, 1.0, errors)
	_validate_range("nickel", nickel, 0.0, 1.0, errors)
	_validate_range("zinc", zinc, 0.0, 1.0, errors)
	_validate_range("moisture", moisture, 0.0, 1.0, errors)
	_validate_range("soil_ph", soil_ph, 0.0, 14.0, errors)
	return errors


## Copies all schema values, including invalid values, without sharing state.
func copy() -> SoilState:
	var result: SoilState = SoilState.new()
	result.nitrogen = nitrogen
	result.phosphorus = phosphorus
	result.potassium = potassium
	result.boron = boron
	result.chlorine = chlorine
	result.copper = copper
	result.iron = iron
	result.manganese = manganese
	result.molybdenum = molybdenum
	result.nickel = nickel
	result.zinc = zinc
	result.soil_ph = soil_ph
	result.moisture = moisture
	return result


func _validate_range(
	property_name: String,
	value: float,
	minimum: float,
	maximum: float,
	errors: PackedStringArray
) -> void:
	if is_nan(value) or is_inf(value):
		errors.append("%s must be finite." % property_name)
	elif value < minimum or value > maximum:
		errors.append("%s must be in [%s, %s]; received %s." % [
			property_name, minimum, maximum, value
		])

class_name SimulationEnums
extends RefCounted
## Shared identifiers. Preserve numeric values for future save compatibility.

enum SIRState {
	S = 0,
	E = 1,
	I = 2,
	R = 3,
}

enum RemovedOutcome {
	NONE = 0,
	RECOVERED_IMMUNE = 1,
	DEAD = 2,
}

enum SimulationAlgorithm {
	SPATIAL_SIR = 0,
	SPATIAL_SEIR = 1,
	STOCHASTIC_CA_SIR = 2,
}

enum CropType {
	SUGARCANE = 0,
	RICE = 1,
	CORN = 2,
}

enum MacroNutrient {
	NITROGEN = 0,
	PHOSPHORUS = 1,
	POTASSIUM = 2,
}

enum MicroNutrient {
	BORON = 0,
	CHLORINE = 1,
	COPPER = 2,
	IRON = 3,
	MANGANESE = 4,
	MOLYBDENUM = 5,
	NICKEL = 6,
	ZINC = 7,
}

enum NutrientType {
	NITROGEN = 0,
	PHOSPHORUS = 1,
	POTASSIUM = 2,
	BORON = 3,
	CHLORINE = 4,
	COPPER = 5,
	IRON = 6,
	MANGANESE = 7,
	MOLYBDENUM = 8,
	NICKEL = 9,
	ZINC = 10,
}

enum NeighborhoodType {
	VON_NEUMANN_4 = 0,
	MOORE_8 = 1,
}

enum DiseaseId {
	RSSI = 0,
	SUGARCANE_SMUT = 1,
	LEAF_SCALD = 2,
	RICE_TUNGRO = 3,
	BACTERIAL_LEAF_BLIGHT = 4,
	RICE_BLAST = 5,
	COMMON_CORN_RUST = 6,
	PHILIPPINE_DOWNY_MILDEW = 7,
	EAR_ROT = 8,
}

enum AbioticFactor {
	SOIL_PH = 0,
	LIGHT_INTENSITY = 1,
	RELATIVE_HUMIDITY = 2,
	ATMOSPHERIC_PRESSURE_KPA = 3,
}


enum TerrainType {
	DRY_SOIL = 0,
	PADDY_MUD = 1,
	GRASS = 2,
}

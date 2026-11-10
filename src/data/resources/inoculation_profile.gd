class_name InoculationProfile
extends Resource
## Fictional gameplay tuning, not agricultural calibration.
@export var duration_turns: int = 3
@export var minimum_moisture: float = 0.3
@export var maximum_moisture: float = 1.0
@export var growing_bonus: float = 0.25
@export var mature_bonus: float = 0.15
## Fractional bonus lost per turn, interpolated using relative humidity.
@export var dry_weather_decay: float = 0.0
@export var humid_weather_decay: float = 0.0

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if duration_turns < 1:
		errors.append("Inoculation duration must be positive.")
	for value: float in [minimum_moisture, maximum_moisture, growing_bonus, mature_bonus, dry_weather_decay, humid_weather_decay]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			errors.append("Inoculation values must be finite and in [0, 1].")
	if minimum_moisture > maximum_moisture or growing_bonus <= 0.0 or mature_bonus <= 0.0:
		errors.append("Inoculation requires ordered moisture bounds and positive bonuses.")
	return errors

func decay(environment: AbioticState) -> float:
	return lerpf(dry_weather_decay, humid_weather_decay, environment.relative_humidity)

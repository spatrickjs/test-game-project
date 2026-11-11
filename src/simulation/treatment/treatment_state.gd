class_name TreatmentState
extends RefCounted
## Per-game treatment state: active effects, cooldowns, resistance usage,
## enhancer per-cell history, and mistake log. Save/load via to_dict/from_dict.

## Key format for effects: "cell_x:cell_y:treatment_id"
var effects: Dictionary = {}
## treatment_id (String) -> turns left (int)
var cooldowns: Dictionary = {}
## ResistanceGroup (int) -> Array[int] of turn numbers when used
var usage_log: Dictionary = {}
## Vector2i key string "x:y" -> Array[int] of turn numbers
var enhancer_uses: Dictionary = {}
## Array[Dictionary] = {treatment_id, disease_id, cell_x, cell_y, turn}
var mistakes: Array = []
## Signal-like event queue (cleared after each advance_turn). Items:
## {"type": "expired", "treatment_id": ..., "cell": Vector2i, "turn": ...}
var events: Array = []


## Returns all active effects on a given cell, across all treatments.
func effects_on(cell: Vector2i) -> Array[TreatmentEffect]:
	var result: Array[TreatmentEffect] = []
	var prefix: String = "%d:%d:" % [cell.x, cell.y]
	for key: String in effects:
		if key.begins_with(prefix):
			var effect: TreatmentEffect = effects[key]
			if effect != null:
				result.append(effect)
	return result


## Finds an existing effect for a specific treatment on a cell, or null.
func get_effect(cell: Vector2i, treatment_id: StringName) -> TreatmentEffect:
	var key: String = "%d:%d:%s" % [cell.x, cell.y, String(treatment_id)]
	return effects.get(key, null)


## Stores or refreshes an effect. Same treatment refreshes duration and keeps max potency.
func put_effect(effect: TreatmentEffect) -> void:
	var key: String = "%d:%d:%s" % [effect.cell.x, effect.cell.y, String(effect.treatment_id)]
	var existing: TreatmentEffect = effects.get(key, null)
	if existing != null:
		existing.remaining_turns = effect.remaining_turns
		existing.potency = maxf(existing.potency, effect.potency)
		existing.applied_turn = effect.applied_turn
	else:
		effects[key] = effect


## Removes an effect for a specific treatment on a cell.
func remove_effect(cell: Vector2i, treatment_id: StringName) -> void:
	var key: String = "%d:%d:%s" % [cell.x, cell.y, String(treatment_id)]
	effects.erase(key)


## Returns the turns remaining for a treatment cooldown (0 = ready).
func get_cooldown(treatment_id: StringName) -> int:
	return int(cooldowns.get(String(treatment_id), 0))


## Sets a cooldown for a treatment.
func set_cooldown(treatment_id: StringName, turns: int) -> void:
	cooldowns[String(treatment_id)] = maxi(0, turns)


## Appends a usage entry for a resistance group at a given turn.
func log_usage(resistance_group: int, turn: int) -> void:
	var key: int = resistance_group
	if not usage_log.has(key):
		usage_log[key] = []
	(usage_log[key] as Array).append(turn)


## Returns the count of uses for a group within the window ending at current_turn.
func usage_count(resistance_group: int, window_turns: int, current_turn: int) -> int:
	var key: int = resistance_group
	if not usage_log.has(key):
		return 0
	var count: int = 0
	for turn: int in usage_log[key]:
		if turn > current_turn - window_turns and turn <= current_turn:
			count += 1
	return count


## Appends an enhancer use for a cell at a given turn.
func log_enhancer_use(cell: Vector2i, turn: int) -> void:
	var key: String = "%d:%d" % [cell.x, cell.y]
	if not enhancer_uses.has(key):
		enhancer_uses[key] = []
	(enhancer_uses[key] as Array).append(turn)


## Returns the count of enhancer uses on a cell within the window.
func enhancer_use_count(cell: Vector2i, window_turns: int, current_turn: int) -> int:
	var key: String = "%d:%d" % [cell.x, cell.y]
	if not enhancer_uses.has(key):
		return 0
	var count: int = 0
	for turn: int in enhancer_uses[key]:
		if turn > current_turn - window_turns and turn <= current_turn:
			count += 1
	return count


## Records a mistake (wrong treatment on a mismatched cell).
func log_mistake(treatment_id: StringName, disease_id: int, cell: Vector2i, turn: int) -> void:
	mistakes.append({
		"treatment_id": String(treatment_id),
		"disease_id": disease_id,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"turn": turn,
	})


## Advances the turn: decrement durations, expire effects, decrement cooldowns,
## prune old usage/enhancer entries. Emits events for expired effects.
func advance_turn(current_turn: int, window_turns: int) -> void:
	events.clear()
	var expired_keys: Array[String] = []
	for key: String in effects:
		var effect: TreatmentEffect = effects[key]
		if effect == null:
			expired_keys.append(key)
			continue
		effect.remaining_turns -= 1
		if effect.remaining_turns <= 0:
			expired_keys.append(key)
			events.append({
				"type": "expired",
				"treatment_id": String(effect.treatment_id),
				"cell_x": effect.cell.x,
				"cell_y": effect.cell.y,
				"turn": current_turn,
			})
	for key: String in expired_keys:
		effects.erase(key)
	# Decrement cooldowns
	var ready: Array[String] = []
	for treatment_id: String in cooldowns:
		cooldowns[treatment_id] = int(cooldowns[treatment_id]) - 1
		if int(cooldowns[treatment_id]) <= 0:
			ready.append(treatment_id)
	for treatment_id: String in ready:
		cooldowns.erase(treatment_id)
	# Prune usage log entries older than the window
	for key in usage_log:
		var entries: Array = usage_log[key]
		var pruned: Array[int] = []
		for turn: int in entries:
			if turn > current_turn - window_turns:
				pruned.append(turn)
		usage_log[key] = pruned
	# Prune enhancer uses older than the window
	for key in enhancer_uses:
		var entries: Array = enhancer_uses[key]
		var pruned: Array[int] = []
		for turn: int in entries:
			if turn > current_turn - window_turns:
				pruned.append(turn)
		enhancer_uses[key] = pruned


## Full serialization for save games.
func to_dict() -> Dictionary:
	var effects_data: Array = []
	for key: String in effects:
		var effect: TreatmentEffect = effects[key]
		if effect != null:
			effects_data.append(effect.to_dict())
	return {
		"effects": effects_data,
		"cooldowns": cooldowns.duplicate(true),
		"usage_log": _int_dict_to_serializable(usage_log),
		"enhancer_uses": enhancer_uses.duplicate(true),
		"mistakes": mistakes.duplicate(true),
	}


## Restores from a save dict. Missing keys load as empty (backward compatible).
static func from_dict(data: Dictionary) -> TreatmentState:
	var state: TreatmentState = TreatmentState.new()
	var effects_data: Array = data.get("effects", [])
	for entry: Dictionary in effects_data:
		var effect: TreatmentEffect = TreatmentEffect.from_dict(entry)
		state.effects["%d:%d:%s" % [effect.cell.x, effect.cell.y, String(effect.treatment_id)]] = effect
	state.cooldowns = data.get("cooldowns", {}).duplicate(true)
	state.usage_log = _serializable_to_int_dict(data.get("usage_log", {}))
	state.enhancer_uses = data.get("enhancer_uses", {}).duplicate(true)
	state.mistakes = data.get("mistakes", []).duplicate(true)
	return state


## Returns a deep copy for snapshot isolation.
func copy() -> TreatmentState:
	return TreatmentState.from_dict(to_dict())


static func _int_dict_to_serializable(d: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in d:
		result[String(key)] = d[key]
	return result


static func _serializable_to_int_dict(d: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in d:
		result[int(key)] = d[key]
	return result

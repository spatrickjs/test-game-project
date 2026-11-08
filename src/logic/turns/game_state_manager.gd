class_name GameStateManager
extends Node
## Meta game state machine. Gates player interaction and tracks win/lose conditions.
## The presenter creates this node if one is not assigned in the Inspector.

signal state_changed(old_state: State, new_state: State)
signal score_changed(total_score: float, goal: int)
signal game_ended(victory: bool)

enum State { MENU, PLAYING, GAME_OVER, VICTORY }

## Maximum turns before the game is lost.
@export var turn_limit: int = 20
## Total harvest score required to win.
@export var score_goal: int = 1000

var current_state: State = State.MENU
var total_score: float = 0.0
var harvest_count: int = 0
var turns_reached: int = 0
## Per-crop tally keyed by crop_type (int); values are CropTally instances.
var crop_tally: Dictionary = {}


## Mutable per-crop harvest totals used by the results screen.
class CropTally:
	extends RefCounted
	var count: int = 0
	var score: float = 0.0


func start_game() -> void:
	total_score = 0.0
	harvest_count = 0
	turns_reached = 0
	crop_tally.clear()
	transition_to(State.PLAYING)
	score_changed.emit(total_score, score_goal)


func record_harvest(result: HarvestResult) -> void:
	if not is_playing() or result == null or not result.success:
		return
	total_score += result.score
	harvest_count += 1
	var key: int = result.crop_type
	var tally: CropTally = crop_tally.get(key) as CropTally
	if tally == null:
		tally = CropTally.new()
		crop_tally[key] = tally
	tally.count += 1
	tally.score += result.score
	score_changed.emit(total_score, score_goal)
	if total_score >= score_goal:
		transition_to(State.VICTORY)
		game_ended.emit(true)


func check_turn_limit(turn_index: int) -> void:
	turns_reached = turn_index
	if is_playing() and turn_index >= turn_limit:
		transition_to(State.GAME_OVER)
		game_ended.emit(false)


func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	var old := current_state
	current_state = new_state
	state_changed.emit(old, new_state)


func is_playing() -> bool:
	return current_state == State.PLAYING

class_name SaveGameController
extends Node
## Owns save-game existence state and reads save metadata headers. Presentation
## reads save existence via has_saved_game() and the save_state_changed signal and
## never inspects the save file directly. Writing the save file is a future concern
## outside this feature's scope; this controller only detects and reads it.

signal save_state_changed(has_save: bool)

var last_error: String = ""
var _save_path: String = "user://savegame.dat"
var _last_known_has_save: bool = false


## True when a save file exists at the configured path. Cheap existence check used
## to gate the Continue option on the Play Menu. Reflects the file's presence even
## when its metadata cannot be parsed.
func has_saved_game() -> bool:
	return FileAccess.file_exists(_save_path)


## Re-checks save existence and emits save_state_changed only when the result
## changed since the last check. Called when the Play Menu opens and after a new
## game starts so the Continue option reflects the latest save state.
func refresh() -> void:
	var has_save: bool = has_saved_game()
	if has_save == _last_known_has_save:
		last_error = ""
		return
	_last_known_has_save = has_save
	last_error = ""
	save_state_changed.emit(has_save)


## Reads and parses the save metadata header. Returns null if no save exists or
## parsing fails; has_saved_game() still reports true for a corrupt file so the
## presenter can keep Continue available while optionally showing a warning.
## Metadata is stored as a ConfigFile [metadata] section so the format stays
## forward-compatible with future game-state sections.
func get_metadata() -> SavedGameMetadata:
	last_error = ""
	if not has_saved_game():
		return null
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(_save_path)
	if err != OK:
		last_error = "Could not parse save metadata (error %d)." % err
		return null
	var metadata: SavedGameMetadata = SavedGameMetadata.new()
	metadata.exists = true
	metadata.timestamp = int(config.get_value("metadata", "timestamp", 0))
	metadata.turn_index = int(config.get_value("metadata", "turn_index", 0))
	metadata.display_name = String(config.get_value("metadata", "display_name", ""))
	var errors: PackedStringArray = metadata.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return null
	return metadata

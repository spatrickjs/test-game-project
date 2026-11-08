class_name SavedGameMetadata
extends RefCounted
## Lightweight header describing a persisted Saved_Game.
## Created by SaveGameController when reading user://savegame.dat.
## Presentation treats these instances as read-only snapshots.

## True when a save file exists at the configured path.
var exists: bool = false
## Unix epoch seconds at the time the save was written.
var timestamp: int = 0
## Progress marker used to resume the player's previous progress.
var turn_index: int = 0
## Human-readable label shown next to the Continue option.
var display_name: String = ""


## Reports invalid values without mutating this instance.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if timestamp < 0:
		errors.append("timestamp must be nonnegative.")
	if turn_index < 0:
		errors.append("turn_index must be nonnegative.")
	return errors


## Copies all values, including invalid values, without sharing state.
func copy() -> SavedGameMetadata:
	var result: SavedGameMetadata = SavedGameMetadata.new()
	result.exists = exists
	result.timestamp = timestamp
	result.turn_index = turn_index
	result.display_name = display_name
	return result

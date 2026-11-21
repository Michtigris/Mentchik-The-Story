extends Node

const SAVE_PATH := "user://save_game.json"

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	var data := GameState.export_save_data()
	file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var raw_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		GameState.import_save_data(parsed)

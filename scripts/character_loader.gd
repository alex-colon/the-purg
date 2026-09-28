extends Node
## CharacterDB (autoload)
##
## Scans res://data/characters/ for character folders and loads their
## character.json + event JSON files into memory. This is the core of
## the "anyone can submit an OC" pipeline: as long as a folder matches
## the schema documented in docs/CHARACTER_TEMPLATE.md, the game will
## find and load it automatically -- no code changes needed to add,
## remove, or edit a character.

const CHARACTERS_PATH := "res://data/characters/"

var characters: Dictionary = {} # id (String) -> character data (Dictionary)


func _ready() -> void:
	load_all_characters()


func load_all_characters() -> void:
	characters.clear()

	var dir := DirAccess.open(CHARACTERS_PATH)
	if dir == null:
		push_error("CharacterDB: could not open %s" % CHARACTERS_PATH)
		return

	dir.list_dir_begin()
	var folder_name := dir.get_next()

	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			_load_character_folder(CHARACTERS_PATH.path_join(folder_name))

		folder_name = dir.get_next()

	dir.list_dir_end()


func _load_character_folder(folder_path: String) -> void:
	var manifest_path := folder_path.path_join("character.json")
	var data := _load_json(manifest_path)

	if data.is_empty():
		push_warning("CharacterDB: no valid character.json in %s" % folder_path)
		return

	if not data.has("id"):
		push_warning("CharacterDB: character.json in %s is missing an id" % folder_path)
		return

	data["_folder"] = folder_path
	data["events"] = _load_events(folder_path.path_join("events"))

	characters[data["id"]] = data


func _load_events(events_path: String) -> Dictionary:
	var events: Dictionary = {}
	var dir := DirAccess.open(events_path)

	if dir == null:
		return events # a character with no events folder yet is valid (e.g. pool characters)

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var event_data := _load_json(events_path.path_join(file_name))
			var key := file_name.get_basename() # "heart_4.json" -> "heart_4"

			if not event_data.is_empty():
				events[key] = event_data

		file_name = dir.get_next()

	dir.list_dir_end()
	return events


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)

	if parsed is Dictionary:
		return parsed

	push_warning("CharacterDB: failed to parse JSON at %s" % path)
	return {}


func get_character(id: String) -> Dictionary:
	return characters.get(id, {})


func get_event(id: String, event_key: String) -> Dictionary:
	var character := get_character(id)
	var events: Dictionary = character.get("events", {})
	return events.get(event_key, {})


func get_all_ids() -> Array:
	return characters.keys()

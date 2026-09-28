extends Node
## Roster (autoload)
##
## Decides which characters live in town ("active") and which are
## waiting in the wings ("pool").
##
## When a character's case is called (their 10-heart / 10-skull scene
## finishes), DialogueBox calls depart(). They leave town immediately,
## and a random pool character arrives the next morning.
##
## The roster is saved to disk, so restarting the game keeps everyone
## where they were.

const SAVE_PATH := "user://roster.json"

var active_ids: Array = []
var pool_ids: Array = []
var departed_ids: Array = []
var pending_arrivals: int = 0 # departures still waiting for a replacement

signal character_departed(character_id: String)
signal character_arrived(character_id: String)


func _ready() -> void:
	_build_from_character_db()
	_load_saved_state()
	_retire_maxed_out_characters()
	save_state()
	Relationships.day_changed.connect(_on_day_changed)


# -------------------------------------------------------------- setup

func _build_from_character_db() -> void:
	active_ids.clear()
	pool_ids.clear()

	for id in CharacterDB.get_all_ids():
		var status := str(CharacterDB.get_character(id).get("status", "pool"))

		if status == "active":
			active_ids.append(id)
		elif status == "pool":
			pool_ids.append(id)
		# "pending" / "departed" characters are skipped on purpose


func _load_saved_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	active_ids = _known_ids(parsed.get("active", []))
	pool_ids = _known_ids(parsed.get("pool", []))
	departed_ids = _known_ids(parsed.get("departed", []))
	pending_arrivals = int(parsed.get("pending_arrivals", 0))

	# Characters added to the game since this save was written get filed
	# by their own "status", so new content shows up without a reset.
	for id in CharacterDB.get_all_ids():
		if active_ids.has(id) or pool_ids.has(id) or departed_ids.has(id):
			continue

		var status := str(CharacterDB.get_character(id).get("status", "pool"))

		if status == "active":
			active_ids.append(id)
		elif status == "pool":
			pool_ids.append(id)


func _known_ids(value: Variant) -> Array:
	# Keeps only ids that still exist in the game's character data.
	var result: Array = []

	if value is Array:
		for id in value:
			if CharacterDB.characters.has(str(id)):
				result.append(str(id))

	return result


func _retire_maxed_out_characters() -> void:
	# Covers saves from before the roster was saved: anyone already at
	# 10 hearts/skulls should have left town.
	for id in active_ids.duplicate():
		if absi(Relationships.get_score(id)) >= Relationships.MAX_SCORE:
			active_ids.erase(id)
			departed_ids.append(id)
			pending_arrivals += 1


# ---------------------------------------------------------- cycling

func depart(character_id: String) -> void:
	if not active_ids.has(character_id):
		return

	active_ids.erase(character_id)
	departed_ids.append(character_id)
	pending_arrivals += 1

	save_state()
	character_departed.emit(character_id)


func _on_day_changed(_day: int) -> void:
	while pending_arrivals > 0:
		if not _promote_random_pool_character():
			break # pool is empty; wait until new characters are added

		pending_arrivals -= 1

	save_state()


func _promote_random_pool_character() -> bool:
	if pool_ids.is_empty():
		push_warning("Roster: pool is empty, no one available to cycle in")
		return false

	var index := randi() % pool_ids.size()
	var new_id: String = pool_ids[index]

	pool_ids.remove_at(index)
	active_ids.append(new_id)
	character_arrived.emit(new_id)
	return true


# ------------------------------------------------------- save / reset

func reset_all() -> void:
	departed_ids.clear()
	pending_arrivals = 0
	_build_from_character_db()
	save_state()


func save_state() -> void:
	var payload := {
		"active": active_ids,
		"pool": pool_ids,
		"departed": departed_ids,
		"pending_arrivals": pending_arrivals,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(payload, "\t"))

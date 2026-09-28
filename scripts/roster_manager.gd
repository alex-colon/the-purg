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
var departures: Dictionary = {}   # id -> {"day", "gate": "bright"/"ember", "mood": "hearts"/"skulls"}
var arrival_days: Dictionary = {} # id -> the day they arrived in town (missing = was here from the start)

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

	var saved_departures: Dictionary = parsed.get("departures", {})
	for id in saved_departures.keys():
		if CharacterDB.characters.has(str(id)):
			departures[str(id)] = saved_departures[id]

	# Anyone who left before departures were recorded still needs a record.
	for id in departed_ids:
		if not departures.has(id):
			_record_departure(str(id), 0)

	var saved_arrivals: Dictionary = parsed.get("arrival_days", {})
	for id in saved_arrivals.keys():
		if CharacterDB.characters.has(str(id)):
			arrival_days[str(id)] = int(saved_arrivals[id])

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
			_record_departure(str(id))


# ---------------------------------------------------------- cycling

func depart(character_id: String) -> void:
	if not active_ids.has(character_id):
		return

	active_ids.erase(character_id)
	departed_ids.append(character_id)
	pending_arrivals += 1
	_record_departure(character_id)

	save_state()
	character_departed.emit(character_id)


func _record_departure(character_id: String, day: int = -1) -> void:
	# Saints walk through the bright gate, sinners through the ember gate,
	# whatever the player felt about them. "mood" is how they felt at the end.
	# day 0 means "we don't know when" (a save from before departures were recorded).
	var alignment := str(CharacterDB.get_character(character_id).get("alignment", "sinner"))

	departures[character_id] = {
		"day": Relationships.current_day if day < 0 else day,
		"gate": "bright" if alignment == "saint" else "ember",
		"mood": "hearts" if Relationships.get_score(character_id) >= 0 else "skulls",
	}


func _on_day_changed(day: int) -> void:
	while pending_arrivals > 0:
		if not _promote_random_pool_character(day):
			break # pool is empty; wait until new characters are added

		pending_arrivals -= 1

	save_state()


func _promote_random_pool_character(day: int) -> bool:
	if pool_ids.is_empty():
		push_warning("Roster: pool is empty, no one available to cycle in")
		return false

	var index := randi() % pool_ids.size()
	var new_id: String = pool_ids[index]

	pool_ids.remove_at(index)
	active_ids.append(new_id)
	arrival_days[new_id] = day
	character_arrived.emit(new_id)
	return true


# ------------------------------------------------------- save / reset

func reset_all() -> void:
	departed_ids.clear()
	departures.clear()
	arrival_days.clear()
	pending_arrivals = 0
	_build_from_character_db()
	save_state()


func save_state() -> void:
	var payload := {
		"active": active_ids,
		"pool": pool_ids,
		"departed": departed_ids,
		"pending_arrivals": pending_arrivals,
		"departures": departures,
		"arrival_days": arrival_days,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(payload, "\t"))

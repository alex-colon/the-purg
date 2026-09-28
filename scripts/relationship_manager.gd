extends Node
## Relationships (autoload)
##
## Tracks, per character id:
##   - a score from -10 (max skulls) to +10 (max hearts)
##   - which milestone events (4 / 8 / 10) have already fired
## and, for the whole game:
##   - the current day
##   - who the player has already spent time with today
##
## Positive score = hearts, negative score = skulls.
## The DialogueBox listens for `milestone_reached` and plays the scenes;
## a level-10 scene ends with the character's case being called (Roster).

const SAVE_PATH := "user://relationships.json"
const MAX_SCORE := 10
const MIN_SCORE := -10
const LEVELS := [4, 8, 10] # milestone thresholds, checked against abs(score)

var scores: Dictionary = {}          # id -> int, -10..10
var unlocked_events: Dictionary = {} # id -> Array of event keys already fired
var acted_today: Dictionary = {}     # id -> true once the player gifted/insulted them today
var current_day: int = 1

signal milestone_reached(character_id: String, event_key: String, event_data: Dictionary)
signal day_changed(day: int)


func _ready() -> void:
	load_data()


# --------------------------------------------------------------- scores

func get_score(character_id: String) -> int:
	return int(scores.get(character_id, 0))


func adjust_score(character_id: String, amount: int) -> void:
	var current := get_score(character_id)
	var new_score := clampi(current + amount, MIN_SCORE, MAX_SCORE)
	scores[character_id] = new_score

	_check_milestones(character_id, new_score)
	save_data()


func _check_milestones(character_id: String, score: int) -> void:
	var prefix := "heart" if score >= 0 else "skull"
	var magnitude := absi(score)

	for level in LEVELS:
		if magnitude < level:
			continue

		var event_key := "%s_%d" % [prefix, level]

		if _has_unlocked(character_id, event_key):
			continue

		_mark_unlocked(character_id, event_key)

		var event_data := CharacterDB.get_event(character_id, event_key)
		milestone_reached.emit(character_id, event_key, event_data)


func _has_unlocked(character_id: String, event_key: String) -> bool:
	var unlocked: Array = unlocked_events.get(character_id, [])
	return unlocked.has(event_key)


func _mark_unlocked(character_id: String, event_key: String) -> void:
	if not unlocked_events.has(character_id):
		unlocked_events[character_id] = []

	unlocked_events[character_id].append(event_key)


# ----------------------------------------------------------------- days

func has_acted_today(character_id: String) -> bool:
	return bool(acted_today.get(character_id, false))


func mark_acted_today(character_id: String) -> void:
	acted_today[character_id] = true
	save_data()


func start_new_day() -> void:
	current_day += 1
	acted_today.clear()
	save_data()
	day_changed.emit(current_day)


# ------------------------------------------------------- save / load

func reset_all() -> void:
	scores.clear()
	unlocked_events.clear()
	acted_today.clear()
	current_day = 1
	save_data()


func save_data() -> void:
	var payload := {
		"scores": scores,
		"unlocked_events": unlocked_events,
		"acted_today": acted_today,
		"current_day": current_day,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(payload, "\t"))


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	# JSON stores every number as a float, so convert scores back to ints.
	scores.clear()
	var saved_scores: Dictionary = parsed.get("scores", {})
	for id in saved_scores.keys():
		scores[str(id)] = int(saved_scores[id])

	unlocked_events = parsed.get("unlocked_events", {})
	acted_today = parsed.get("acted_today", {})
	current_day = int(parsed.get("current_day", 1))

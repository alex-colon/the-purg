extends Node
## Relationships (autoload)
##
## Tracks the player's standing with every character by id, as a single
## score from -10 (max skulls) to +10 (max hearts). Also tracks which
## milestone events have already fired, so each only plays once.
##
## Positive score = hearts (saint-track goodwill).
## Negative score = skulls (sinner-track spite).

const SAVE_PATH := "user://relationships.json"
const MAX_SCORE := 10
const MIN_SCORE := -10
const LEVELS := [4, 8, 10] # milestone thresholds, checked against abs(score)

var scores: Dictionary = {}          # id -> int, -10..10
var unlocked_events: Dictionary = {} # id -> Array[String] of event keys already fired

signal milestone_reached(character_id: String, event_key: String, event_data: Dictionary)
signal case_called(character_id: String)


func _ready() -> void:
	load_data()


func get_score(character_id: String) -> int:
	return scores.get(character_id, 0)


func adjust_score(character_id: String, amount: int) -> void:
	var current := get_score(character_id)
	var new_score: int = clampi(current + amount, MIN_SCORE, MAX_SCORE)
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

		if level == 10:
			case_called.emit(character_id)


func _has_unlocked(character_id: String, event_key: String) -> bool:
	var unlocked: Array = unlocked_events.get(character_id, [])
	return unlocked.has(event_key)


func _mark_unlocked(character_id: String, event_key: String) -> void:
	if not unlocked_events.has(character_id):
		unlocked_events[character_id] = []

	unlocked_events[character_id].append(event_key)


func save_data() -> void:
	var payload := {
		"scores": scores,
		"unlocked_events": unlocked_events,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t"))


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if parsed is Dictionary:
		scores = parsed.get("scores", {})
		unlocked_events = parsed.get("unlocked_events", {})

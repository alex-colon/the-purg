extends Node
## Relationships (autoload)
##
## The save state for the whole run. Per character id:
##   - a score from -10 (max skulls) to +10 (max hearts)
##   - which milestone events (4 / 8 / 10) have already fired
##   - what the player has learned about their gift tastes
## and for the player / world:
##   - the current day, and who the player has spent time with today
##   - coins and the item inventory
##   - one-per-day flags (foraging, digging, ...) and the day's notice board
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

const STARTING_COINS := 20
const STARTING_ITEMS := {"wildflowers": 1, "sweet_bun": 1, "old_coin": 1}

var coins: int = STARTING_COINS
var inventory: Dictionary = STARTING_ITEMS.duplicate() # item id -> how many you hold
var known_tastes: Dictionary = {}  # character id -> {item id -> "love"/"like"/...}
var daily_flags: Dictionary = {}   # "forage:meadow" -> true, cleared every morning
var board: Dictionary = {}         # today's notice-board requests

signal milestone_reached(character_id: String, event_key: String, event_data: Dictionary)
signal day_changed(day: int)
signal inventory_changed


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
	daily_flags.clear()
	save_data()
	day_changed.emit(current_day)


func flag_today(key: String) -> bool:
	## True if the one-per-day thing called `key` was already done today.
	return bool(daily_flags.get(key, false))


func set_flag_today(key: String) -> void:
	daily_flags[key] = true
	save_data()


# ------------------------------------------------- coins and inventory

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	save_data()
	inventory_changed.emit()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false

	coins -= amount
	save_data()
	inventory_changed.emit()
	return true


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = item_count(item_id) + amount
	save_data()
	inventory_changed.emit()


func remove_item(item_id: String) -> bool:
	var have := item_count(item_id)
	if have <= 0:
		return false

	if have == 1:
		inventory.erase(item_id)
	else:
		inventory[item_id] = have - 1

	save_data()
	inventory_changed.emit()
	return true


func owned_item_ids() -> Array:
	## Item ids you hold at least one of, in the order items.json lists them.
	var result: Array = []

	for item in CharacterDB.get_all_items():
		var id := str(item.get("id", ""))
		if item_count(id) > 0:
			result.append(id)

	return result


func record_taste(character_id: String, item_id: String, tier: String) -> void:
	## Remember what the player has learned about a character's tastes.
	if not known_tastes.has(character_id):
		known_tastes[character_id] = {}

	known_tastes[character_id][item_id] = tier
	save_data()


# ------------------------------------------------------- save / load

func reset_all() -> void:
	scores.clear()
	unlocked_events.clear()
	acted_today.clear()
	known_tastes.clear()
	daily_flags.clear()
	board = {}
	inventory = STARTING_ITEMS.duplicate()
	coins = STARTING_COINS
	current_day = 1
	save_data()
	inventory_changed.emit()


func save_data() -> void:
	var payload := {
		"scores": scores,
		"unlocked_events": unlocked_events,
		"acted_today": acted_today,
		"current_day": current_day,
		"coins": coins,
		"inventory": inventory,
		"known_tastes": known_tastes,
		"daily_flags": daily_flags,
		"board": board,
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

	# Older saves have no coins or items: start those fresh.
	coins = int(parsed.get("coins", STARTING_COINS))

	inventory.clear()
	if parsed.has("inventory"):
		var saved_inventory: Dictionary = parsed.get("inventory", {})
		for id in saved_inventory.keys():
			inventory[str(id)] = int(saved_inventory[id])
	else:
		inventory = STARTING_ITEMS.duplicate()

	known_tastes = parsed.get("known_tastes", {})
	daily_flags = parsed.get("daily_flags", {})
	board = parsed.get("board", {})

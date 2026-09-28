extends Node
## CharacterDB (autoload)
##
## Loads all game content from JSON at startup:
##   - res://data/personalities.json             (personality traits + their tag tastes)
##   - res://data/items.json                     (giftable items, each with tags)
##   - res://data/characters/<id>/character.json (identity, personality, idle dialogue)
##   - res://data/characters/<id>/gifts.json     (optional: gift overrides + reaction lines)
##   - res://data/characters/<id>/events/*.json  (the 4/8/10 heart/skull scenes)
##
## GIFTS: a character has 1-3 personality traits. Each trait loves and
## dislikes certain item TAGS, so the game works out how a character feels
## about every item automatically. The first trait counts double. A
## character's gifts.json can override individual items ("loves", "likes",
## "dislikes", "hates") for personal quirks.
##
## Drop a correctly-shaped character folder in and the game finds it --
## no code changes needed. See docs/CHARACTER_TEMPLATE.md for the format.

const CHARACTERS_PATH := "res://data/characters/"
const ITEMS_PATH := "res://data/items.json"
const PERSONALITIES_PATH := "res://data/personalities.json"
const EVENT_KEYS := ["heart_4", "heart_8", "heart_10", "skull_4", "skull_8", "skull_10"]

var characters: Dictionary = {} # id (String) -> character data (Dictionary)
var items: Dictionary = {}      # item id (String) -> item data (Dictionary)
var personalities: Dictionary = {} # trait id (String) -> trait data (Dictionary)
var valid_tags: Array = []      # every tag name personalities.json allows
var _item_order: Array = []     # keeps items in the order items.json lists them

# Score needed for each reaction (see get_gift_score).
const LOVE_MIN := 3
const LIKE_MIN := 1
const DISLIKE_MAX := -1
const HATE_MAX := -3

# gifts.json override list name -> reaction tier
const OVERRIDE_TIERS := {
	"loves": "love",
	"likes": "like",
	"dislikes": "dislike",
	"hates": "hate",
}


func _ready() -> void:
	load_personalities()
	load_items()
	load_all_characters()


# -------------------------------------------------------- personalities

func load_personalities() -> void:
	personalities.clear()

	var data := _load_json(PERSONALITIES_PATH)
	var tags: Array = data.get("tags", [])
	valid_tags = tags

	var list: Array = data.get("traits", [])
	for entry in list:
		if entry is Dictionary and entry.has("id"):
			personalities[str(entry["id"])] = entry


# ---------------------------------------------------------------- items

func load_items() -> void:
	items.clear()
	_item_order.clear()

	var data := _load_json(ITEMS_PATH)
	var list: Array = data.get("items", [])

	for entry in list:
		if entry is Dictionary and entry.has("id"):
			items[entry["id"]] = entry
			_item_order.append(entry["id"])

			var item_tags: Array = entry.get("tags", [])
			if item_tags.is_empty():
				push_warning("CharacterDB: item '%s' has no tags (everyone will feel neutral about it)" % entry["id"])

			for tag in item_tags:
				if not valid_tags.has(tag):
					push_warning("CharacterDB: item '%s' uses unknown tag '%s'" % [entry["id"], tag])


func get_all_items() -> Array:
	var result: Array = []
	for id in _item_order:
		result.append(items[id])
	return result


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


# ----------------------------------------------------------- characters

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
	data["gift_data"] = _load_json(folder_path.path_join("gifts.json"))

	characters[data["id"]] = data
	_validate_character(data, folder_path)


func _validate_character(data: Dictionary, folder_path: String) -> void:
	# Friendly warnings (shown in Godot's Output panel) for anything a
	# submitted character is missing. Nothing here blocks loading.
	var id := str(data.get("id", ""))

	if id != folder_path.get_file():
		push_warning("CharacterDB: id '%s' does not match its folder name '%s'" % [id, folder_path.get_file()])

	for key in ["name", "alignment", "status"]:
		if not data.has(key):
			push_warning("CharacterDB: '%s' is missing \"%s\" in character.json" % [id, key])

	var events: Dictionary = data.get("events", {})
	for key in EVENT_KEYS:
		if not events.has(key):
			push_warning("CharacterDB: '%s' is missing events/%s.json" % [id, key])

	var traits := get_personality(id)
	if traits.is_empty():
		push_warning("CharacterDB: '%s' has no \"personality\" (gifts will all feel neutral)" % id)
	if traits.size() > 3:
		push_warning("CharacterDB: '%s' has more than 3 personality traits" % id)
	for trait_id in traits:
		if not personalities.has(str(trait_id)):
			push_warning("CharacterDB: '%s' has unknown personality trait '%s'" % [id, trait_id])


func _load_events(events_path: String) -> Dictionary:
	var events: Dictionary = {}
	var dir := DirAccess.open(events_path)

	if dir == null:
		return events

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
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if parsed is Dictionary:
		return parsed

	push_warning("CharacterDB: failed to parse JSON at %s (check for a missing comma or quote)" % path)
	return {}


func get_character(id: String) -> Dictionary:
	return characters.get(id, {})


func get_event(id: String, event_key: String) -> Dictionary:
	var character := get_character(id)
	var events: Dictionary = character.get("events", {})
	return events.get(event_key, {})


func get_all_ids() -> Array:
	return characters.keys()


# ------------------------------------------------------------------ art

func get_art_path(id: String, kind: String) -> String:
	## Finds a character's "sprite" or "portrait" image. Tries the path in
	## character.json first, then falls back to the naming convention
	##   res://assets/characters/npcs/sprites/<id>.png
	##   res://assets/characters/npcs/portraits/<id>.png
	## Returns "" if no image exists (callers then use a placeholder).
	var data := get_character(id)
	var explicit := str(data.get(kind, ""))

	if explicit != "" and not explicit.begins_with("res://"):
		explicit = "res://" + explicit

	if explicit != "" and ResourceLoader.exists(explicit):
		return explicit

	var folder := "sprites" if kind == "sprite" else "portraits"
	var conventional := "res://assets/characters/npcs/%s/%s.png" % [folder, id]

	if ResourceLoader.exists(conventional):
		return conventional

	return ""


# ----------------------------------------------------------------- gifts

func get_personality(character_id: String) -> Array:
	## The character's trait ids, e.g. ["cheerful", "compassionate"].
	## Read from character.json, or from gifts.json if it isn't there.
	var data := get_character(character_id)
	var traits: Array = data.get("personality", [])

	if traits.is_empty():
		var gift_data: Dictionary = data.get("gift_data", {})
		traits = gift_data.get("personality", [])

	return traits


func get_primary_trait(character_id: String) -> Dictionary:
	var traits := get_personality(character_id)

	if traits.is_empty():
		return {}

	return personalities.get(str(traits[0]), {})


func get_gift_score(character_id: String, item_id: String) -> int:
	## Adds up how well an item's tags match the character's traits.
	## For each tag: +1 if the trait loves it, -1 if it dislikes it. The
	## first (primary) trait counts double, so a character with mixed
	## traits leans toward their main one instead of cancelling out.
	var item_tags: Array = get_item(item_id).get("tags", [])
	var traits := get_personality(character_id)
	var total := 0

	for i in traits.size():
		var trait_data: Dictionary = personalities.get(str(traits[i]), {})
		var loves: Array = trait_data.get("loves", [])
		var dislikes: Array = trait_data.get("dislikes", [])
		var weight := 2 if i == 0 else 1

		for tag in item_tags:
			if loves.has(tag):
				total += weight
			elif dislikes.has(tag):
				total -= weight

	return total


func get_gift_tier(character_id: String, item_id: String) -> String:
	## "love", "like", "neutral", "dislike" or "hate".
	# 1. A character's own gifts.json overrides win.
	var gift_data: Dictionary = get_character(character_id).get("gift_data", {})

	for list_key in OVERRIDE_TIERS.keys():
		var list: Array = gift_data.get(list_key, [])
		if list.has(item_id):
			return str(OVERRIDE_TIERS[list_key])

	# 2. Otherwise it comes from their personality.
	var score := get_gift_score(character_id, item_id)

	if score >= LOVE_MIN:
		return "love"
	if score >= LIKE_MIN:
		return "like"
	if score <= HATE_MAX:
		return "hate"
	if score <= DISLIKE_MAX:
		return "dislike"

	return "neutral"


func get_gift_reaction(character_id: String, tier: String) -> String:
	## What the character says about a gift. Their own gifts.json line wins,
	## then their primary trait's line. "" means "use the game's default".
	var gift_data: Dictionary = get_character(character_id).get("gift_data", {})
	var own: Dictionary = gift_data.get("reactions", {})

	if own.has(tier):
		return str(own[tier])

	var trait_reactions: Dictionary = get_primary_trait(character_id).get("reactions", {})

	if trait_reactions.has(tier):
		return str(trait_reactions[tier])

	return ""


func get_rude_reactions(character_id: String) -> Array:
	## Lines the character might say when insulted. Own lines win, then
	## their primary trait's. An empty array means "use the game's default".
	var gift_data: Dictionary = get_character(character_id).get("gift_data", {})
	var own: Array = gift_data.get("rude_reactions", [])

	if not own.is_empty():
		return own

	var from_trait: Array = get_primary_trait(character_id).get("rude_reactions", [])
	return from_trait

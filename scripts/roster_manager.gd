extends Node
## Roster (autoload)
##
## Decides which characters currently live in town ("active") versus
## which are waiting in the wings ("pool"). When a character's case is
## called (10 hearts or 10 skulls), they depart and a random pool
## character is promoted to active in their place.
##
## This is intentionally simple (random pick from the pool) so it's
## easy to later swap in curated selection, player-influenced choice,
## or a moderation-approved queue -- without touching anything else
## that depends on Roster.

var active_ids: Array = []
var pool_ids: Array = []
var departed_ids: Array = []

signal character_departed(character_id: String)
signal character_arrived(character_id: String)


func _ready() -> void:
	_build_from_character_db()
	Relationships.case_called.connect(_on_case_called)


func _build_from_character_db() -> void:
	active_ids.clear()
	pool_ids.clear()

	for id in CharacterDB.get_all_ids():
		var status: String = CharacterDB.get_character(id).get("status", "pool")

		if status == "active":
			active_ids.append(id)
		elif status == "pool":
			pool_ids.append(id)
		# "departed" / "pending" characters are skipped at startup on purpose


func _on_case_called(character_id: String) -> void:
	if not active_ids.has(character_id):
		return

	active_ids.erase(character_id)
	departed_ids.append(character_id)
	character_departed.emit(character_id)

	_promote_random_pool_character()


func _promote_random_pool_character() -> void:
	if pool_ids.is_empty():
		push_warning("Roster: pool is empty, no one available to cycle in")
		return

	var index := randi() % pool_ids.size()
	var new_id: String = pool_ids[index]

	pool_ids.remove_at(index)
	active_ids.append(new_id)
	character_arrived.emit(new_id)

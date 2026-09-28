extends RefCounted
## MapData
##
## The layout of every place in the game, described as plain data:
##   size, colours, things to draw, solid rectangles (collision), doors to
##   other maps, "spots" the player can interact with, and where NPCs stand.
##
## main.gd reads these and does the drawing / collision / doors. To add a
## building, a decoration or a new interactable, edit this file only.
##
## Coordinates are pixels, (0, 0) = top-left of the map, y grows downward.
## Every map gets a solid border wall automatically.
##
## Rules of thumb used below:
##  - A door TRIGGER is the small rectangle that moves you to another map
##    when you walk into it. Spawn points must sit OUTSIDE the trigger
##    you arrive from, or you'd bounce straight back.
##  - The player's collision box is 32x48, so their centre can get no
##    closer than 24px to a wall's face.

const WALL := 32.0

static var _cache: Dictionary = {}


static func get_map(map_id: String) -> Dictionary:
	if not _cache.has(map_id):
		match map_id:
			"room":
				_cache[map_id] = _build_room()
			"town":
				_cache[map_id] = _build_town()
			"lost_and_found":
				_cache[map_id] = _build_lost_and_found()
			"pub":
				_cache[map_id] = _build_pub()
			"bureau":
				_cache[map_id] = _build_bureau()
			_:
				push_error("MapData: unknown map '%s'" % map_id)
				_cache[map_id] = _build_room()

	return _cache[map_id]


# ------------------------------------------------------------- helpers

static func _new_map(size: Vector2, floor_color: Color, border_color: Color) -> Dictionary:
	return {
		"size": size,
		"floor": floor_color,
		"border": border_color,
		"draw": [],
		"solids": [],
		"doors": [],
		"interactables": [],
		"npc_slots": [],
		"station_slots": [],
		"gates": {},
	}


static func _rect(m: Dictionary, r: Rect2, c: Color) -> void:
	m["draw"].append({"t": "rect", "r": r, "c": c})


static func _dot(m: Dictionary, p: Vector2, radius: float, c: Color) -> void:
	m["draw"].append({"t": "circle", "p": p, "radius": radius, "c": c})


static func _label(m: Dictionary, p: Vector2, s: String, size: int = 16) -> void:
	m["draw"].append({"t": "text", "p": p, "s": s, "size": size})


static func _solid(m: Dictionary, r: Rect2) -> void:
	m["solids"].append(r)


static func _door(m: Dictionary, r: Rect2, to: String, spawn: Vector2) -> void:
	m["doors"].append({"rect": r, "to": to, "spawn": spawn})


static func _spot(m: Dictionary, id: String, kind: String, pos: Vector2, radius: float, prompt: String, extra: Dictionary = {}) -> void:
	var entry := {"id": id, "kind": kind, "pos": pos, "radius": radius, "prompt": prompt}
	entry.merge(extra)
	m["interactables"].append(entry)


static func _exit_door(m: Dictionary, to: String, spawn: Vector2) -> void:
	# A doorway in the bottom wall of an interior.
	var size: Vector2 = m["size"]
	var cx := size.x / 2.0
	_rect(m, Rect2(cx - 45, size.y - 78, 90, 46), Color("c4a574"))
	_label(m, Vector2(cx, size.y - 90), "Exit", 14)
	_door(m, Rect2(cx - 50, size.y - 84, 100, 44), to, spawn)


static func _building(m: Dictionary, r: Rect2, color: Color, title: String, door_to: String = "", spawn: Vector2 = Vector2(0, 0)) -> void:
	# An exterior building: solid body, roof, door, windows, name sign.
	# If door_to is given, walking into the door (just below the building)
	# takes you to that interior, arriving at `spawn`.
	_rect(m, r, color)
	_rect(m, Rect2(r.position - Vector2(12, 12), Vector2(r.size.x + 24, 40)), color.darkened(0.3))
	_rect(m, Rect2(r.position.x + r.size.x / 2.0 - 24, r.end.y - 60, 48, 60), Color("30282a"))
	_rect(m, Rect2(r.position.x + 36, r.position.y + 64, 46, 40), Color("c4d6c8"))
	_rect(m, Rect2(r.end.x - 82, r.position.y + 64, 46, 40), Color("c4d6c8"))
	_label(m, Vector2(r.position.x + r.size.x / 2.0, r.position.y - 20), title, 18)
	_solid(m, r)

	if door_to != "":
		var cx := r.position.x + r.size.x / 2.0
		_door(m, Rect2(cx - 36, r.end.y + 16, 72, 36), door_to, spawn)


# ----------------------------------------------------- your bedroom

static func _build_room() -> Dictionary:
	var m := _new_map(Vector2(800, 600), Color("40384f"), Color("24202e"))

	# Rug
	_rect(m, Rect2(275, 180, 250, 180), Color("694a78"))

	# Bed
	_rect(m, Rect2(80, 80, 130, 210), Color("252030"))
	_rect(m, Rect2(92, 92, 106, 55), Color("d8cee5"))
	_solid(m, Rect2(80, 80, 130, 210))
	_spot(m, "bed", "bed", Vector2(145, 340), 95.0, "Sleep until tomorrow")

	# Table
	_dot(m, Vector2(650, 200), 65, Color("76513b"))
	_solid(m, Rect2(590, 140, 120, 120))

	_label(m, Vector2(400, 80), "Your Room", 18)
	_exit_door(m, "town", Vector2(1100, 1400))
	return m


# ------------------------------------------------------------- town

static func _build_town() -> Dictionary:
	var m := _new_map(Vector2(2200, 1500), Color("536b4c"), Color("29312a"))

	# --- paths and the central plaza
	var path := Color("a58d70")
	_rect(m, Rect2(1050, 32, 100, 1436), path)
	_rect(m, Rect2(32, 700, 2136, 100), path)
	_dot(m, Vector2(1100, 750), 190, Color("b5a488"))

	# --- the Reflecting Pool (a solid square around the round pool)
	_dot(m, Vector2(1100, 750), 62, Color("4c7184"))
	_dot(m, Vector2(1100, 750), 34, Color("7fb4c9"))
	_solid(m, Rect2(1050, 700, 100, 100))
	_label(m, Vector2(1100, 880), "The Reflecting Pool", 16)
	_spot(m, "pool", "pool", Vector2(1100, 750), 100.0, "Look into the Reflecting Pool")

	# --- buildings you can enter
	_building(m, Rect2(330, 120, 300, 180), Color("66547c"), "Lost & Found", "lost_and_found", Vector2(360, 390))
	_building(m, Rect2(930, 110, 340, 200), Color("4d6573"), "Bureau of Case Review", "bureau", Vector2(400, 430))
	_building(m, Rect2(330, 1000, 320, 200), Color("73583f"), "The Pub", "pub", Vector2(380, 430))
	_building(m, Rect2(1000, 1150, 200, 150), Color("7a4e55"), "Your Lodgings", "room", Vector2(400, 470))

	# --- the chapel: half-built and never finished
	var chapel := Rect2(1600, 130, 300, 200)
	_rect(m, chapel, Color("cfc8b6"))
	_rect(m, Rect2(1588, 118, 160, 40), Color("6b5b4b"))
	_rect(m, Rect2(1748, 118, 6, 90), Color("8a6a45"))
	_rect(m, Rect2(1830, 118, 6, 90), Color("8a6a45"))
	_rect(m, Rect2(1740, 118, 110, 6), Color("8a6a45"))
	_rect(m, Rect2(1725, 250, 50, 80), Color("30282a"))
	_rect(m, Rect2(1640, 190, 40, 50), Color("a9b8c4"))
	_rect(m, Rect2(1810, 300, 60, 30), Color("9d958a"))
	_label(m, Vector2(1750, 100), "The Chapel (unfinished)", 18)
	_solid(m, chapel)
	_spot(m, "candle", "candle", Vector2(1750, 372), 80.0, "Light a prayer candle")

	# --- notice board
	_rect(m, Rect2(870, 930, 90, 70), Color("76513b"))
	_rect(m, Rect2(880, 940, 22, 28), Color("e8e2d0"))
	_rect(m, Rect2(910, 944, 22, 30), Color("e8e2d0"))
	_rect(m, Rect2(934, 940, 20, 22), Color("e8e2d0"))
	_label(m, Vector2(915, 920), "Notices", 16)
	_solid(m, Rect2(870, 930, 90, 70))
	_spot(m, "board", "board", Vector2(915, 1030), 80.0, "Read the notice board")

	# --- the two gates
	_rect(m, Rect2(36, 640, 110, 220), Color("d9d2b8"))
	_rect(m, Rect2(52, 660, 78, 180), Color("fff7c9"))
	_label(m, Vector2(90, 625), "Bright Gate", 16)
	_spot(m, "gate_bright", "gate", Vector2(190, 750), 90.0, "Approach the Bright Gate", {"gate": "bright"})

	_rect(m, Rect2(2054, 640, 110, 220), Color("4a2a26"))
	_rect(m, Rect2(2070, 660, 78, 180), Color("ff7a3c"))
	_label(m, Vector2(2110, 625), "Ember Gate", 16)
	_spot(m, "gate_ember", "gate", Vector2(2010, 750), 90.0, "Approach the Ember Gate", {"gate": "ember"})

	m["gates"] = {"bright": Vector2(100, 750), "ember": Vector2(2100, 750)}

	# --- arrival station (newcomers stand here on the day they arrive)
	_rect(m, Rect2(1700, 1120, 420, 70), Color("8a8478"))
	_rect(m, Rect2(1650, 1215, 520, 14), Color("5c564e"))
	_rect(m, Rect2(1650, 1245, 520, 14), Color("5c564e"))
	for i in range(11):
		_rect(m, Rect2(1660 + i * 48, 1210, 8, 54), Color("4b3b2b"))
	_rect(m, Rect2(1690, 1050, 130, 34), Color("3b4a5a"))
	_label(m, Vector2(1755, 1074), "ARRIVALS", 16)
	m["station_slots"] = [Vector2(1900, 1090), Vector2(2010, 1090)]

	# --- memorial garden (headstones are drawn from the roster in main.gd)
	_rect(m, Rect2(1420, 880, 380, 210), Color("4a5f47"))
	_rect(m, Rect2(1420, 880, 380, 6), Color("6b5b4b"))
	_rect(m, Rect2(1420, 1084, 380, 6), Color("6b5b4b"))
	_rect(m, Rect2(1420, 880, 6, 210), Color("6b5b4b"))
	_rect(m, Rect2(1794, 880, 6, 210), Color("6b5b4b"))
	_label(m, Vector2(1610, 866), "Memorial Garden", 16)
	_spot(m, "memorial", "memorial", Vector2(1395, 985), 90.0, "Read the markers")

	# --- the creek (fishing for lost things) along the south edge
	_rect(m, Rect2(32, 1400, 880, 68), Color("3f6d8a"))
	_rect(m, Rect2(120, 1425, 90, 5), Color("6fa3c0"))
	_rect(m, Rect2(420, 1445, 120, 5), Color("6fa3c0"))
	_rect(m, Rect2(700, 1420, 100, 5), Color("6fa3c0"))
	_solid(m, Rect2(32, 1400, 880, 68))
	_label(m, Vector2(470, 1385), "The Creek", 16)
	_spot(m, "creek", "creek", Vector2(600, 1372), 100.0, "Fish for lost things")

	# --- the junkyard (north-east)
	_rect(m, Rect2(1960, 60, 190, 340), Color("4a4640"))
	_dot(m, Vector2(2040, 180), 34, Color("6e6a62"))
	_dot(m, Vector2(2085, 260), 28, Color("5c5850"))
	_dot(m, Vector2(2030, 330), 38, Color("6e6a62"))
	_label(m, Vector2(2055, 45), "Junkyard", 16)
	_solid(m, Rect2(1990, 140, 120, 220))
	_spot(m, "junk", "junk", Vector2(1935, 260), 100.0, "Dig through the junk")

	# --- foraging patches
	for i in range(8):
		_dot(m, Vector2(215 + (i % 4) * 22, 460 + (i / 4) * 28), 9, Color("e8b4d8") if i % 2 == 0 else Color("f2e28c"))
	_label(m, Vector2(250, 430), "Meadow", 16)
	_spot(m, "meadow", "forage", Vector2(250, 480), 90.0, "Pick wildflowers", {"item": "wildflowers", "name": "the meadow"})

	for i in range(7):
		_dot(m, Vector2(1945 + (i % 4) * 22, 500 + (i / 4) * 26), 10, Color("5f8f4f"))
	_label(m, Vector2(1985, 470), "Herb Patch", 16)
	_spot(m, "herbs", "forage", Vector2(1980, 520), 90.0, "Gather herbs", {"item": "herbal_tea", "name": "the herb patch"})

	# --- where residents stand (one spot each; more residents than spots stay away)
	m["npc_slots"] = [
		Vector2(600, 360),
		Vector2(1260, 380),
		Vector2(1660, 390),
		Vector2(640, 1250),
		Vector2(1330, 780),
		Vector2(870, 780),
		Vector2(1310, 1250),
	]
	return m


# ------------------------------------------------- Lost & Found (shop)

static func _build_lost_and_found() -> Dictionary:
	var m := _new_map(Vector2(720, 520), Color("5a4a3a"), Color("2b2119"))

	# shelves crowded with other people's things
	_rect(m, Rect2(40, 70, 110, 300), Color("3b2c20"))
	_rect(m, Rect2(570, 70, 110, 300), Color("3b2c20"))
	_solid(m, Rect2(40, 70, 110, 300))
	_solid(m, Rect2(570, 70, 110, 300))
	for i in range(6):
		_rect(m, Rect2(52, 82 + i * 48, 86, 22), Color("8a6f52") if i % 2 == 0 else Color("6d8a7a"))
		_rect(m, Rect2(582, 82 + i * 48, 86, 22), Color("6d8a7a") if i % 2 == 0 else Color("8a6f52"))

	# counter and clerk
	_dot(m, Vector2(360, 100), 24, Color("e8c39e"))
	_rect(m, Rect2(338, 118, 44, 30), Color("4a5f7a"))
	_rect(m, Rect2(240, 150, 240, 56), Color("76513b"))
	_solid(m, Rect2(240, 150, 240, 56))
	_label(m, Vector2(360, 60), "LOST & FOUND", 18)
	_spot(m, "clerk", "shop", Vector2(360, 245), 90.0, "Talk to the clerk")

	_exit_door(m, "town", Vector2(480, 400))
	return m


# ---------------------------------------------------------------- pub

static func _build_pub() -> Dictionary:
	var m := _new_map(Vector2(760, 560), Color("4a3626"), Color("2a1d14"))

	# bottles on the wall, then the bar
	_rect(m, Rect2(80, 50, 400, 30), Color("6b4a30"))
	for i in range(8):
		_rect(m, Rect2(96 + i * 48, 54, 14, 22), Color("7fa88a") if i % 2 == 0 else Color("a8794f"))
	_rect(m, Rect2(60, 90, 440, 52), Color("76513b"))
	_solid(m, Rect2(60, 90, 440, 52))
	for i in range(5):
		_dot(m, Vector2(110 + i * 80, 185), 14, Color("3b2a1e"))
	_spot(m, "bar", "drink", Vector2(280, 230), 100.0, "Order a drink (3 coins)")

	# the dice table in the back
	_dot(m, Vector2(600, 320), 65, Color("2f5a3f"))
	_dot(m, Vector2(600, 320), 55, Color("3f7a52"))
	_solid(m, Rect2(540, 260, 120, 120))
	_rect(m, Rect2(585, 305, 14, 14), Color("f2efe2"))
	_rect(m, Rect2(610, 322, 14, 14), Color("f2efe2"))
	_label(m, Vector2(600, 235), "Bone Dice", 16)
	_spot(m, "dice", "dice", Vector2(600, 415), 95.0, "Play Bone Dice")

	_label(m, Vector2(280, 40), "THE PUB", 18)
	_exit_door(m, "town", Vector2(490, 1300))
	return m


# ------------------------------------------------------------- bureau

static func _build_bureau() -> Dictionary:
	var m := _new_map(Vector2(800, 560), Color("4d5563"), Color("2a2d36"))

	# filing cabinets, a great many of them
	_rect(m, Rect2(50, 60, 60, 220), Color("6c7180"))
	_rect(m, Rect2(690, 60, 60, 220), Color("6c7180"))
	_rect(m, Rect2(50, 320, 60, 120), Color("6c7180"))
	_rect(m, Rect2(690, 320, 60, 120), Color("6c7180"))
	_solid(m, Rect2(50, 60, 60, 220))
	_solid(m, Rect2(690, 60, 60, 220))
	_solid(m, Rect2(50, 320, 60, 120))
	_solid(m, Rect2(690, 320, 60, 120))
	for i in range(5):
		_rect(m, Rect2(58, 70 + i * 42, 44, 8), Color("a9adbb"))
		_rect(m, Rect2(698, 70 + i * 42, 44, 8), Color("a9adbb"))

	# the desk and its clerk
	_dot(m, Vector2(400, 95), 24, Color("e8c39e"))
	_rect(m, Rect2(378, 113, 44, 32), Color("3b3f4d"))
	_rect(m, Rect2(300, 140, 200, 50), Color("76513b"))
	_solid(m, Rect2(300, 140, 200, 50))
	_label(m, Vector2(400, 50), "BUREAU OF CASE REVIEW", 18)
	_spot(m, "desk", "bureau_desk", Vector2(400, 235), 100.0, "Speak to the clerk")

	# a take-a-number machine
	_rect(m, Rect2(180, 380, 50, 46), Color("b8433f"))
	_solid(m, Rect2(180, 380, 50, 46))
	_label(m, Vector2(205, 372), "Take a number", 14)
	_spot(m, "number", "number", Vector2(205, 460), 80.0, "Take a number")

	_exit_door(m, "town", Vector2(1100, 410))
	return m

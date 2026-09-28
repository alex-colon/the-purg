extends Node2D
## Main
##
## Runs the world: loads a map from MapData, draws it, builds its walls,
## moves you through doors, follows you with the camera, finds the spot
## you're standing at, and places the residents. Menus and what each spot
## does live in menu_ui.gd and town_actions.gd.

const MapData := preload("res://scripts/map_data.gd")
const MenuUI := preload("res://scripts/menu_ui.gd")
const TownActions := preload("res://scripts/town_actions.gd")
const NPC_SCENE := preload("res://scenes/npc.tscn")

const WALL_THICKNESS := 32.0
const LEAVE_SPEED := 170.0            # px/second when a resident walks to their gate
const MEMORIAL_ORIGIN := Vector2(1452, 935) # first headstone in the Memorial Garden
const MEMORIAL_COLUMNS := 6

@onready var player: CharacterBody2D = $Player

var current_map_id: String = "room"
var menu: MenuUI
var actions: TownActions

var _map: Dictionary = {}
var _walls: Node2D
var _npcs: Node2D
var _npc_slots: Dictionary = {}    # character id -> index into the town's npc_slots
var _spot: Dictionary = {}         # the interactable the player is standing at, if any
var _transitioning: bool = false
var _sleeping: bool = false

var _camera: Camera2D
var _day_label: Label
var _coin_label: Label
var _toast_label: Label
var _prompt_label: Label
var _fade: ColorRect
var _toast_tween: Tween


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("17131f"))

	menu = MenuUI.new()
	add_child(menu)
	actions = TownActions.new(self, menu)

	_build_hud()
	_build_camera()
	_update_day_label()
	_update_coin_label()

	Relationships.day_changed.connect(_on_day_changed)
	Relationships.inventory_changed.connect(_update_coin_label)
	Roster.character_departed.connect(_on_character_departed)
	Roster.character_arrived.connect(_on_character_arrived)

	_load_map("room", Vector2(400, 470))


# ----------------------------------------------------------------- HUD

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)

	_day_label = _make_hud_label(22)
	_day_label.position = Vector2(16, 10)
	hud.add_child(_day_label)

	_coin_label = _make_hud_label(18)
	_coin_label.position = Vector2(16, 42)
	hud.add_child(_coin_label)

	_toast_label = _make_hud_label(16)
	_toast_label.position = Vector2(16, 74)
	_toast_label.modulate.a = 0.0
	hud.add_child(_toast_label)

	_prompt_label = _make_hud_label(20)
	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_top = -70.0
	_prompt_label.offset_bottom = -30.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(_prompt_label)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_hud_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label


func _update_day_label() -> void:
	_day_label.text = "Day %d" % Relationships.current_day


func _update_coin_label() -> void:
	_coin_label.text = "Coins: %d" % Relationships.coins


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0

	if _toast_tween != null:
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_interval(4.5)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.8)


func is_ui_open() -> bool:
	## True while something (a menu, a conversation, a fade) should stop the
	## player from walking around.
	return _transitioning or _sleeping or DialogueBox.is_open() or menu.is_open()


# -------------------------------------------------------------- camera

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 9.0
	player.add_child(_camera)
	_camera.make_current()


func _set_camera_limits() -> void:
	var size: Vector2 = _map["size"]
	var view := get_viewport_rect().size

	# If a map is smaller than the screen on one axis, centre it on that axis.
	var left := 0.0
	var right := size.x
	if size.x < view.x:
		left = size.x / 2.0 - view.x / 2.0
		right = size.x / 2.0 + view.x / 2.0

	var top := 0.0
	var bottom := size.y
	if size.y < view.y:
		top = size.y / 2.0 - view.y / 2.0
		bottom = size.y / 2.0 + view.y / 2.0

	_camera.limit_left = int(left)
	_camera.limit_right = int(right)
	_camera.limit_top = int(top)
	_camera.limit_bottom = int(bottom)


# ---------------------------------------------------------------- maps

func _load_map(map_id: String, spawn: Vector2) -> void:
	current_map_id = map_id
	_map = MapData.get_map(map_id)
	player.position = spawn

	_build_collision()
	_reset_npcs()
	if map_id == "town":
		spawn_npcs()

	_set_camera_limits()
	_camera.reset_smoothing()
	_spot = {}
	_update_prompt()
	queue_redraw()


func _build_collision() -> void:
	if is_instance_valid(_walls):
		_walls.free()

	_walls = Node2D.new()
	_walls.name = "Walls"
	add_child(_walls)

	var size: Vector2 = _map["size"]
	_add_solid(Rect2(0, 0, size.x, WALL_THICKNESS))
	_add_solid(Rect2(0, size.y - WALL_THICKNESS, size.x, WALL_THICKNESS))
	_add_solid(Rect2(0, 0, WALL_THICKNESS, size.y))
	_add_solid(Rect2(size.x - WALL_THICKNESS, 0, WALL_THICKNESS, size.y))

	for rect in _map["solids"]:
		_add_solid(rect)


func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	_walls.add_child(body)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)


func _transition_to(map_id: String, spawn: Vector2) -> void:
	if _transitioning:
		return

	_transitioning = true
	player.set_physics_process(false)

	var fade_out := create_tween()
	fade_out.tween_property(_fade, "color:a", 1.0, 0.18)
	await fade_out.finished

	_load_map(map_id, spawn)

	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, 0.18)
	await fade_in.finished

	player.set_physics_process(true)
	_transitioning = false


func _process(_delta: float) -> void:
	if _transitioning or _map.is_empty():
		return

	for door in _map["doors"]:
		var rect: Rect2 = door["rect"]
		if rect.has_point(player.position):
			_transition_to(str(door["to"]), door["spawn"])
			return

	_update_spot()


# --------------------------------------------------- interactable spots

func _update_spot() -> void:
	var best := {}

	if not is_ui_open():
		var best_distance := INF

		for spot in _map["interactables"]:
			var distance := player.position.distance_to(spot["pos"])
			if distance <= float(spot["radius"]) and distance < best_distance:
				best = spot
				best_distance = distance

	if best != _spot:
		_spot = best
		_update_prompt()


func _update_prompt() -> void:
	if _spot.is_empty():
		_prompt_label.text = ""
	else:
		_prompt_label.text = "[Enter] %s" % str(_spot["prompt"])


func _unhandled_input(event: InputEvent) -> void:
	# F9: wipe all saved progress and restart (handy while testing).
	if event is InputEventKey:
		var key := event as InputEventKey

		if key.pressed and not key.echo and key.keycode == KEY_F9:
			_reset_progress()
			return

	if event.is_action_pressed("ui_accept") and not is_ui_open() and not _spot.is_empty():
		get_viewport().set_input_as_handled()

		if str(_spot["kind"]) == "bed":
			_sleep()
		else:
			actions.run(_spot)


func _reset_progress() -> void:
	DialogueBox.hide_dialogue()
	menu.close()
	Relationships.reset_all()
	Roster.reset_all()
	get_tree().reload_current_scene()


# ------------------------------------------------------ days and sleep

func _on_day_changed(_day: int) -> void:
	_update_day_label()


func _sleep() -> void:
	if _sleeping:
		return

	_sleeping = true
	player.set_physics_process(false)

	var fade_out := create_tween()
	fade_out.tween_property(_fade, "color:a", 1.0, 0.6)
	await fade_out.finished

	Relationships.start_new_day()
	await get_tree().create_timer(0.5).timeout

	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, 0.6)
	await fade_in.finished

	player.set_physics_process(true)
	_sleeping = false


# ----------------------------------------------------------- residents

func _display_name(character_id: String) -> String:
	return str(CharacterDB.get_character(character_id).get("name", character_id))


func _on_character_arrived(character_id: String) -> void:
	show_toast("%s has arrived at the station." % _display_name(character_id))

	if current_map_id == "town":
		spawn_npcs()


func _on_character_departed(character_id: String) -> void:
	show_toast("%s's case has been called. They're heading for the gate." % _display_name(character_id))
	queue_redraw() # the Memorial Garden gets a new headstone

	if current_map_id != "town":
		return

	var resident := _find_npc(character_id)
	if resident == null:
		return

	# Let them walk to their gate instead of vanishing.
	_npc_slots.erase(character_id)
	var record: Dictionary = Roster.departures.get(character_id, {})
	var gates: Dictionary = _map["gates"]
	var target: Vector2 = gates.get(str(record.get("gate", "bright")), Vector2(100, 750))
	var seconds := clampf(resident.position.distance_to(target) / LEAVE_SPEED, 2.0, 10.0)
	resident.call("leave_toward", target, seconds)


func _find_npc(character_id: String) -> Node2D:
	if not is_instance_valid(_npcs):
		return null

	for child in _npcs.get_children():
		if str(child.get("character_id")) == character_id:
			return child as Node2D

	return null


func _reset_npcs() -> void:
	if is_instance_valid(_npcs):
		_npcs.free()

	_npcs = Node2D.new()
	_npcs.name = "NPCs"
	add_child(_npcs)


func _arrived_today(character_id: String) -> bool:
	return int(Roster.arrival_days.get(character_id, 0)) == Relationships.current_day


func spawn_npcs() -> void:
	_reset_npcs()

	if current_map_id != "town":
		return

	_assign_slots()

	var slots: Array = _map["npc_slots"]
	var station: Array = _map["station_slots"]
	var station_index := 0

	for id in Roster.active_ids:
		var spot := Vector2.ZERO

		if _arrived_today(str(id)):
			# Today's newcomers wait at the arrival station.
			if station_index >= station.size():
				continue
			spot = station[station_index]
			station_index += 1
		elif _npc_slots.has(id):
			spot = slots[_npc_slots[id]]
		else:
			continue # more residents than places to stand

		var npc := NPC_SCENE.instantiate()
		npc.character_id = id
		npc.position = spot
		_npcs.add_child(npc)


func _assign_slots() -> void:
	var slots: Array = _map["npc_slots"]

	# Free the spots of anyone who has left town...
	for id in _npc_slots.keys():
		if not Roster.active_ids.has(id):
			_npc_slots.erase(id)

	# ...then give each resident without a spot the first free one.
	for id in Roster.active_ids:
		if _npc_slots.has(id) or _arrived_today(str(id)):
			continue

		for slot in slots.size():
			if not _npc_slots.values().has(slot):
				_npc_slots[id] = slot
				break


# ------------------------------------------------------------- drawing

func _draw() -> void:
	if _map.is_empty():
		return

	var size: Vector2 = _map["size"]
	draw_rect(Rect2(Vector2.ZERO, size), _map["floor"])

	# Border walls
	var border: Color = _map["border"]
	draw_rect(Rect2(0, 0, size.x, WALL_THICKNESS), border)
	draw_rect(Rect2(0, size.y - WALL_THICKNESS, size.x, WALL_THICKNESS), border)
	draw_rect(Rect2(0, 0, WALL_THICKNESS, size.y), border)
	draw_rect(Rect2(size.x - WALL_THICKNESS, 0, WALL_THICKNESS, size.y), border)

	for cmd in _map["draw"]:
		match str(cmd["t"]):
			"rect":
				draw_rect(cmd["r"], cmd["c"])
			"circle":
				draw_circle(cmd["p"], float(cmd["radius"]), cmd["c"])
			"text":
				_draw_label(cmd["p"], str(cmd["s"]), int(cmd["size"]))

	if current_map_id == "town":
		_draw_memorial()


func _draw_label(center: Vector2, text: String, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(center.x - text_size.x / 2.0, center.y)

	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_memorial() -> void:
	# One headstone per resident who has left. Pale for the bright gate,
	# rust-red for the ember gate.
	for i in mini(Roster.departed_ids.size(), MEMORIAL_COLUMNS * 2):
		var id := str(Roster.departed_ids[i])
		var record: Dictionary = Roster.departures.get(id, {})
		var stone := Color("d9d4c4") if str(record.get("gate", "bright")) == "bright" else Color("a86a58")

		var pos := MEMORIAL_ORIGIN + Vector2((i % MEMORIAL_COLUMNS) * 58, (i / MEMORIAL_COLUMNS) * 76)
		draw_rect(Rect2(pos, Vector2(28, 38)), stone)
		draw_circle(pos + Vector2(14, 0), 14, stone)
		draw_rect(Rect2(pos + Vector2(4, 14), Vector2(20, 3)), stone.darkened(0.35))

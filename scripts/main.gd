extends Node2D

enum Map {
	ROOM,
	TOWN
}

const ROOM_SIZE := Vector2(800, 600)
const TOWN_SIZE := Vector2(1100, 640)
const WALL_THICKNESS := 32.0
const DOOR_WIDTH := 100.0

const NPC_SCENE := preload("res://scenes/npc.tscn")

# Spots in town where NPCs stand: in front of the home, shop, pub and
# office. Each character keeps the same spot for as long as they're in town.
const NPC_SPAWN_POSITIONS := [
	Vector2(215, 260),
	Vector2(885, 260),
	Vector2(215, 570),
	Vector2(885, 570),
]

# Standing near the bed lets you sleep to start a new day.
const BED_RECT := Rect2(80, 80, 130, 210)

@onready var player: CharacterBody2D = $Player

var current_map: Map = Map.ROOM
var walls: Node2D
var npcs: Node2D

var _npc_slots: Dictionary = {} # character id -> index into NPC_SPAWN_POSITIONS
var _near_bed: bool = false
var _sleeping: bool = false

var _day_label: Label
var _toast_label: Label
var _toast_tween: Tween
var _fade: ColorRect


func _ready() -> void:
	_build_hud()
	_update_day_label()

	Relationships.day_changed.connect(_on_day_changed)
	Roster.character_departed.connect(_on_character_departed)
	Roster.character_arrived.connect(_on_character_arrived)

	build_room()


# ------------------------------------------------------------ HUD

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)

	_day_label = _make_hud_label(22)
	_day_label.position = Vector2(16, 10)
	hud.add_child(_day_label)

	_toast_label = _make_hud_label(16)
	_toast_label.position = Vector2(16, 42)
	_toast_label.modulate.a = 0.0
	hud.add_child(_toast_label)

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


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0

	if _toast_tween != null:
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_interval(4.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.8)


# ------------------------------------------------- days, sleep, reset

func _on_day_changed(_day: int) -> void:
	_update_day_label()


func _on_character_departed(character_id: String) -> void:
	_show_toast("%s's case has been called. They've left town." % _display_name(character_id))

	if current_map == Map.TOWN:
		spawn_npcs()


func _on_character_arrived(character_id: String) -> void:
	_show_toast("%s has arrived in town." % _display_name(character_id))

	if current_map == Map.TOWN:
		spawn_npcs()


func _display_name(character_id: String) -> String:
	return str(CharacterDB.get_character(character_id).get("name", character_id))


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


func _unhandled_input(event: InputEvent) -> void:
	# F9: wipe all saved progress and restart (handy while testing).
	if event is InputEventKey:
		var key := event as InputEventKey

		if key.pressed and not key.echo and key.keycode == KEY_F9:
			_reset_progress()
			return

	if (
		event.is_action_pressed("ui_accept")
		and current_map == Map.ROOM
		and _near_bed
		and not _sleeping
		and not DialogueBox.is_open()
	):
		get_viewport().set_input_as_handled()
		_sleep()


func _reset_progress() -> void:
	DialogueBox.hide_dialogue()
	Relationships.reset_all()
	Roster.reset_all()
	get_tree().reload_current_scene()


func _update_bed_prompt() -> void:
	var near := current_map == Map.ROOM and BED_RECT.grow(45.0).has_point(player.position)

	if near != _near_bed:
		_near_bed = near
		queue_redraw()


# ------------------------------------------------------------- maps

func _process(_delta: float) -> void:
	if current_map == Map.ROOM and player.position.y > ROOM_SIZE.y + 30:
		enter_town()

	elif current_map == Map.TOWN and player.position.y > TOWN_SIZE.y + 30:
		enter_room()

	_update_bed_prompt()


func enter_town() -> void:
	current_map = Map.TOWN
	player.position = Vector2(TOWN_SIZE.x / 2, TOWN_SIZE.y - 70)
	build_town()
	queue_redraw()


func enter_room() -> void:
	current_map = Map.ROOM
	player.position = Vector2(ROOM_SIZE.x / 2, ROOM_SIZE.y - 70)
	build_room()
	reset_npcs()
	queue_redraw()


func reset_walls() -> void:
	if is_instance_valid(walls):
		walls.free()

	walls = Node2D.new()
	walls.name = "Walls"
	add_child(walls)


func build_room() -> void:
	reset_walls()

	# Top, left, and right walls
	create_wall(
		Vector2(ROOM_SIZE.x / 2, WALL_THICKNESS / 2),
		Vector2(ROOM_SIZE.x, WALL_THICKNESS)
	)

	create_wall(
		Vector2(WALL_THICKNESS / 2, ROOM_SIZE.y / 2),
		Vector2(WALL_THICKNESS, ROOM_SIZE.y)
	)

	create_wall(
		Vector2(ROOM_SIZE.x - WALL_THICKNESS / 2, ROOM_SIZE.y / 2),
		Vector2(WALL_THICKNESS, ROOM_SIZE.y)
	)

	create_bottom_wall_with_door(ROOM_SIZE)


func build_town() -> void:
	reset_walls()

	# Town border
	create_wall(
		Vector2(TOWN_SIZE.x / 2, WALL_THICKNESS / 2),
		Vector2(TOWN_SIZE.x, WALL_THICKNESS)
	)

	create_wall(
		Vector2(WALL_THICKNESS / 2, TOWN_SIZE.y / 2),
		Vector2(WALL_THICKNESS, TOWN_SIZE.y)
	)

	create_wall(
		Vector2(TOWN_SIZE.x - WALL_THICKNESS / 2, TOWN_SIZE.y / 2),
		Vector2(WALL_THICKNESS, TOWN_SIZE.y)
	)

	create_bottom_wall_with_door(TOWN_SIZE)
	spawn_npcs()


func reset_npcs() -> void:
	if is_instance_valid(npcs):
		npcs.free()

	npcs = Node2D.new()
	npcs.name = "NPCs"
	add_child(npcs)


func spawn_npcs() -> void:
	reset_npcs()
	_assign_slots()

	for id in Roster.active_ids:
		if not _npc_slots.has(id):
			continue # more characters than spots; the extras stay offscreen

		var npc := NPC_SCENE.instantiate()
		npc.character_id = id
		npc.position = NPC_SPAWN_POSITIONS[_npc_slots[id]]
		npcs.add_child(npc)


func _assign_slots() -> void:
	# Free the spots of anyone who has left town...
	for id in _npc_slots.keys():
		if not Roster.active_ids.has(id):
			_npc_slots.erase(id)

	# ...then give each newcomer the first free spot.
	for id in Roster.active_ids:
		if _npc_slots.has(id):
			continue

		for slot in NPC_SPAWN_POSITIONS.size():
			if not _npc_slots.values().has(slot):
				_npc_slots[id] = slot
				break


func create_bottom_wall_with_door(map_size: Vector2) -> void:
	var side_width := (map_size.x - DOOR_WIDTH) / 2.0

	create_wall(
		Vector2(side_width / 2, map_size.y - WALL_THICKNESS / 2),
		Vector2(side_width, WALL_THICKNESS)
	)

	create_wall(
		Vector2(map_size.x - side_width / 2, map_size.y - WALL_THICKNESS / 2),
		Vector2(side_width, WALL_THICKNESS)
	)


func create_wall(wall_position: Vector2, wall_size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = wall_position
	walls.add_child(wall)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()

	shape.size = wall_size
	collision.shape = shape
	wall.add_child(collision)


func _draw() -> void:
	if current_map == Map.ROOM:
		draw_room()
	else:
		draw_town()


func draw_room() -> void:
	# Floor
	draw_rect(
		Rect2(Vector2.ZERO, ROOM_SIZE),
		Color("40384f")
	)

	draw_border_with_door(ROOM_SIZE, Color("24202e"))

	# Rug
	draw_rect(
		Rect2(275, 180, 250, 180),
		Color("694a78")
	)

	# Bed
	draw_rect(
		Rect2(80, 80, 130, 210),
		Color("252030")
	)
	draw_rect(
		Rect2(92, 92, 106, 55),
		Color("d8cee5")
	)

	# Table
	draw_circle(
		Vector2(650, 200),
		65,
		Color("76513b")
	)

	if _near_bed:
		var prompt := "[Enter] Sleep until tomorrow"
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(60, 66), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color.BLACK)
		draw_string(font, Vector2(60, 66), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func draw_town() -> void:
	# Grass
	draw_rect(
		Rect2(Vector2.ZERO, TOWN_SIZE),
		Color("536b4c")
	)

	# Main paths
	var path_color := Color("a58d70")

	draw_rect(
		Rect2(500, 30, 100, 610),
		path_color
	)

	draw_rect(
		Rect2(30, 290, 1040, 100),
		path_color
	)

	# Town square
	draw_circle(
		Vector2(550, 340),
		145,
		Color("b5a488")
	)

	# Fountain
	draw_circle(
		Vector2(550, 340),
		55,
		Color("4c7184")
	)
	draw_circle(
		Vector2(550, 340),
		28,
		Color("7fb4c9")
	)

	# Buildings
	draw_building(
		Rect2(90, 70, 250, 155),
		Color("7a4e55"),
		"home"
	)

	draw_building(
		Rect2(760, 70, 250, 155),
		Color("66547c"),
		"shop"
	)

	draw_building(
		Rect2(90, 440, 250, 135),
		Color("73583f"),
		"pub"
	)

	draw_building(
		Rect2(760, 440, 250, 135),
		Color("4d6573"),
		"office"
	)

	# Entrance mat
	draw_rect(
		Rect2(500, 590, 100, 30),
		Color("c4a574")
	)

	draw_border_with_door(TOWN_SIZE, Color("29312a"))


func draw_building(
	building_rect: Rect2,
	building_color: Color,
	_building_type: String
) -> void:
	# Main building
	draw_rect(building_rect, building_color)

	# Roof
	draw_rect(
		Rect2(
			building_rect.position - Vector2(12, 12),
			Vector2(building_rect.size.x + 24, 38)
		),
		building_color.darkened(0.25)
	)

	# Door
	draw_rect(
		Rect2(
			building_rect.position.x + building_rect.size.x / 2 - 22,
			building_rect.end.y - 55,
			44,
			55
		),
		Color("30282a")
	)

	# Windows
	draw_rect(
		Rect2(
			building_rect.position.x + 35,
			building_rect.position.y + 58,
			42,
			36
		),
		Color("c4d6c8")
	)

	draw_rect(
		Rect2(
			building_rect.end.x - 77,
			building_rect.position.y + 58,
			42,
			36
		),
		Color("c4d6c8")
	)


func draw_border_with_door(
	map_size: Vector2,
	wall_color: Color
) -> void:
	# Top
	draw_rect(
		Rect2(0, 0, map_size.x, WALL_THICKNESS),
		wall_color
	)

	# Left
	draw_rect(
		Rect2(0, 0, WALL_THICKNESS, map_size.y),
		wall_color
	)

	# Right
	draw_rect(
		Rect2(
			map_size.x - WALL_THICKNESS,
			0,
			WALL_THICKNESS,
			map_size.y
		),
		wall_color
	)

	# Bottom sections
	var side_width := (map_size.x - DOOR_WIDTH) / 2.0

	draw_rect(
		Rect2(
			0,
			map_size.y - WALL_THICKNESS,
			side_width,
			WALL_THICKNESS
		),
		wall_color
	)

	draw_rect(
		Rect2(
			side_width + DOOR_WIDTH,
			map_size.y - WALL_THICKNESS,
			side_width,
			WALL_THICKNESS
		),
		wall_color
	)

extends Node2D

enum Map {
	ROOM,
	TOWN
}

const ROOM_SIZE := Vector2(800, 600)
const TOWN_SIZE := Vector2(1100, 640)
const WALL_THICKNESS := 32.0
const DOOR_WIDTH := 100.0

@onready var player: CharacterBody2D = $Player

var current_map: Map = Map.ROOM
var walls: Node2D


func _ready() -> void:
	build_room()


func _process(_delta: float) -> void:
	if current_map == Map.ROOM and player.position.y > ROOM_SIZE.y + 30:
		enter_town()

	elif current_map == Map.TOWN and player.position.y > TOWN_SIZE.y + 30:
		enter_room()


func enter_town() -> void:
	current_map = Map.TOWN
	player.position = Vector2(TOWN_SIZE.x / 2, TOWN_SIZE.y - 70)
	build_town()
	queue_redraw()


func enter_room() -> void:
	current_map = Map.ROOM
	player.position = Vector2(ROOM_SIZE.x / 2, ROOM_SIZE.y - 70)
	build_room()
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

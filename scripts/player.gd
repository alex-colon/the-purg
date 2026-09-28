extends CharacterBody2D

const SPEED := 200.0
const SPRITE_PATH := "res://assets/characters/player/purple_fella_sprite.png"

var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("player")
	_try_load_sprite()
	queue_redraw()


func _try_load_sprite() -> void:
	if not ResourceLoader.exists(SPRITE_PATH):
		return # no real art yet -- _draw() below covers this with a placeholder

	var texture: Texture2D = load(SPRITE_PATH)
	if texture == null:
		return

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.position = Vector2(0, -texture.get_height() / 2.0 + 24)
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0

	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	velocity = direction.normalized() * SPEED
	move_and_slide()


func _draw() -> void:
	if _sprite != null:
		return

	draw_rect(
		Rect2(-16, -24, 32, 48),
		Color("8b5cf6")
	)

	draw_circle(
		Vector2(0, -30),
		12,
		Color("e8c39e")
	)

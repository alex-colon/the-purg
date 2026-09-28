extends CharacterBody2D

const SPEED := 200.0
const SPRITE_PATH := "res://assets/characters/player/purple_fella_sprite.png"
const SPRITE_HEIGHT := 96.0 # keep in step with npc.gd's DEFAULT_SPRITE_HEIGHT

const SpriteUtil := preload("res://scripts/sprite_util.gd")

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

	_sprite = SpriteUtil.build_sprite(texture, SPRITE_HEIGHT, 24.0)
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	# Stand still while a conversation, menu or fade is open.
	var blocked := DialogueBox.is_open()
	var main := get_parent()
	if main != null and main.has_method("is_ui_open"):
		blocked = blocked or bool(main.call("is_ui_open"))

	if blocked:
		velocity = Vector2.ZERO
		return

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

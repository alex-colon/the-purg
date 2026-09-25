extends CharacterBody2D

const SPEED := 200.0

func _ready() -> void:
	queue_redraw()


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
	draw_rect(
		Rect2(-16, -24, 32, 48),
		Color("8b5cf6")
	)

	draw_circle(
		Vector2(0, -30),
		12,
		Color("e8c39e")
	)

extends CharacterBody2D
## NPC
##
## A character standing in town. Looks up its identity in CharacterDB by
## `character_id`, shows its sprite (or a coloured placeholder if no art
## exists yet), and opens the DialogueBox when the player presses Enter
## while standing close.

const SpriteUtil := preload("res://scripts/sprite_util.gd")

# Default on-screen height of the visible character art, in pixels. A
# character can override this with an optional "sprite_height" number in
# its character.json (handy for very tall or very small characters).
const DEFAULT_SPRITE_HEIGHT := 96.0

@export var character_id: String = ""

var player_in_range: bool = false
var _data: Dictionary = {}
var _sprite: Sprite2D = null


func _ready() -> void:
	_data = CharacterDB.get_character(character_id)

	if _data.is_empty():
		push_warning("NPC: no character data found for id '%s'" % character_id)

	_try_load_sprite()
	queue_redraw()


func _try_load_sprite() -> void:
	var sprite_path := CharacterDB.get_art_path(character_id, "sprite")

	if sprite_path.is_empty():
		return # no real art yet -- _draw() below covers this with a placeholder

	var texture: Texture2D = load(sprite_path)
	if texture == null:
		return

	var height := float(_data.get("sprite_height", DEFAULT_SPRITE_HEIGHT))

	# Feet line up with the bottom of the collision box (y = 24).
	_sprite = SpriteUtil.build_sprite(texture, height, 24.0)
	add_child(_sprite)


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or DialogueBox.is_open():
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		DialogueBox.show_for_character(character_id)


func leave_toward(target: Vector2, seconds: float) -> void:
	## Called when this character's case is called: they stop being
	## interactive and walk to their gate, fading out as they arrive.
	player_in_range = false
	set_process_unhandled_input(false)
	$CollisionShape2D.set_deferred("disabled", true)
	$Detector.set_deferred("monitoring", false)
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "position", target, seconds)
	tween.parallel().tween_property(self, "modulate:a", 0.0, seconds * 0.35).set_delay(seconds * 0.65)
	tween.tween_callback(queue_free)


func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		queue_redraw()


func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		queue_redraw()


func _draw() -> void:
	if _sprite == null:
		# Placeholder for characters that haven't supplied a sprite yet.
		# Give a character its own colour with "placeholder_color" in character.json.
		var body_color := Color.from_string(str(_data.get("placeholder_color", "cfd8dc")), Color("cfd8dc"))
		draw_rect(Rect2(-16, -24, 32, 48), body_color)
		draw_circle(Vector2(0, -30), 12, body_color.lightened(0.2))

	if player_in_range:
		var text := "[Enter] Talk to %s" % str(_data.get("name", character_id))
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var text_pos := Vector2(-text_size.x / 2.0, -84)

		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

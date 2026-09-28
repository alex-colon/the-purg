extends CharacterBody2D
## NPC
##
## A character rendered in the world. Reads its identity from
## CharacterDB by `character_id` and opens the DialogueBox when the
## player interacts with it. Draws a plain placeholder shape for now --
## swap this for a sprite once art exists (see draw comment below).

@export var character_id: String = ""

# Sprites are scaled to this height in-game, so art of any source
# resolution (64x96, 1024x1024, ...) ends up the same on-screen size.
const SPRITE_TARGET_HEIGHT := 96.0

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
	var sprite_path: String = _data.get("sprite", "")

	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		return # no real art yet -- _draw() below covers this with a placeholder

	var texture: Texture2D = load(sprite_path)
	if texture == null:
		return

	var scale_factor := SPRITE_TARGET_HEIGHT / float(texture.get_height())

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # keep pixel edges crisp
	_sprite.scale = Vector2(scale_factor, scale_factor)
	# Feet line up with the bottom of the collision box (y = 24).
	_sprite.position = Vector2(0, 24.0 - SPRITE_TARGET_HEIGHT / 2.0)
	add_child(_sprite)


func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("ui_accept"):
		_interact()


func _interact() -> void:
	DialogueBox.show_for_character(character_id)


func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		queue_redraw()


func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		queue_redraw()


func _draw() -> void:
	var display_name: String = _data.get("name", character_id)

	if _sprite == null:
		# Placeholder art for characters that haven't supplied a sprite yet.
		var body_color := Color("cfd8dc")
		draw_rect(Rect2(-16, -24, 32, 48), body_color)
		draw_circle(Vector2(0, -30), 12, body_color.lightened(0.2))

	if player_in_range:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-46, -50),
			"[Enter] Talk to %s" % display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			92
		)

extends CanvasLayer
## DialogueBox (autoload scene)
##
## Global dialogue UI. Shows a character's current line -- the freshest
## unlocked milestone event if one applies, otherwise idle chatter --
## plus two interaction choices: give a gift (raises hearts) or be
## rude (raises skulls).

@onready var panel: Panel = $Panel
@onready var portrait_rect: TextureRect = $Panel/RootRow/PortraitRect
@onready var name_label: Label = $Panel/RootRow/VBoxContainer/NameLabel
@onready var text_label: Label = $Panel/RootRow/VBoxContainer/TextLabel
@onready var gift_button: Button = $Panel/RootRow/VBoxContainer/HBoxContainer/GiftButton
@onready var rude_button: Button = $Panel/RootRow/VBoxContainer/HBoxContainer/RudeButton
@onready var close_button: Button = $Panel/RootRow/VBoxContainer/HBoxContainer/CloseButton

const GIFT_AMOUNT := 2
const RUDE_AMOUNT := -2

var current_character_id: String = ""


func _ready() -> void:
	visible = false
	gift_button.pressed.connect(_on_gift_pressed)
	rude_button.pressed.connect(_on_rude_pressed)
	close_button.pressed.connect(hide_dialogue)


func show_for_character(character_id: String) -> void:
	current_character_id = character_id

	var data := CharacterDB.get_character(character_id)
	name_label.text = data.get("name", character_id)
	text_label.text = _pick_line(character_id, data)
	portrait_rect.texture = _load_portrait(data)

	visible = true


func _load_portrait(data: Dictionary) -> Texture2D:
	var portrait_path: String = data.get("portrait", "")

	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		return null

	return load(portrait_path)


func _pick_line(character_id: String, data: Dictionary) -> String:
	var score := Relationships.get_score(character_id)
	var prefix := "heart" if score >= 0 else "skull"

	# Prefer the highest milestone reached, so the most meaningful line wins.
	for level in [10, 8, 4]:
		if absi(score) < level:
			continue

		var event_key := "%s_%d" % [prefix, level]
		var event_data := CharacterDB.get_event(character_id, event_key)
		var lines: Array = event_data.get("dialogue", [])

		if not lines.is_empty():
			return _format_line(lines[0])

	var idle: Array = data.get("idle_dialogue", [])
	if not idle.is_empty():
		return idle[randi() % idle.size()]

	return "..."


func _format_line(line: Variant) -> String:
	if line is Dictionary:
		return str(line.get("text", ""))
	return str(line)


func _on_gift_pressed() -> void:
	Relationships.adjust_score(current_character_id, GIFT_AMOUNT)
	show_for_character(current_character_id) # refresh in case a milestone just hit


func _on_rude_pressed() -> void:
	Relationships.adjust_score(current_character_id, RUDE_AMOUNT)
	show_for_character(current_character_id)


func hide_dialogue() -> void:
	visible = false
	current_character_id = ""

extends CanvasLayer
## DialogueBox (autoload scene)
##
## The conversation UI. Its interface is built in code (see _build_ui),
## so there's no node tree to keep in sync with this script.
##
## Flow:
##   MENU  - the character says something; player picks Give Gift / Be Rude / Leave
##   GIFT  - player picks which item to give
##   SCENE - a sequence of lines plays, one per Enter/click: the action's
##           reaction, then any heart/skull milestone scene that was
##           unlocked. If that scene was a level-10 goodbye, the character
##           leaves town when it ends.
##
## Each character can spend time with the player once per day (a gift OR
## an insult), which is what makes hearts take days instead of seconds.

const GIFT_POINTS := {
	"love": 3,
	"like": 2,
	"neutral": 1,
	"dislike": -1,
	"hate": -3,
}
const RUDE_POINTS := -2

# Used only when a character has neither their own line nor a trait line.
const DEFAULT_REACTIONS := {
	"love": "Oh, {item}! This is wonderful, thank you!",
	"like": "Oh, {item}. That's nice of you.",
	"neutral": "Oh. {item}. Thank you, I suppose.",
	"dislike": "{item}? ...I'd rather not, but thanks.",
	"hate": "{item}?! Take that away. Now.",
}
const DEFAULT_RUDE := ["Excuse me?!", "Well. That was uncalled for."]

enum Mode { MENU, GIFT, SCENE }

var current_character_id: String = ""

var _mode: Mode = Mode.MENU
var _scene_lines: Array = []
var _scene_index: int = 0
var _pending_events: Array = []    # milestones unlocked by the action just taken
var _depart_after_scene: bool = false

var _panel: Panel
var _portrait: TextureRect
var _name_label: Label
var _status_label: Label
var _text_label: Label
var _continue_hint: Label
var _action_row: HBoxContainer
var _gift_button: Button
var _rude_button: Button
var _leave_button: Button
var _gift_row: HFlowContainer


func _ready() -> void:
	_build_ui()
	visible = false
	Relationships.milestone_reached.connect(_on_milestone_reached)


func is_open() -> bool:
	return visible


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_left = 0.06
	_panel.anchor_right = 0.94
	_panel.anchor_top = 0.52
	_panel.anchor_bottom = 0.96
	add_child(_panel)

	var margin := MarginContainer.new()
	_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(150, 150)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	column.add_child(_name_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_status_label)

	_text_label = Label.new()
	_text_label.custom_minimum_size = Vector2(200, 60)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_text_label)

	_continue_hint = Label.new()
	_continue_hint.text = "[Enter / click] Continue"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.add_theme_font_size_override("font_size", 14)
	_continue_hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(_continue_hint)

	_action_row = HBoxContainer.new()
	_action_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_action_row)

	_gift_button = _make_button("Give Gift", _on_gift_pressed)
	_rude_button = _make_button("Be Rude", _on_rude_pressed)
	_leave_button = _make_button("Leave", hide_dialogue)
	_action_row.add_child(_gift_button)
	_action_row.add_child(_rude_button)
	_action_row.add_child(_leave_button)

	_gift_row = HFlowContainer.new()
	column.add_child(_gift_row)


func _make_button(label: String, callback: Callable, font_size: int = 0) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)

	if font_size > 0:
		button.add_theme_font_size_override("font_size", font_size)

	return button


# ---------------------------------------------------------- opening

func show_for_character(character_id: String) -> void:
	current_character_id = character_id

	var data := CharacterDB.get_character(character_id)
	_portrait.texture = _load_portrait(character_id)
	_pending_events.clear()
	_depart_after_scene = false

	_enter_menu(_pick_idle_line(data))
	visible = true
	_focus_first_button.call_deferred()


func hide_dialogue() -> void:
	visible = false
	current_character_id = ""
	_mode = Mode.MENU


func _load_portrait(character_id: String) -> Texture2D:
	var path := CharacterDB.get_art_path(character_id, "portrait")

	if path.is_empty():
		return null

	return load(path)


func _pick_idle_line(data: Dictionary) -> String:
	var idle: Array = data.get("idle_dialogue", [])

	if idle.is_empty():
		return "..."

	return str(idle[randi() % idle.size()])


# ------------------------------------------------------------- menu

func _enter_menu(text: String) -> void:
	var data := CharacterDB.get_character(current_character_id)
	var acted := Relationships.has_acted_today(current_character_id)

	_mode = Mode.MENU
	_name_label.text = str(data.get("name", current_character_id))
	_text_label.text = text
	_status_label.text = _status_text(acted)
	_continue_hint.visible = false
	_gift_row.visible = false
	_action_row.visible = true
	_gift_button.disabled = acted
	_rude_button.disabled = acted


func _status_text(acted_today: bool) -> String:
	var score := Relationships.get_score(current_character_id)
	var text := "Strangers"

	if score > 0:
		text = "Hearts: %d / 10" % score
	elif score < 0:
		text = "Skulls: %d / 10" % absi(score)

	if acted_today:
		text += "     (You've already spent time together today. Come back tomorrow.)"

	return text


func _focus_first_button() -> void:
	if not visible or _mode != Mode.MENU:
		return

	if _gift_button.disabled:
		_leave_button.grab_focus()
	else:
		_gift_button.grab_focus()


# ------------------------------------------------------------- gifts

func _on_gift_pressed() -> void:
	_mode = Mode.GIFT
	_action_row.visible = false
	_gift_row.visible = true
	_text_label.text = "What will you give them?"

	for child in _gift_row.get_children():
		_gift_row.remove_child(child)
		child.queue_free()

	for item in CharacterDB.get_all_items():
		var item_id := str(item.get("id", ""))
		var item_name := str(item.get("name", item_id))
		_gift_row.add_child(_make_button(item_name, _on_item_chosen.bind(item_id), 15))

	_gift_row.add_child(_make_button("Back", _on_gift_back, 15))
	_focus_gift_row.call_deferred()


func _focus_gift_row() -> void:
	if _mode != Mode.GIFT or _gift_row.get_child_count() == 0:
		return

	var first := _gift_row.get_child(0) as Button
	if first != null:
		first.grab_focus()


func _on_gift_back() -> void:
	var data := CharacterDB.get_character(current_character_id)
	_enter_menu(_pick_idle_line(data))
	_focus_first_button.call_deferred()


func _on_item_chosen(item_id: String) -> void:
	var data := CharacterDB.get_character(current_character_id)
	var char_name := str(data.get("name", current_character_id))
	var item_name := str(CharacterDB.get_item(item_id).get("name", item_id))

	var tier := CharacterDB.get_gift_tier(current_character_id, item_id)
	var reaction := CharacterDB.get_gift_reaction(current_character_id, tier)
	if reaction.is_empty():
		reaction = str(DEFAULT_REACTIONS[tier])
	reaction = reaction.replace("{item}", item_name)

	var narration := "You give %s the %s." % [char_name, item_name]
	_perform_action(int(GIFT_POINTS[tier]), narration, reaction)


# --------------------------------------------------------------- rude

func _on_rude_pressed() -> void:
	var data := CharacterDB.get_character(current_character_id)
	var char_name := str(data.get("name", current_character_id))

	var pool := CharacterDB.get_rude_reactions(current_character_id)
	if pool.is_empty():
		pool = DEFAULT_RUDE

	var reaction := str(pool[randi() % pool.size()])
	var narration := "You say something cruel to %s." % char_name
	_perform_action(RUDE_POINTS, narration, reaction)


# ----------------------------------------------------------- actions

func _perform_action(points: int, narration: String, reaction: String) -> void:
	var id := current_character_id
	var data := CharacterDB.get_character(id)
	var speaker := str(data.get("name", id))

	# adjust_score() fires milestone_reached synchronously, which fills
	# _pending_events with any 4/8/10 scenes this action just unlocked.
	_pending_events.clear()
	Relationships.mark_acted_today(id)
	Relationships.adjust_score(id, points)

	var lines: Array = [
		{"speaker": "", "text": narration},
		{"speaker": speaker, "text": reaction},
	]
	_depart_after_scene = false

	for entry in _pending_events:
		var event: Dictionary = entry["event_data"]
		var event_lines: Array = event.get("dialogue", [])

		for line in event_lines:
			lines.append(_normalize_line(line, speaker))

		var key := str(entry["event_key"])
		if key.ends_with("_10") or bool(event.get("departs", false)):
			_depart_after_scene = true

			if event_lines.is_empty():
				lines.append({"speaker": speaker, "text": "It seems my case has been called. Goodbye."})

	_pending_events.clear()
	_start_scene(lines)


func _normalize_line(line: Variant, default_speaker: String) -> Dictionary:
	if line is Dictionary:
		return {
			"speaker": str(line.get("speaker", default_speaker)),
			"text": str(line.get("text", "")),
		}

	return {"speaker": default_speaker, "text": str(line)}


func _on_milestone_reached(character_id: String, event_key: String, event_data: Dictionary) -> void:
	_pending_events.append({
		"character_id": character_id,
		"event_key": event_key,
		"event_data": event_data,
	})


# ------------------------------------------------------------- scenes

func _start_scene(lines: Array) -> void:
	_mode = Mode.SCENE
	_scene_lines = lines
	_scene_index = 0
	_action_row.visible = false
	_gift_row.visible = false
	_continue_hint.visible = true
	_show_scene_line()


func _show_scene_line() -> void:
	var line: Dictionary = _scene_lines[_scene_index]
	_name_label.text = str(line.get("speaker", ""))
	_text_label.text = str(line.get("text", ""))
	_status_label.text = _status_text(true)


func _advance_scene() -> void:
	_scene_index += 1

	if _scene_index < _scene_lines.size():
		_show_scene_line()
		return

	_end_scene()


func _end_scene() -> void:
	var id := current_character_id

	if _depart_after_scene:
		_depart_after_scene = false
		hide_dialogue()
		Roster.depart(id)
		return

	var data := CharacterDB.get_character(id)
	_enter_menu(_pick_idle_line(data))
	_focus_first_button.call_deferred()


# -------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not visible:
		return

	match _mode:
		Mode.SCENE:
			var clicked := false

			if event is InputEventMouseButton:
				var mouse := event as InputEventMouseButton
				clicked = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT

			if event.is_action_pressed("ui_accept") or clicked:
				get_viewport().set_input_as_handled()
				_advance_scene()

		Mode.GIFT:
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				_on_gift_back()

		Mode.MENU:
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				hide_dialogue()

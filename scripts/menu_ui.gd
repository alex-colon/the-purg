extends CanvasLayer
## MenuUI
##
## One reusable pop-up screen: a title, a paragraph of text, and a list
## of buttons. The shop, notice board, dice game, bureau files and so on
## are all just different calls to open(). To "go to another screen", a
## button's callback simply calls open() again with new contents.
##
## Built entirely in code, so there's no node tree to keep in sync.
##
##   menu.open("Title", "Some text", [
##       {"label": "Do a thing", "call": _do_thing},
##       {"label": "Can't afford", "disabled": true, "call": _nothing},
##   ])
##
## A "Close" button is added automatically unless can_close is false.

var _panel: Panel
var _title: Label
var _body: Label
var _list: VBoxContainer
var _can_close: bool = true


func _ready() -> void:
	layer = 8
	_build_ui()
	visible = false


func is_open() -> bool:
	return visible


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9
	add_child(_panel)

	var margin := MarginContainer.new()
	_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	column.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(300, 70)
	_body.add_theme_font_size_override("font_size", 17)
	column.add_child(_body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)


func open(title: String, body: String, options: Array = [], can_close: bool = true) -> void:
	_can_close = can_close
	_title.text = title
	_body.text = body

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	for option in options:
		var button := Button.new()
		button.text = str(option.get("label", "..."))
		button.disabled = bool(option.get("disabled", false))

		var callback: Callable = option.get("call", Callable())
		if callback.is_valid():
			button.pressed.connect(_on_option_pressed.bind(callback))

		_list.add_child(button)

	if can_close:
		var close_button := Button.new()
		close_button.text = "Close"
		close_button.pressed.connect(close)
		_list.add_child(close_button)

	visible = true
	_focus_first.call_deferred()


func close() -> void:
	visible = false


func _on_option_pressed(callback: Callable) -> void:
	# Deferred, so the button that was pressed finishes its own signal
	# before the callback rebuilds the list.
	callback.call_deferred()


func _focus_first() -> void:
	if not visible:
		return

	for child in _list.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return


func _input(event: InputEvent) -> void:
	if visible and _can_close and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

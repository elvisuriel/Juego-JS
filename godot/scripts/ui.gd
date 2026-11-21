class_name UI
extends RefCounted
## Estilo común de botones y paneles para menú, pausa y fin de partida.

const ACCENT := Color("#ff4f9a")
const GOLD := Color("#ffe066")
const PANEL := Color("#0d3a5c")

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 30

	var normal := _box(Color("#1d6fa5"))
	var hover := _box(Color("#2b86c5"))
	var pressed := _box(Color("#155a88"))
	var disabled := _box(Color(0.3, 0.35, 0.4, 0.8))
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled, "focus": normal}[s]
		_theme.set_stylebox(s, "Button", box)
	_theme.set_color("font_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.5))
	_theme.set_constant("outline_size", "Button", 6)
	_theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.4))

	_theme.set_color("font_color", "Label", Color.WHITE)
	_theme.set_constant("outline_size", "Label", 6)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.5))

	_theme.set_stylebox("normal", "LineEdit", _box(Color(1, 1, 1, 0.95)))
	_theme.set_stylebox("focus", "LineEdit", _box(Color.WHITE))
	_theme.set_color("font_color", "LineEdit", Color("#0d3a5c"))
	_theme.set_font_size("font_size", "LineEdit", 34)

	var panel := _box(Color(PANEL, 0.92))
	panel.set_corner_radius_all(24)
	panel.set_content_margin_all(28)
	_theme.set_stylebox("panel", "PanelContainer", panel)
	return _theme


static func _box(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(18)
	b.content_margin_left = 26
	b.content_margin_right = 26
	b.content_margin_top = 12
	b.content_margin_bottom = 12
	b.border_color = Color(1, 1, 1, 0.25)
	b.set_border_width_all(2)
	return b


static func button(text: String, on_press: Callable, min_width := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b


static func label(text: String, size := 30, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Panel centrado con una columna de controles.
static func center_panel(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	return box


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

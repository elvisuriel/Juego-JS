extends Control
## Menú de inicio: Jugar, Tienda (skins con diamantes), Récords y Ajustes.
## De fondo, el mar con burbujas, el caballito y un tiburón 3D nadando.

const GAME_SCENE := "res://scenes/main.tscn"
const HORSE_TEXTURE := preload("res://assets/images/horse.png")
const MUSIC := preload("res://assets/sounds/musicLoop.mp3")
const SIZE := Vector2(1136, 640)

var _content: Control
var _horse: Sprite2D
var _bank_label: Label
var _music: AudioStreamPlayer
var _t := 0.0


func _ready() -> void:
	Game.load_data()
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = WorldMap.WATER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scene := Node2D.new()
	add_child(scene)
	var bubbles: Node2D = preload("res://scripts/bubbles.gd").new()
	scene.add_child(bubbles)
	bubbles.setup(SIZE)

	var shark := Shark.new()
	shark.bounds = Rect2(Vector2(-150, 120), SIZE + Vector2(300, -120))
	shark.position = Vector2(900, 380)
	scene.add_child(shark)

	_horse = Sprite2D.new()
	_horse.texture = HORSE_TEXTURE
	_horse.hframes = 2
	_horse.position = Vector2(190, 360)
	_horse.scale = Vector2.ONE * 1.4
	scene.add_child(_horse)

	_bank_label = UI.label("", 28, UI.GOLD)
	_bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bank_label.position = Vector2(736, 16)
	_bank_label.size = Vector2(380, 40)
	add_child(_bank_label)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_music = AudioStreamPlayer.new()
	var stream: AudioStreamMP3 = MUSIC.duplicate()
	stream.loop = true
	_music.stream = stream
	_music.volume_db = -10.0
	add_child(_music)
	if Game.music_on:
		_music.play()

	_show_main()


func _process(delta: float) -> void:
	_t += delta
	_horse.position.y = 360 + sin(_t * 1.6) * 14.0
	_horse.rotation = sin(_t * 1.1) * 0.06


func _refresh() -> void:
	_bank_label.text = "DIAMANTES: %d" % Game.bank
	_horse.material = Game.skin_material(Game.skin)


func _screen() -> VBoxContainer:
	UI.clear(_content)
	_refresh()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 260
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


func _click() -> void:
	if Game.sound_on:
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.click()
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)


# --- Pantallas -------------------------------------------------------------

func _show_main() -> void:
	var box := _screen()
	var title := UI.label("ATLANTIS", 96, Color.WHITE)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color("#0d3a5c"))
	box.add_child(title)
	box.add_child(UI.label("el caballito y los diamantes", 26, UI.GOLD))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	box.add_child(spacer)
	box.add_child(UI.button("JUGAR", _play))
	box.add_child(UI.button("Tienda", _nav(_show_shop)))
	box.add_child(UI.button("Récords", _nav(_show_records)))
	box.add_child(UI.button("Ajustes", _nav(_show_settings)))


func _nav(screen: Callable) -> Callable:
	return func() -> void:
		_click()
		screen.call()


func _play() -> void:
	_click()
	Game.new_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _back_button() -> Button:
	return UI.button("Volver", _nav(_show_main), 260)


func _show_records() -> void:
	var box := _screen()
	box.add_child(UI.label("RÉCORDS", 56, UI.GOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 8)
	for h in ["#", "NOMBRE", "PUNTOS", "NIVEL"]:
		grid.add_child(UI.label(h, 22, Color(1, 1, 1, 0.6)))
	for i in Game.MAX_RECORDS:
		var has := i < Game.records.size()
		var r: Dictionary = Game.records[i] if has else {}
		var color := UI.GOLD if i == 0 and has else Color.WHITE
		grid.add_child(UI.label(str(i + 1), 28, color))
		grid.add_child(UI.label(r.name if has else "-", 28, color))
		grid.add_child(UI.label(str(r.score) if has else "-", 28, color))
		grid.add_child(UI.label(str(r.level) if has else "-", 28, color))
	box.add_child(grid)
	box.add_child(_back_button())


func _show_settings() -> void:
	var box := _screen()
	box.add_child(UI.label("AJUSTES", 56, UI.GOLD))
	box.add_child(_toggle("Música", Game.music_on, func(on: bool) -> void:
		Game.music_on = on
		if on: _music.play()
		else: _music.stop()))
	box.add_child(_toggle("Sonidos", Game.sound_on, func(on: bool) -> void: Game.sound_on = on))
	box.add_child(_toggle("Vibración", Game.vibration_on, func(on: bool) -> void:
		Game.vibration_on = on
		Game.vibrate(80)))

	var controls := UI.button("", func() -> void: pass)
	var update := func() -> void:
		controls.text = "Controles: " + ("Joystick" if Game.joystick else "Mantener el dedo")
	update.call()
	controls.pressed.connect(func() -> void:
		_click()
		Game.joystick = not Game.joystick
		Game.save()
		update.call())
	box.add_child(controls)
	box.add_child(_back_button())


func _toggle(text: String, value: bool, on_change: Callable) -> Button:
	var b := UI.button("", func() -> void: pass)
	b.toggle_mode = true
	b.button_pressed = value
	var paint := func() -> void:
		b.text = "%s: %s" % [text, "SÍ" if b.button_pressed else "NO"]
		b.modulate = Color.WHITE if b.button_pressed else Color(1, 1, 1, 0.6)
	paint.call()
	b.toggled.connect(func(on: bool) -> void:
		_click()
		on_change.call(on)
		Game.save()
		paint.call())
	return b


func _show_shop() -> void:
	var box := _screen()
	box.add_child(UI.label("TIENDA", 56, UI.GOLD))
	box.add_child(UI.label("Compra colores con los diamantes que atrapas", 22, Color(1, 1, 1, 0.75)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	for s in Game.SKINS:
		grid.add_child(_skin_card(s))
	box.add_child(grid)
	box.add_child(_back_button())


func _skin_card(s: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.custom_minimum_size = Vector2(230, 0)

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(230, 90)
	var spr := Sprite2D.new()
	spr.texture = HORSE_TEXTURE
	spr.hframes = 2
	spr.scale = Vector2.ONE * 0.55
	spr.position = Vector2(115, 45)
	spr.material = Game.skin_material(s.id)
	preview.add_child(spr)
	card.add_child(preview)

	var owned: bool = Game.owned.has(s.id)
	var in_use: bool = Game.skin == s.id
	var text: String
	if in_use:
		text = "%s (en uso)" % s.name
	elif owned:
		text = "Usar %s" % s.name
	else:
		text = "%s: %d" % [s.name, s.price]
	var b := UI.button(text, _skin_pressed.bind(s), 230)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size.y = 50
	b.disabled = in_use or (not owned and Game.bank < s.price)
	card.add_child(b)
	return card


func _skin_pressed(s: Dictionary) -> void:
	_click()
	if not Game.owned.has(s.id):
		if Game.bank < s.price:
			return
		Game.bank -= s.price
		Game.owned.append(s.id)
	Game.skin = s.id
	Game.save()
	_show_shop()

extends Node2D
## Atlantis: explora el mapa y recoge todos los diamantes antes de que
## se acabe el tiempo, sin que te atrapen los tiburones.
## Cada nivel es más grande y difícil; las vidas y los puntos pasan
## de un nivel al siguiente.

const POINTS_PER_DIAMOND := 100
const POINTS_PER_SECOND_LEFT := 50
const MAX_PLACEMENT_TRIES := 500
const MIN_DIAMOND_GAP := 120.0
const SAFE_DISTANCE := 900.0         # enemigos lejos del inicio
const POWERUP_RESPAWN := 12.0        # segundos entre power-ups nuevos
const TURBO_TIME := 6.0
const ALERT_COOLDOWN := 1.5

const DiamondScene := preload("res://scenes/diamond.tscn")
const EXPLOSION_TEXTURE := preload("res://assets/images/explosion.png")
const LivesScript := preload("res://scripts/lives.gd")
const JoystickScript := preload("res://scripts/joystick.gd")
const InkScript := preload("res://scripts/ink.gd")
const FISHES_TEXTURE := preload("res://assets/images/fishes.png")
const MOLLUSK_TEXTURE := preload("res://assets/images/mollusk.png")
const MENU_SCENE := "res://scenes/menu.tscn"

enum State { WAITING, PLAYING, ENDED }

var state := State.WAITING
var cfg: Dictionary
var world_size: Vector2
var amount_diamonds := 30
var score := 0
var time_left := 75
var caught := 0
var lives := 3
var end_reason := ""

var _swimmers: Array[Sprite2D] = []
var _sharks: Array[Shark] = []
var _octopi: Array[Octopus] = []
var _hideouts: Array[Hideout] = []
var _powerups_root: Node2D
var _powerup_timer := 0.0
var _alert_cooldown := 0.0

var _lives_view: Control
var _flash: ColorRect
var _ink: Control
var _toast: Label
var _status: Control
var _pause_layer: Control
var _joystick: Control

@onready var world_map: WorldMap = $Map
@onready var bubbles: Node2D = $Bubbles
@onready var decor_root: Node2D = $Decor
@onready var diamonds_root: Node2D = $Diamonds
@onready var effects_root: Node2D = $Effects
@onready var horse: Area2D = $Horse
@onready var camera: Camera2D = $Horse/Camera
@onready var game_timer: Timer = $GameTimer
@onready var music: AudioStreamPlayer = $Music
@onready var pop: AudioStreamPlayer = $Pop
@onready var hud: CanvasLayer = $HUD

@onready var score_label: Label = $HUD/ScoreLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var record_label: Label = $HUD/RecordLabel
@onready var diamonds_label: Label = $HUD/DiamondsLabel
@onready var start_label: Label = $HUD/StartLabel
@onready var minimap: Control = $HUD/Minimap
@onready var end_panel: Control = $HUD/EndPanel


func _ready() -> void:
	Game.load_data()
	cfg = Game.level_config(Game.level)
	world_size = cfg.world
	amount_diamonds = cfg.diamonds
	time_left = cfg.time
	score = Game.run_score
	lives = Game.run_lives

	var stream := music.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	if not Game.sound_on:
		pop.volume_db = -80.0

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	world_map.generate(world_size, rng)
	bubbles.setup(world_size)

	horse.position = world_size / 2.0
	horse.bounds = Rect2(Vector2.ZERO, world_size)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	camera.reset_smoothing()

	_spawn_decor()
	_spawn_hideouts()
	_spawn_diamonds()
	_spawn_powerups_root()
	for i in cfg.powerups:
		_spawn_powerup()
	_spawn_sharks()
	_spawn_octopi()
	_build_hud()

	minimap.world_map = world_map
	minimap.horse = horse
	minimap.diamonds_root = diamonds_root
	minimap.camera = camera
	minimap.sharks = _sharks
	minimap.hideouts = _hideouts
	minimap.octopi = _octopi

	horse.diamond_caught.connect(_on_diamond_caught)
	horse.powerup_caught.connect(_on_powerup_caught)
	game_timer.timeout.connect(_on_timer_tick)

	end_panel.hide()
	start_label.text = "NIVEL %d  ·  TOCA PARA EMPEZAR" % Game.level
	_update_hud()

	var blink := create_tween().set_loops()
	blink.tween_property(start_label, "modulate:a", 0.2, 0.7).set_trans(Tween.TRANS_SINE)
	blink.tween_property(start_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	# En móvil el toque llega emulado como clic del mouse
	if event is InputEventMouseButton and event.pressed and state == State.WAITING:
		_start_game()


func _notification(what: int) -> void:
	# Si entra una llamada o se sale de la app, se pausa sola
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.PLAYING and not get_tree().paused:
			_set_paused(true)


func _process(delta: float) -> void:
	var f := delta * 60.0
	for s in _swimmers:
		s.position.x += s.get_meta("vel") * f
		if s.position.x < -400.0 or s.position.x > world_size.x + 400.0:
			var from_left: bool = s.get_meta("vel") > 0.0
			s.position.x = -350.0 if from_left else world_size.x + 350.0
			s.position.y = randf_range(80, world_size.y - 80)

	var inside := false
	for h in _hideouts:
		h.occupied = h.contains(horse.global_position)
		inside = inside or h.occupied
	horse.in_hideout = inside

	_alert_cooldown = maxf(_alert_cooldown - delta, 0.0)

	if state == State.PLAYING:
		_powerup_timer += delta
		if _powerup_timer > POWERUP_RESPAWN:
			_powerup_timer = 0.0
			if _powerups_root.get_child_count() < cfg.powerups:
				_spawn_powerup()
	_status.queue_redraw()


# --- Flujo del juego -------------------------------------------------------

func _start_game() -> void:
	state = State.PLAYING
	horse.active = true
	for sh in _sharks:
		sh.hunting = true
	for o in _octopi:
		o.hunting = true
	start_label.hide()
	game_timer.start()
	if Game.music_on:
		music.play()


func _on_timer_tick() -> void:
	if state != State.PLAYING:
		return
	time_left -= 1
	_update_hud()
	if time_left <= 0:
		end_reason = "¡SE ACABÓ EL TIEMPO!"
		_finish_game(false)


func _on_diamond_caught(diamond: Area2D) -> void:
	if state != State.PLAYING or diamond.is_queued_for_deletion():
		return

	_spawn_explosion(diamond.position)
	diamond.queue_free()

	horse.smile()
	pop.play()

	caught += 1
	Game.bank += 1
	score += POINTS_PER_DIAMOND
	if caught >= amount_diamonds:
		score += time_left * POINTS_PER_SECOND_LEFT
		_update_hud()
		_finish_game(true)
	else:
		_update_hud()


func _on_powerup_caught(p: Area2D) -> void:
	if state != State.PLAYING or p.is_queued_for_deletion():
		return
	var pu := p as PowerUp
	match pu.kind:
		PowerUp.Kind.TURBO:
			horse.turbo_left = TURBO_TIME
		PowerUp.Kind.SHIELD:
			horse.shield = true
		PowerUp.Kind.HEART:
			lives = mini(lives + 1, Game.MAX_LIVES)
		PowerUp.Kind.CLOCK:
			time_left += 10
	_show_toast(PowerUp.NAMES[pu.kind], PowerUp.COLORS[pu.kind])
	_spawn_explosion(pu.position)
	pu.queue_free()
	_play(Sfx.powerup())
	Game.vibrate(40)
	_update_hud()


func _on_shark_bite(shark: Shark) -> void:
	if state != State.PLAYING or horse.is_invulnerable():
		return

	var lost: bool = horse.hurt(shark.global_position)
	shark.retreat()
	_shake_camera()

	if not lost:
		_show_toast("¡ESCUDO ROTO!", PowerUp.COLORS[PowerUp.Kind.SHIELD])
		_play(Sfx.ink())
		Game.vibrate(80)
		return

	lives -= 1
	_play(pop.stream, 0.45)
	Game.vibrate(300)
	_update_hud()
	_flash.color.a = 0.45
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)

	if lives <= 0:
		end_reason = "¡TE ATRAPÓ UN TIBURÓN!"
		_finish_game(false)


func _on_shark_chase(_shark: Shark) -> void:
	if state == State.PLAYING and _alert_cooldown <= 0.0:
		_alert_cooldown = ALERT_COOLDOWN
		_play(Sfx.alert())
		Game.vibrate(25)


func _on_inked(_o: Octopus) -> void:
	if state != State.PLAYING:
		return
	_ink.splash()
	_play(Sfx.ink())
	Game.vibrate(60)
	_show_toast("¡TINTA!", Octopus.COLOR)


func _finish_game(won: bool) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	horse.active = false
	for sh in _sharks:
		sh.hunting = false
	for o in _octopi:
		o.hunting = false
	game_timer.stop()
	_ink.clear()
	Game.save()
	_update_hud()

	end_panel.show()
	for c in end_panel.get_children():
		c.hide()
	var box := UI.center_panel(end_panel)
	end_panel.theme = UI.theme()

	if won:
		_play(Sfx.level_up())
		box.add_child(UI.label("¡NIVEL %d COMPLETADO!" % Game.level, 56, UI.GOLD))
		box.add_child(UI.label("PUNTOS: %d   ·   bonus de tiempo: %ds" % [score, time_left], 28))
		box.add_child(UI.label("Siguiente: más tiburones y un mapa más grande", 22, Color(1, 1, 1, 0.75)))
		box.add_child(UI.button("Siguiente nivel", _next_level))
		box.add_child(UI.button("Menú", _go_menu))
		return

	box.add_child(UI.label("GAME OVER", 64))
	box.add_child(UI.label(end_reason, 30, UI.GOLD))
	box.add_child(UI.label("PUNTOS: %d   ·   NIVEL %d" % [score, Game.level], 28))

	if Game.qualifies(score):
		var entry := VBoxContainer.new()
		entry.add_child(UI.label("¡Entraste en el top 5! Escribe tu nombre:", 24, Color(1, 1, 1, 0.85)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_edit := LineEdit.new()
		name_edit.text = Game.last_name
		name_edit.max_length = 12
		name_edit.custom_minimum_size = Vector2(300, 60)
		name_edit.select_all_on_focus = true
		row.add_child(name_edit)
		var save_btn := UI.button("Guardar", func() -> void: pass, 160)
		row.add_child(save_btn)
		entry.add_child(row)
		box.add_child(entry)
		save_btn.pressed.connect(_save_record.bind(name_edit, entry, box), CONNECT_ONE_SHOT)
		name_edit.text_submitted.connect(func(_t: String) -> void: _save_record(name_edit, entry, box), CONNECT_ONE_SHOT)

	box.add_child(UI.button("Jugar de nuevo", _restart))
	box.add_child(UI.button("Menú", _go_menu))


func _save_record(name_edit: LineEdit, row: Control, box: VBoxContainer) -> void:
	if not is_instance_valid(row) or row.is_queued_for_deletion():
		return
	var player := name_edit.text.strip_edges().to_upper()
	Game.add_record(player if player != "" else "JUGADOR", score, Game.level)
	row.queue_free()
	var done := UI.label("¡Récord guardado como %s!" % Game.last_name, 26, UI.GOLD)
	box.add_child(done)
	box.move_child(done, row.get_index())
	_update_hud()


func _next_level() -> void:
	Game.level += 1
	Game.run_score = score
	Game.run_lives = lives
	get_tree().reload_current_scene()


func _restart() -> void:
	Game.new_run()
	get_tree().reload_current_scene()


func _go_menu() -> void:
	get_tree().paused = false
	Game.save()
	get_tree().change_scene_to_file(MENU_SCENE)


func _set_paused(p: bool) -> void:
	get_tree().paused = p
	_pause_layer.visible = p
	if p:
		music.stream_paused = true
	else:
		music.stream_paused = false


func _update_hud() -> void:
	score_label.text = str(score)
	timer_label.text = str(time_left)
	timer_label.modulate = Color(1, 0.33, 0.33) if time_left <= 10 else Color.WHITE
	record_label.text = "RÉCORD: %d   ·   NIVEL %d" % [maxi(Game.high_score(), score), Game.level]
	diamonds_label.text = "DIAMANTES: %d/%d" % [caught, amount_diamonds]
	if _lives_view:
		_lives_view.max_lives = maxi(Game.START_LIVES, lives)
		_lives_view.lives = lives


# --- HUD -------------------------------------------------------------------

func _build_hud() -> void:
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	timer_label.position.x -= 70

	_lives_view = LivesScript.new()
	_lives_view.position = Vector2(20, 84)
	_lives_view.size = Vector2(220, 34)
	hud.add_child(_lives_view)

	# Poderes activos (turbo con su tiempo, escudo)
	_status = Control.new()
	_status.position = Vector2(20, 124)
	_status.size = Vector2(200, 40)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.draw.connect(_draw_status)
	hud.add_child(_status)

	_ink = InkScript.new()
	_ink.size = Vector2(1136, 640)
	hud.add_child(_ink)
	hud.move_child(_ink, 0)

	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.05, 0.1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.size = Vector2(1136, 640)
	hud.add_child(_flash)
	hud.move_child(_flash, 0)

	_toast = UI.label("", 44)
	_toast.position = Vector2(0, 150)
	_toast.size = Vector2(1136, 60)
	_toast.modulate.a = 0.0
	hud.add_child(_toast)

	if Game.joystick:
		_joystick = JoystickScript.new()
		_joystick.position = Vector2(40, 400)
		hud.add_child(_joystick)
		horse.joystick = _joystick

	# Botón de pausa
	var pause_btn := UI.button("II", _on_pause_pressed, 64)
	pause_btn.theme = UI.theme()
	pause_btn.custom_minimum_size = Vector2(64, 60)
	pause_btn.position = Vector2(1058, 12)
	hud.add_child(pause_btn)

	_pause_layer = ColorRect.new()
	_pause_layer.color = Color(0, 0.05, 0.1, 0.6)
	_pause_layer.size = Vector2(1136, 640)
	_pause_layer.theme = UI.theme()
	_pause_layer.hide()
	hud.add_child(_pause_layer)
	var box := UI.center_panel(_pause_layer)
	box.add_child(UI.label("PAUSA", 60))
	box.add_child(UI.button("Continuar", _set_paused.bind(false)))
	box.add_child(UI.button("Reiniciar nivel", _restart_level))
	box.add_child(UI.button("Menú", _go_menu))


func _on_pause_pressed() -> void:
	if state == State.PLAYING:
		_set_paused(true)


func _restart_level() -> void:
	get_tree().paused = false
	Game.save()
	get_tree().reload_current_scene()


func _draw_status() -> void:
	var x := 18.0
	if horse.turbo_left > 0.0:
		PowerUp.draw_icon(_status, PowerUp.Kind.TURBO, Vector2(x, 18), 0.9, PowerUp.COLORS[PowerUp.Kind.TURBO])
		var w: float = 60.0 * horse.turbo_left / TURBO_TIME
		_status.draw_rect(Rect2(x + 20, 12, 60, 12), Color(0, 0, 0, 0.35))
		_status.draw_rect(Rect2(x + 20, 12, w, 12), PowerUp.COLORS[PowerUp.Kind.TURBO])
		x += 100.0
	if horse.shield:
		PowerUp.draw_icon(_status, PowerUp.Kind.SHIELD, Vector2(x, 18), 0.9, PowerUp.COLORS[PowerUp.Kind.SHIELD])


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	_toast.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if not Game.sound_on:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = -2.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _shake_camera() -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(camera, "offset", Vector2(randf_range(-14, 14), randf_range(-14, 14)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.05)


# --- Creación de elementos -------------------------------------------------

func _far_point(margin: float) -> Vector2:
	var pos := Vector2.ZERO
	for t in MAX_PLACEMENT_TRIES:
		pos = Vector2(randf_range(margin, world_size.x - margin), randf_range(margin, world_size.y - margin))
		if pos.distance_to(horse.position) > SAFE_DISTANCE:
			break
	return pos


func _spawn_decor() -> void:
	# Moluscos quietos que flotan suave
	for i in 6:
		var m := Sprite2D.new()
		m.texture = MOLLUSK_TEXTURE
		m.position = Vector2(randf_range(100, world_size.x - 100), randf_range(100, world_size.y - 100))
		decor_root.add_child(m)
		var tw := create_tween().set_loops()
		tw.tween_property(m, "position:y", m.position.y - 40.0, randf_range(2.0, 3.5)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "position:y", m.position.y, randf_range(2.0, 3.5)).set_trans(Tween.TRANS_SINE)

	# Cardúmenes de fondo (los tiburones van aparte, en 3D)
	for i in 5:
		_add_swimmer(FISHES_TEXTURE, randf_range(0.4, 0.9))


func _add_swimmer(texture: Texture2D, vel: float) -> void:
	var s := Sprite2D.new()
	s.texture = texture
	s.position = Vector2(randf_range(0, world_size.x), randf_range(80, world_size.y - 80))
	s.set_meta("vel", vel)
	decor_root.add_child(s)
	_swimmers.append(s)


func _spawn_hideouts() -> void:
	var root := Node2D.new()
	add_child(root)
	move_child(root, horse.get_index() + 1)
	var placed: Array[Vector2] = []
	for i in cfg.hideouts:
		var pos := Vector2.ZERO
		for t in MAX_PLACEMENT_TRIES:
			pos = Vector2(randf_range(250, world_size.x - 250), randf_range(250, world_size.y - 250))
			if pos.distance_to(horse.position) < 300.0:
				continue
			if placed.any(func(p: Vector2): return p.distance_to(pos) < 500.0):
				continue
			break
		placed.append(pos)
		var h := Hideout.new()
		h.position = pos
		root.add_child(h)
		_hideouts.append(h)


func _spawn_diamonds() -> void:
	var safe_zone := Rect2(horse.position - Vector2(250, 200), Vector2(500, 400))
	var placed: Array[Vector2] = []

	for i in amount_diamonds:
		var diamond: Area2D = DiamondScene.instantiate()
		var s := randf_range(0.5, 0.9)
		diamond.scale = Vector2(s, s)
		diamond.get_node("Sprite").frame = randi_range(0, 3)

		var pos := Vector2.ZERO
		for t in MAX_PLACEMENT_TRIES:
			pos = Vector2(randf_range(80, world_size.x - 80), randf_range(80, world_size.y - 80))
			if safe_zone.has_point(pos):
				continue
			if placed.any(func(p: Vector2): return p.distance_to(pos) < MIN_DIAMOND_GAP):
				continue
			break

		diamond.position = pos
		placed.append(pos)
		diamonds_root.add_child(diamond)

		# Un brillo suave para que se note al encontrarlo
		var tw := diamond.create_tween().set_loops()
		tw.tween_property(diamond, "scale", Vector2.ONE * s * 1.12, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(diamond, "scale", Vector2.ONE * s, 0.6).set_trans(Tween.TRANS_SINE)


func _spawn_powerups_root() -> void:
	_powerups_root = Node2D.new()
	add_child(_powerups_root)
	move_child(_powerups_root, diamonds_root.get_index() + 1)


func _spawn_powerup() -> void:
	var p := PowerUp.new()
	# El corazón es más raro
	var roll := randf()
	if roll < 0.3:
		p.kind = PowerUp.Kind.TURBO
	elif roll < 0.6:
		p.kind = PowerUp.Kind.SHIELD
	elif roll < 0.85:
		p.kind = PowerUp.Kind.CLOCK
	else:
		p.kind = PowerUp.Kind.HEART
	p.position = Vector2(randf_range(150, world_size.x - 150), randf_range(150, world_size.y - 150))
	_powerups_root.add_child(p)


func _spawn_sharks() -> void:
	var kinds: Array[int] = []
	for i in cfg.big_sharks:
		kinds.append(Shark.Kind.BIG)
	for i in cfg.fast_sharks:
		kinds.append(Shark.Kind.FAST)
	while kinds.size() < cfg.sharks:
		kinds.append(Shark.Kind.NORMAL)

	for k in kinds:
		var sh := Shark.new()
		sh.kind = k
		sh.chase_speed = cfg.chase_speed
		sh.horse = horse
		sh.bounds = Rect2(Vector2.ZERO, world_size)
		sh.position = _far_point(150)
		sh.bitten.connect(_on_shark_bite)
		sh.chase_started.connect(_on_shark_chase)
		# Por encima de los diamantes, por debajo del caballito
		add_child(sh)
		move_child(sh, horse.get_index())
		_sharks.append(sh)


func _spawn_octopi() -> void:
	for i in cfg.octopus:
		var o := Octopus.new()
		o.horse = horse
		o.bounds = Rect2(Vector2.ZERO, world_size)
		o.position = _far_point(200)
		o.inked.connect(_on_inked)
		add_child(o)
		move_child(o, horse.get_index())
		_octopi.append(o)


func _spawn_explosion(at: Vector2) -> void:
	var fx := Sprite2D.new()
	fx.texture = EXPLOSION_TEXTURE
	fx.position = at
	fx.scale = Vector2.ONE * 0.4
	effects_root.add_child(fx)

	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "scale", Vector2.ONE * 0.8, 0.3)
	tw.tween_property(fx, "scale", Vector2.ONE * 0.4, 0.3).set_delay(0.3)
	tw.tween_property(fx, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(fx.queue_free)

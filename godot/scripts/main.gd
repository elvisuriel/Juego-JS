extends Node2D
## Atlantis: explora el mapa y recoge todos los diamantes antes de que
## se acabe el tiempo.

const WORLD_SIZE := Vector2(3400, 2000)
const AMOUNT_DIAMONDS := 30
const GAME_TIME := 75
const POINTS_PER_DIAMOND := 100
const POINTS_PER_SECOND_LEFT := 50
const MAX_PLACEMENT_TRIES := 500
const MIN_DIAMOND_GAP := 120.0
const SAVE_PATH := "user://atlantis.cfg"

const DiamondScene := preload("res://scenes/diamond.tscn")
const EXPLOSION_TEXTURE := preload("res://assets/images/explosion.png")
const SHARK_TEXTURE := preload("res://assets/images/shark.png")
const FISHES_TEXTURE := preload("res://assets/images/fishes.png")
const MOLLUSK_TEXTURE := preload("res://assets/images/mollusk.png")

enum State { WAITING, PLAYING, ENDED }

var state := State.WAITING
var score := 0
var time_left := GAME_TIME
var caught := 0
var high_score := 0
var can_restart := false

var _swimmers: Array[Sprite2D] = []

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

@onready var score_label: Label = $HUD/ScoreLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var record_label: Label = $HUD/RecordLabel
@onready var diamonds_label: Label = $HUD/DiamondsLabel
@onready var start_label: Label = $HUD/StartLabel
@onready var minimap: Control = $HUD/Minimap
@onready var end_panel: Control = $HUD/EndPanel
@onready var title_label: Label = $HUD/EndPanel/TitleLabel
@onready var sub_label: Label = $HUD/EndPanel/SubLabel
@onready var restart_label: Label = $HUD/EndPanel/RestartLabel


func _ready() -> void:
	high_score = _load_high_score()

	var stream := music.stream as AudioStreamMP3
	if stream:
		stream.loop = true

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	world_map.generate(WORLD_SIZE, rng)
	bubbles.setup(WORLD_SIZE)

	horse.position = WORLD_SIZE / 2.0
	horse.bounds = Rect2(Vector2.ZERO, WORLD_SIZE)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.reset_smoothing()

	_spawn_decor()
	_spawn_diamonds()

	minimap.world_map = world_map
	minimap.horse = horse
	minimap.diamonds_root = diamonds_root
	minimap.camera = camera

	horse.diamond_caught.connect(_on_diamond_caught)
	game_timer.timeout.connect(_on_timer_tick)

	end_panel.hide()
	_update_hud()

	var blink := create_tween().set_loops()
	blink.tween_property(start_label, "modulate:a", 0.2, 0.7).set_trans(Tween.TRANS_SINE)
	blink.tween_property(start_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	# En móvil el toque llega emulado como clic del mouse
	if not (event is InputEventMouseButton and event.pressed):
		return

	match state:
		State.WAITING:
			_start_game()
		State.ENDED:
			if can_restart:
				get_tree().reload_current_scene()


func _process(delta: float) -> void:
	var f := delta * 60.0
	for s in _swimmers:
		s.position.x += s.get_meta("vel") * f
		if s.position.x < -400.0 or s.position.x > WORLD_SIZE.x + 400.0:
			var from_left: bool = s.get_meta("vel") > 0.0
			s.position.x = -350.0 if from_left else WORLD_SIZE.x + 350.0
			s.position.y = randf_range(80, WORLD_SIZE.y - 80)


# --- Flujo del juego -------------------------------------------------------

func _start_game() -> void:
	state = State.PLAYING
	horse.active = true
	start_label.hide()
	game_timer.start()
	music.play()


func _on_timer_tick() -> void:
	if state != State.PLAYING:
		return
	time_left -= 1
	_update_hud()
	if time_left <= 0:
		_finish_game(false)


func _on_diamond_caught(diamond: Area2D) -> void:
	if state != State.PLAYING or diamond.is_queued_for_deletion():
		return

	_spawn_explosion(diamond.position)
	diamond.queue_free()

	horse.smile()
	pop.play()

	caught += 1
	score += POINTS_PER_DIAMOND
	if caught >= AMOUNT_DIAMONDS:
		score += time_left * POINTS_PER_SECOND_LEFT
		_update_hud()
		_finish_game(true)
	else:
		_update_hud()


func _finish_game(won: bool) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	horse.active = false
	game_timer.stop()

	var new_record := score > high_score
	if new_record:
		high_score = score
		_save_high_score(high_score)
		_update_hud()

	title_label.text = "¡GANASTE!" if won else "GAME OVER"
	var sub := "PUNTOS: %d   ·   DIAMANTES: %d/%d" % [score, caught, AMOUNT_DIAMONDS]
	if won:
		sub += "\nbonus %ds" % time_left
	if new_record:
		sub += "\n¡NUEVO RÉCORD!"
	sub_label.text = sub

	restart_label.hide()
	end_panel.show()

	# Pequeña pausa para no reiniciar con un toque accidental
	await get_tree().create_timer(1.0).timeout
	can_restart = true
	restart_label.show()


func _update_hud() -> void:
	score_label.text = str(score)
	timer_label.text = str(time_left)
	timer_label.modulate = Color(1, 0.33, 0.33) if time_left <= 10 else Color.WHITE
	record_label.text = "RÉCORD: %d" % high_score
	diamonds_label.text = "DIAMANTES: %d/%d" % [caught, AMOUNT_DIAMONDS]


# --- Creación de elementos -------------------------------------------------

func _spawn_decor() -> void:
	# Moluscos quietos que flotan suave
	for i in 6:
		var m := Sprite2D.new()
		m.texture = MOLLUSK_TEXTURE
		m.position = Vector2(randf_range(100, WORLD_SIZE.x - 100), randf_range(100, WORLD_SIZE.y - 100))
		decor_root.add_child(m)
		var tw := create_tween().set_loops()
		tw.tween_property(m, "position:y", m.position.y - 40.0, randf_range(2.0, 3.5)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "position:y", m.position.y, randf_range(2.0, 3.5)).set_trans(Tween.TRANS_SINE)

	# Tiburones (van a la izquierda) y cardúmenes (a la derecha)
	for i in 3:
		_add_swimmer(SHARK_TEXTURE, -randf_range(1.2, 2.0))
	for i in 5:
		_add_swimmer(FISHES_TEXTURE, randf_range(0.4, 0.9))


func _add_swimmer(texture: Texture2D, vel: float) -> void:
	var s := Sprite2D.new()
	s.texture = texture
	s.position = Vector2(randf_range(0, WORLD_SIZE.x), randf_range(80, WORLD_SIZE.y - 80))
	s.set_meta("vel", vel)
	decor_root.add_child(s)
	_swimmers.append(s)


func _spawn_diamonds() -> void:
	var safe_zone := Rect2(horse.position - Vector2(250, 200), Vector2(500, 400))
	var placed: Array[Vector2] = []

	for i in AMOUNT_DIAMONDS:
		var diamond: Area2D = DiamondScene.instantiate()
		var s := randf_range(0.5, 0.9)
		diamond.scale = Vector2(s, s)
		diamond.get_node("Sprite").frame = randi_range(0, 3)

		var pos := Vector2.ZERO
		for t in MAX_PLACEMENT_TRIES:
			pos = Vector2(randf_range(80, WORLD_SIZE.x - 80), randf_range(80, WORLD_SIZE.y - 80))
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


# --- Récord ----------------------------------------------------------------

func _load_high_score() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("game", "high_score", 0))
	return 0


func _save_high_score(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "high_score", value)
	cfg.save(SAVE_PATH)

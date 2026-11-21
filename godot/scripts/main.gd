extends Node2D
## Atlantis: recoge todos los diamantes antes de que se acabe el tiempo.

const AMOUNT_DIAMONDS := 30
const AMOUNT_BUBBLES := 30
const GAME_TIME := 30
const POINTS_PER_DIAMOND := 100
const POINTS_PER_SECOND_LEFT := 50
const MAX_PLACEMENT_TRIES := 500
const SAVE_PATH := "user://atlantis.cfg"

const DiamondScene := preload("res://scenes/diamond.tscn")
const BUBBLE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/images/booble1.png"),
	preload("res://assets/images/booble2.png"),
]
const EXPLOSION_TEXTURE := preload("res://assets/images/explosion.png")

enum State { WAITING, PLAYING, ENDED }

var state := State.WAITING
var score := 0
var time_left := GAME_TIME
var caught := 0
var high_score := 0
var can_restart := false

var _bubbles: Array[Sprite2D] = []
var _mollusk_tween: Tween

@onready var bubbles_root: Node2D = $Bubbles
@onready var diamonds_root: Node2D = $Diamonds
@onready var effects_root: Node2D = $Effects
@onready var mollusk: Sprite2D = $Mollusk
@onready var shark: Sprite2D = $Shark
@onready var fishes: Sprite2D = $Fishes
@onready var horse: Area2D = $Horse
@onready var game_timer: Timer = $GameTimer
@onready var music: AudioStreamPlayer = $Music
@onready var pop: AudioStreamPlayer = $Pop

@onready var score_label: Label = $HUD/ScoreLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var record_label: Label = $HUD/RecordLabel
@onready var start_label: Label = $HUD/StartLabel
@onready var end_panel: Control = $HUD/EndPanel
@onready var title_label: Label = $HUD/EndPanel/TitleLabel
@onready var sub_label: Label = $HUD/EndPanel/SubLabel
@onready var restart_label: Label = $HUD/EndPanel/RestartLabel


func _ready() -> void:
	high_score = _load_high_score()

	var stream := music.stream as AudioStreamMP3
	if stream:
		stream.loop = true

	_spawn_bubbles()
	_spawn_diamonds()

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
	var f := delta * 60.0  # 1.0 a 60 FPS

	# El fondo se anima siempre
	for bubble in _bubbles:
		bubble.position.y -= bubble.get_meta("vel") * f
		if bubble.position.y < -50.0:
			bubble.position = Vector2(randf_range(1, 1140), 700)

	shark.position.x -= 1.0 * f
	if shark.position.x < -300.0:
		shark.position.x = 1300.0

	fishes.position.x += 0.3 * f
	if fishes.position.x > 1300.0:
		fishes.position.x = -300.0


# --- Flujo del juego -------------------------------------------------------

func _start_game() -> void:
	state = State.PLAYING
	horse.active = true
	start_label.hide()
	game_timer.start()
	music.play()

	_mollusk_tween = create_tween().set_loops()
	_mollusk_tween.tween_property(mollusk, "position:y", 0.0, 5.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_mollusk_tween.tween_property(mollusk, "position:y", mollusk.position.y, 5.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


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
	if _mollusk_tween:
		_mollusk_tween.kill()

	var new_record := score > high_score
	if new_record:
		high_score = score
		_save_high_score(high_score)
		_update_hud()

	title_label.text = "¡GANASTE!" if won else "GAME OVER"
	var sub := "PUNTOS: %d" % score
	if won:
		sub += "  (bonus %ds)" % time_left
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


# --- Creación de elementos -------------------------------------------------

func _spawn_bubbles() -> void:
	for i in AMOUNT_BUBBLES:
		var bubble := Sprite2D.new()
		bubble.texture = BUBBLE_TEXTURES.pick_random()
		bubble.centered = false
		bubble.position = Vector2(randf_range(1, 1140), randf_range(0, 950))
		bubble.scale = Vector2.ONE * (0.2 + randf())
		bubble.modulate.a = 0.9
		bubble.set_meta("vel", 0.2 + randf() * 2.0)
		bubbles_root.add_child(bubble)
		_bubbles.append(bubble)


func _spawn_diamonds() -> void:
	var horse_rect := _rect_centered(horse.position, Vector2(84, 156))
	var placed: Array[Rect2] = []

	for i in AMOUNT_DIAMONDS:
		var diamond: Area2D = DiamondScene.instantiate()
		var s := 0.30 + randf()
		diamond.scale = Vector2(s, s)
		diamond.get_node("Sprite").frame = randi_range(0, 3)

		var rect: Rect2
		for t in MAX_PLACEMENT_TRIES:
			diamond.position = Vector2(randi_range(50, 1050), randi_range(50, 600))
			rect = _rect_centered(diamond.position, Vector2(81, 84) * s)
			if not rect.intersects(horse_rect) and not placed.any(func(r: Rect2): return r.intersects(rect)):
				break

		placed.append(rect)
		diamonds_root.add_child(diamond)


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


func _rect_centered(center: Vector2, size: Vector2) -> Rect2:
	return Rect2(center - size / 2.0, size)


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

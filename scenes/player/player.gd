extends CharacterBody2D
class_name Player

enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT }

# 重力は物理設定から取得（変更不要）
var GRAVITY: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ノード参照をキャッシュ（CLAUDE.mdガイドライン準拠）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# ========== 移動設定 ==========
# 通常の歩行速度とダッシュ速度を調整可能
@export_group("Movement Settings", "move_")
@export var move_walk_speed: float = 200.0  # 通常歩行速度（ピクセル/秒）
@export var move_run_speed: float = 350.0   # ダッシュ速度（ピクセル/秒）

# ========== ジャンプ設定 ==========
# ジャンプの感触を細かく調整可能な設定群
@export_group("Jump Settings", "jump_")
@export var jump_force: float = 380.0        # ジャンプの初速度（大きいほど高くジャンプ）
@export var jump_run_bonus: float = 80.0     # run状態でのジャンプ力ボーナス（慣性ジャンプ）
@export var jump_max_fall_speed: float = 400.0  # 最大落下速度（大きいほど速く落ちる）
@export var jump_gravity_scale: float = 1.0     # 重力倍率（1.0が標準、小さいほどふわふわ）
@export var jump_buffer_time: float = 0.1       # ジャンプ先行入力時間（秒）
@export var jump_coyote_time: float = 0.1       # コヨーテタイム（地面を離れてもジャンプ可能な時間）

# ========== 内部状態変数 ==========
var direction_x: float = 0.0
var state: PLAYER_STATE = PLAYER_STATE.IDLE
var is_running: bool = false
var is_squatting: bool = false

# ジャンプバッファとコヨーテタイム用タイマー
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var was_on_floor: bool = false

func _ready():
	animated_sprite_2d.flip_h = true

func _physics_process(delta: float) -> void:
	update_timers(delta)
	apply_gravity(delta)
	handle_input()
	apply_movement()
	move_and_slide()
	update_state()

# タイマー更新（ジャンプバッファとコヨーテタイム）
func update_timers(delta: float) -> void:
	# 現在の床接触状態を記録
	var currently_on_floor: bool = is_on_floor()

	# コヨーテタイマーの更新
	if currently_on_floor:
		coyote_timer = jump_coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# ジャンプバッファタイマーの更新
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

	was_on_floor = currently_on_floor

# 重力適用（改良版：重力倍率対応）
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var effective_gravity: float = GRAVITY * jump_gravity_scale
		velocity.y = min(velocity.y + effective_gravity * delta, jump_max_fall_speed)

# 入力処理（改良版：ジャンプバッファとコヨーテタイム対応）
func handle_input() -> void:
	# Shiftキーの状態を直接確認
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	# しゃがみ入力の状態確認（地面にいる時のみ）
	is_squatting = is_on_floor() and Input.is_action_pressed("squat")

	# 方向キーの状態確認
	var left_key: bool = Input.is_key_pressed(KEY_A)
	var right_key: bool = Input.is_key_pressed(KEY_D)

	# 移動方向と走行状態の決定（しゃがみ中は移動を無効にする）
	if not is_squatting:
		if left_key:
			direction_x = -1.0
			is_running = shift_pressed
		elif right_key:
			direction_x = 1.0
			is_running = shift_pressed
		else:
			direction_x = 0.0
			is_running = false
	else:
		direction_x = 0.0
		is_running = false

	# ジャンプ入力処理（しゃがみ中はジャンプ不可）
	if Input.is_action_just_pressed("jump") and not is_squatting:
		jump_buffer_timer = jump_buffer_time

	# ジャンプ実行判定（ジャンプバッファとコヨーテタイム対応）
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		perform_jump()

# ジャンプ実行（run状態での慣性ジャンプ対応）
func perform_jump() -> void:
	var effective_jump_force: float = jump_force
	# run状態の場合、慣性により追加のジャンプ力を得る
	if is_running:
		effective_jump_force += jump_run_bonus

	velocity.y = -effective_jump_force
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

# 移動適用（静的型付け強化）
func apply_movement() -> void:
	if direction_x != 0.0:
		animated_sprite_2d.flip_h = direction_x > 0.0
		var target_speed: float = move_run_speed if is_running else move_walk_speed
		velocity.x = direction_x * target_speed
	else:
		velocity.x = 0.0

# 状態更新（静的型付け強化）
func update_state() -> void:
	var new_state: PLAYER_STATE

	if is_on_floor():
		if is_squatting:
			new_state = PLAYER_STATE.SQUAT
		elif velocity.x == 0.0:
			new_state = PLAYER_STATE.IDLE
		else:
			new_state = PLAYER_STATE.RUN if is_running else PLAYER_STATE.WALK
	else:
		new_state = PLAYER_STATE.FALL if velocity.y > 0.0 else PLAYER_STATE.JUMP

	set_state(new_state)

# 状態設定とアニメーション制御
func set_state(new_state: PLAYER_STATE) -> void:
	if new_state == state:
		return

	state = new_state

	# 状態に応じたアニメーション再生
	match state:
		PLAYER_STATE.IDLE:
			animated_sprite_2d.play("normal_idle")
		PLAYER_STATE.WALK:
			animated_sprite_2d.play("normal_walk")
		PLAYER_STATE.RUN:
			animated_sprite_2d.play("normal_run")
		PLAYER_STATE.JUMP:
			animated_sprite_2d.play("normal_jump")
		PLAYER_STATE.FALL:
			animated_sprite_2d.play("normal_fall")
		PLAYER_STATE.SQUAT:
			animated_sprite_2d.play("normal_squat")

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
@export var jump_vertical_bonus: float = 80.0     # run状態でのジャンプ垂直力ボーナス
@export var jump_horizontal_bonus: float = 100.0  # run状態でのジャンプ水平力ボーナス
@export var jump_max_fall_speed: float = 400.0  # 最大落下速度（大きいほど速く落ちる）
@export var jump_gravity_scale: float = 1.0     # 重力倍率（1.0が標準、小さいほどふわふわ）
@export var jump_buffer_time: float = 0.1       # ジャンプ先行入力時間（秒）
@export var jump_coyote_time: float = 0.1       # コヨーテタイム（地面を離れてもジャンプ可能な時間）

# ========== 内部状態変数 ==========
var direction_x: float = 0.0
var state: PLAYER_STATE = PLAYER_STATE.IDLE
var is_running: bool = false
var is_squatting: bool = false

# 着地状態（フレームごとに一度だけチェック）
var is_grounded: bool = false    # 現在のフレームで地面に接触しているか
var was_grounded: bool = false   # 前のフレームで地面に接触していたか（着地瞬間の検知に使用）

# ジャンプバッファとコヨーテタイム用タイマー
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0

# ジャンプ時のボーナス維持用変数
var current_vertical_bonus: float = 0.0    # 現在の垂直ボーナス
var current_horizontal_bonus: float = 0.0  # 現在の水平ボーナス
var jump_direction: float = 0.0            # ジャンプ時の移動方向を記録

func _ready():
	animated_sprite_2d.flip_h = true

func _physics_process(delta: float) -> void:
	# 着地状態を一度だけチェックして内部状態変数に保存
	was_grounded = is_grounded
	is_grounded = is_on_floor()

	update_timers(delta)
	apply_gravity(delta)
	handle_input()
	apply_movement()
	move_and_slide()
	update_state()

# タイマー更新（ジャンプバッファとコヨーテタイム）
func update_timers(delta: float) -> void:
	# 着地検知（空中から地面に着地した瞬間）
	if not was_grounded and is_grounded:
		# 着地時に垂直・水平ボーナスをリセット
		current_vertical_bonus = 0.0
		current_horizontal_bonus = 0.0
		jump_direction = 0.0

	# コヨーテタイマーの更新
	if is_grounded:
		coyote_timer = jump_coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# ジャンプバッファタイマーの更新
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

# 重力適用（改良版：重力倍率対応）
func apply_gravity(delta: float) -> void:
	if not is_grounded:
		var effective_gravity: float = GRAVITY * jump_gravity_scale
		velocity.y = min(velocity.y + effective_gravity * delta, jump_max_fall_speed)

# 入力処理（改良版：ジャンプバッファとコヨーテタイム対応）
func handle_input() -> void:
	# Shiftキーの状態を直接確認
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	# しゃがみ入力の状態確認（地面にいる時のみ）
	is_squatting = is_grounded and Input.is_action_pressed("squat")

	# 方向キーの状態確認
	var left_key: bool = Input.is_key_pressed(KEY_A)
	var right_key: bool = Input.is_key_pressed(KEY_D)

	# 移動方向と走行状態の決定（しゃがみ中は移動を無効にする）
	if not is_squatting:
		if left_key:
			direction_x = -1.0
			# 地面にいる時のみランニング状態を更新
			if is_grounded:
				is_running = shift_pressed
		elif right_key:
			direction_x = 1.0
			# 地面にいる時のみランニング状態を更新
			if is_grounded:
				is_running = shift_pressed
		else:
			direction_x = 0.0
			# 地面にいる時のみランニング状態をfalseに
			if is_grounded:
				is_running = false
	else:
		direction_x = 0.0
		is_running = false

	# 空中にいる場合はランニング状態をfalseにする
	if not is_grounded:
		is_running = false

	# ジャンプ入力処理（しゃがみ中はジャンプ不可）
	if Input.is_action_just_pressed("jump") and not is_squatting:
		jump_buffer_timer = jump_buffer_time

	# ジャンプ実行判定（ジャンプバッファとコヨーテタイム対応）
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		perform_jump()

# ジャンプ実行（run状態での垂直・水平ボーナス対応）
func perform_jump() -> void:
	var effective_jump_force: float = jump_force
	# run状態の場合、慣性により垂直・水平両方のジャンプボーナスを得る
	if is_running:
		current_vertical_bonus = jump_vertical_bonus
		current_horizontal_bonus = jump_horizontal_bonus
		jump_direction = direction_x  # ジャンプ時の方向を記録
		effective_jump_force += current_vertical_bonus
	else:
		current_vertical_bonus = 0.0
		current_horizontal_bonus = 0.0
		jump_direction = 0.0

	velocity.y = -effective_jump_force
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

# 移動適用（静的型付け強化）
func apply_movement() -> void:
	if direction_x != 0.0:
		animated_sprite_2d.flip_h = direction_x > 0.0
		var target_speed: float = move_run_speed if is_running else move_walk_speed

		# 地面にいる場合は通常の移動、空中の場合は慣性ボーナスを追加
		if is_grounded:
			velocity.x = direction_x * target_speed
		else:
			# 空中では基本移動速度＋ジャンプ時の水平慣性ボーナスを適用
			velocity.x = direction_x * target_speed + (direction_x * current_horizontal_bonus)
	else:
		# 移動入力がない場合
		if is_grounded:
			velocity.x = 0.0
		else:
			# 空中では記録されたジャンプ方向の慣性を維持
			if jump_direction != 0.0:
				velocity.x = jump_direction * current_horizontal_bonus
			else:
				velocity.x = 0.0

# 状態更新（静的型付け強化）
func update_state() -> void:
	var new_state: PLAYER_STATE

	if is_grounded:
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

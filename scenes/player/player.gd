extends CharacterBody2D
class_name Player

enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING }

# 重力は物理設定から取得（変更不要）
var GRAVITY: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ノード参照をキャッシュ（CLAUDE.mdガイドライン準拠）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# ========== 移動設定 ==========
# 通常の歩行速度とダッシュ速度を調整可能
@export_group("Movement Settings", "move_")
@export var move_walk_speed: float = 200.0  # 通常歩行速度（ピクセル/秒）
@export var move_run_speed: float = 350.0   # ダッシュ速度（ピクセル/秒）
@export var move_attack_initial_speed: float = 400.0  # 攻撃開始時の初期前進速度（ピクセル/秒）
@export var move_attack_max_distance: float = 200.0  # 攻撃時の最大前進距離（ピクセル）
@export var move_attack_decel_start_ratio: float = 0.8  # 減速開始距離の割合（0.8 = 最大距離の80%で減速開始）
@export var move_attack_deceleration: float = 0.95  # 攻撃中の減速率（1.0=減速なし、0.95=5%ずつ減速）

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

# ========== 当たり判定設定 ==========
# しゃがみ時の当たり判定サイズ調整
@export_group("Collision Settings", "collision_")
@export var collision_normal_size: Vector2 = Vector2(78.5, 168)  # 通常時の当たり判定サイズ
@export var collision_squat_size: Vector2 = Vector2(78.5, 84)    # しゃがみ時の当たり判定サイズ（高さ半分）
@export var collision_squat_offset: Vector2 = Vector2(0, 42)     # しゃがみ時の当たり判定オフセット

# ========== 内部状態変数 ==========
var direction_x: float = 0.0
var state: PLAYER_STATE = PLAYER_STATE.IDLE
var is_running: bool = false
var is_squatting: bool = false
var was_squatting: bool = false  # 前フレームのしゃがみ状態（当たり判定更新判定用）

# 攻撃状態管理
var is_attacking: bool = false
var attack_direction: float = 0.0  # 攻撃開始時の方向を記録
var attack_start_position: float = 0.0  # 攻撃開始時のX座標
var current_attack_speed: float = 0.0  # 現在の攻撃中の前進速度

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
	update_collision_shape()
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

	# しゃがみ入力の状態確認（地面にいる時かつ攻撃中でない場合のみ）
	is_squatting = is_grounded and Input.is_action_pressed("squat") and not is_attacking

	# 攻撃入力処理（fキー、攻撃中でない場合のみ）
	if Input.is_key_pressed(KEY_F) and not is_attacking:
		perform_attack()

	# 方向キーの状態確認
	var left_key: bool = Input.is_key_pressed(KEY_A)
	var right_key: bool = Input.is_key_pressed(KEY_D)

	# 移動方向と走行状態の決定（しゃがみ中と攻撃中は移動を無効にする）
	if not is_squatting and not is_attacking:
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

	# ジャンプ入力処理（しゃがみ中かつ攻撃中はジャンプ不可）
	if Input.is_action_just_pressed("jump") and not is_squatting and not is_attacking:
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

# 攻撃実行（飛び蹴りモーション）
func perform_attack() -> void:
	is_attacking = true
	# 攻撃開始時の向きを記録（現在の向きか、向きが決まっていない場合はスプライトの向きから判定）
	if direction_x != 0.0:
		attack_direction = direction_x
	else:
		attack_direction = 1.0 if animated_sprite_2d.flip_h else -1.0

	# 攻撃開始時の位置を記録
	attack_start_position = global_position.x

	# 攻撃開始時の初期速度を設定
	current_attack_speed = move_attack_initial_speed

	set_state(PLAYER_STATE.FIGHTING)

	# アニメーション終了時のコールバックを設定
	if not animated_sprite_2d.animation_finished.is_connected(_on_attack_animation_finished):
		animated_sprite_2d.animation_finished.connect(_on_attack_animation_finished)

# 攻撃アニメーション終了時のコールバック
func _on_attack_animation_finished() -> void:
	if state == PLAYER_STATE.FIGHTING:
		is_attacking = false
		attack_direction = 0.0
		attack_start_position = 0.0
		current_attack_speed = 0.0
		# シグナル接続を解除
		if animated_sprite_2d.animation_finished.is_connected(_on_attack_animation_finished):
			animated_sprite_2d.animation_finished.disconnect(_on_attack_animation_finished)
		# 状態更新を呼び出し（自動的に適切な状態に遷移）
		update_state()

# 当たり判定更新（しゃがみ状態に応じて形状を変更）
func update_collision_shape() -> void:
	# しゃがみ状態が変化した場合のみ当たり判定を更新
	if is_squatting != was_squatting:
		var shape: RectangleShape2D = collision_shape_2d.shape as RectangleShape2D

		if is_squatting:
			# しゃがみ状態：当たり判定を縮小し、位置を調整
			shape.size = collision_squat_size
			collision_shape_2d.position.y += collision_squat_offset.y
		else:
			# 通常状態：当たり判定を元に戻す
			shape.size = collision_normal_size
			collision_shape_2d.position.y -= collision_squat_offset.y

		was_squatting = is_squatting

# 移動適用（静的型付け強化）
func apply_movement() -> void:
	# 攻撃中は攻撃方向への前進移動を優先（距離ベース制御）
	if is_attacking:
		# 攻撃開始からの移動距離を計算
		var distance_moved: float = abs(global_position.x - attack_start_position)
		var decel_start_distance: float = move_attack_max_distance * move_attack_decel_start_ratio

		# 減速開始距離に達していない場合は一定速度で前進
		if distance_moved < decel_start_distance:
			velocity.x = attack_direction * current_attack_speed
		elif distance_moved < move_attack_max_distance:
			# 減速開始距離に達した場合は徐々に減速
			current_attack_speed *= move_attack_deceleration
			velocity.x = attack_direction * current_attack_speed
		else:
			# 最大距離に達した場合は急激に減速
			current_attack_speed *= move_attack_deceleration * 0.85  # より強い減速
			velocity.x = attack_direction * current_attack_speed

			# 速度が非常に小さくなったら停止
			if current_attack_speed < 20.0:
				velocity.x = 0.0
		return

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
	# 攻撃中は状態変更を行わない
	if is_attacking:
		return

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
		PLAYER_STATE.FIGHTING:
			animated_sprite_2d.play("normal_fighting_01")

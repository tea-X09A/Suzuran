class_name JumpState
extends BaseState

# ジャンプ開始時刻
var jump_start_time: float = 0.0
# ジャンプ開始時の水平速度（慣性を保持するため）
var initial_horizontal_speed: float = 0.0

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	jump_start_time = Time.get_ticks_msec() / 1000.0
	# ジャンプ開始時の水平速度を記憶（run/walkの速度を維持）
	initial_horizontal_speed = abs(player.velocity.x)

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	jump_start_time = 0.0
	initial_horizontal_speed = 0.0

## 入力処理
func handle_input(_delta: float) -> void:
	# 水平移動入力を処理
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		# 入力方向への速度を計算（基本は歩行速度）
		var input_speed: float = get_parameter("move_walk_speed")
		# ジャンプ開始時の速度（run/walkの慣性）と入力速度の大きい方を使用
		var target_speed: float = max(input_speed, initial_horizontal_speed)
		apply_movement(movement_input, target_speed)
	# 入力がない場合は現在の速度を維持（慣性保持）

## 物理演算処理
func physics_update(delta: float) -> void:
	# 現在時刻を取得
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var elapsed_time: float = current_time - jump_start_time

	# パラメータからジャンプ関連の値を取得
	var hold_duration: float = get_parameter("jump_hold_duration")
	var max_jump_velocity: float = get_parameter("jump_max_velocity")
	var hold_acceleration: float = get_parameter("jump_hold_acceleration")

	# 長押し受付時間内かつボタンが押され続けており、上昇中の場合
	if elapsed_time < hold_duration and Input.is_action_pressed("jump") and player.velocity.y < 0.0:
		# 上昇速度を増加
		player.velocity.y = max(player.velocity.y + hold_acceleration * delta, max_jump_velocity)

	# 重力を適用
	apply_gravity(delta)

	# 落下開始（速度が0以上）したらFALL状態に遷移
	if player.velocity.y >= 0.0:
		player.update_animation_state("FALL")

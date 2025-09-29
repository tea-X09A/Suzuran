class_name JumpState
extends BaseState

# ジャンプ開始時刻
var jump_start_time: float = 0.0
# 長押し受付時間（秒）
const HOLD_DURATION: float = 0.3
# 最大上昇速度
const MAX_JUMP_VELOCITY: float = -500.0
# 長押し時の加速度（1秒あたりの速度増加）
const HOLD_ACCELERATION: float = -1000.0

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# ジャンプ開始時刻を記録
	jump_start_time = Time.get_ticks_msec() / 1000.0

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	jump_start_time = 0.0

## 入力処理
func handle_input(_delta: float) -> void:
	# 水平移動入力を処理
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		var speed: float = get_parameter("move_walk_speed")
		apply_movement(movement_input, speed)

## 物理演算処理
func physics_update(delta: float) -> void:
	# 現在時刻を取得
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var elapsed_time: float = current_time - jump_start_time

	# 長押し受付時間内かつボタンが押され続けており、上昇中の場合
	if elapsed_time < HOLD_DURATION and Input.is_action_pressed("jump") and player.velocity.y < 0.0:
		# 上昇速度を増加（最大-500まで）
		player.velocity.y = max(player.velocity.y + HOLD_ACCELERATION * delta, MAX_JUMP_VELOCITY)

	# 重力を適用
	apply_gravity(delta)

	# 落下開始（速度が0以上）したらFALL状態に遷移
	if player.velocity.y >= 0.0:
		player.update_animation_state("FALL")

class_name JumpState
extends BaseState

# ジャンプ開始時刻
var jump_start_time: float = 0.0

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	jump_start_time = Time.get_ticks_msec() / 1000.0
	# 慣性保持の初期化（BaseStateの共通メソッド使用）
	initialize_airborne_inertia()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	jump_start_time = 0.0
	# 慣性保持のクリーンアップ（BaseStateの共通メソッド使用）
	cleanup_airborne_inertia()

## 入力処理
func handle_input(_delta: float) -> void:
	# 空中でのアクション入力（攻撃・射撃）
	if handle_air_action_input():
		return

	# 空中での移動入力処理（慣性保持考慮 - BaseStateの共通メソッド使用）
	handle_airborne_movement_input()

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

class_name PlayerClosingState
extends PlayerBaseState

# ======================== 状態初期化・クリーンアップ ========================

## 状態名を取得
func get_state_name() -> String:
	return "CLOSING"

# 追従状態管理変数
var distance_traveled: float = 0.0  # 移動距離
var max_closing_distance: float = 0.0  # 最大追従距離（ピクセル）（パラメータから設定）
var start_position: Vector2 = Vector2.ZERO  # 開始位置

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 追従状態初期化
	distance_traveled = 0.0
	start_position = player.global_position

	# 前の状態に応じて速度と距離を設定
	var base_run_speed: float = get_parameter("move_run_speed")
	var speed_multiplier: float
	var forward_speed: float

	if player.previous_state and player.previous_state.get_state_name() == "RUN":
		# RUN状態からの遷移：速い速度で長距離追従
		speed_multiplier = get_parameter("move_closing_speed_multiplier_from_run")
		max_closing_distance = get_parameter("move_closing_max_distance_from_run")
	else:
		# 通常地上状態（IDLE, WALK）からの遷移：run速度で短距離追従
		speed_multiplier = get_parameter("move_closing_speed_multiplier_from_ground")
		max_closing_distance = get_parameter("move_closing_max_distance_from_ground")

	forward_speed = base_run_speed * speed_multiplier

	# Sprite2Dの向きに応じて前進
	var direction: float = 1.0 if sprite_2d.flip_h else -1.0
	player.velocity.x = direction * forward_speed

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	pass

# ======================== 入力処理 ========================

## 入力処理
func handle_input(delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(delta)
	if player.disable_input:
		return

	# ダブルタップ検出（回避）
	var dodge_direction: float = check_dodge_double_tap()
	if dodge_direction != 0.0:
		# ダブルタップされた方向にspriteを向けてから回避状態へ遷移
		sprite_2d.flip_h = dodge_direction > 0.0
		player.direction_x = dodge_direction
		player.change_state("DODGING")
		return

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面にいない場合は重力を適用してFALL状態に遷移
	if not player.is_grounded:
		apply_gravity(delta)
		player.change_state("FALL")
		return

	# 壁に衝突した場合、追従を中止してidle状態へ遷移
	if player.is_on_wall():
		player.change_state("IDLE")
		return

	# 前方のエネミーを検知（ポーリング方式）
	if detect_enemy_in_front():
		player.change_state("FIGHTING")
		return

	# 移動距離を計算
	distance_traveled = abs(player.global_position.x - start_position.x)

	# 最大追従距離に達した場合、fighting状態へ遷移
	if distance_traveled >= max_closing_distance:
		player.change_state("FIGHTING")
		return

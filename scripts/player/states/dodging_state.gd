class_name DodgingState
extends BaseState

# ======================== 状態初期化・クリーンアップ ========================

# 回避状態管理変数
var distance_traveled: float = 0.0  # 移動距離
var max_dodging_distance: float = 0.0  # 最大回避距離（ピクセル）（パラメータから設定）
var start_position: Vector2 = Vector2.ZERO  # 開始位置

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 全てのhurtboxを無効化（前のstateのhurtboxをクリア）
	player.disable_all_collision_boxes()

	# 回避状態初期化
	distance_traveled = 0.0
	start_position = player.global_position
	max_dodging_distance = get_parameter("move_dodging_distance")

	# 前進速度の設定（closingと同じ倍率適用で素早く回避）
	var base_run_speed: float = get_parameter("move_run_speed")
	var speed_multiplier: float = get_parameter("move_dodging_speed_multiplier")
	var forward_speed: float = base_run_speed * speed_multiplier
	# Sprite2Dの向きに応じて前進
	var direction: float = 1.0 if sprite_2d.flip_h else -1.0
	player.velocity.x = direction * forward_speed

# ======================== 入力処理 ========================

## 入力処理
func handle_input(delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(delta)
	if player.disable_input:
		return

	# 回避中はジャンプとしゃがみのみ受け付ける
	if can_jump():
		perform_jump()
		return

	if can_transition_to_squat():
		player.change_state("SQUAT")
		return

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面にいない場合は重力を適用してFALL状態に遷移
	if not player.is_grounded:
		apply_gravity(delta)
		player.change_state("FALL")
		return

	# 壁に衝突した場合、回避を中止してidle状態へ遷移
	if player.is_on_wall():
		player.change_state("IDLE")
		return

	# 移動距離を計算
	distance_traveled = abs(player.global_position.x - start_position.x)

	# 最大回避距離に達した場合、idle状態へ遷移
	if distance_traveled >= max_dodging_distance:
		player.change_state("IDLE")
		return

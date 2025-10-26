class_name RunState
extends BaseState

# ======================== 入力処理 ========================

## 入力処理（RUN状態固有）
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

	# RUN状態固有の攻撃入力チェック（closing状態への遷移）
	if is_fight_input():
		player.change_state("CLOSING")
		return

	# その他の入力はhandle_movement_state_inputに委譲
	# ただし攻撃入力は既に処理済みなので、handle_common_inputsを使わずに個別処理
	if can_jump():
		perform_jump()
		return

	if can_transition_to_squat():
		player.change_state("SQUAT")
		return

	if is_shooting_input():
		player.change_state("SHOOTING")
		return

	# 移動入力処理
	handle_movement_input_common("RUN", delta)

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面チェック処理（共通メソッド使用）
	handle_ground_physics(delta)
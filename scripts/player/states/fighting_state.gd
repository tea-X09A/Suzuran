class_name FightingState
extends BaseState

# ======================== シグナル定義 ========================
signal fighting_finished

# ======================== 戦闘状態管理変数 ========================
var fighting_timer: float = 0.0
var is_fighting_active: bool = false
var started_airborne: bool = false  # 状態開始時に空中にいたかのフラグ

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 攻撃が有効でない場合は処理を停止
	if not get_parameter("fighting_enabled"):
		return

	# 戦闘状態初期化
	is_fighting_active = true
	fighting_timer = get_parameter("move_fighting_duration")
	started_airborne = not player.is_on_floor()  # 開始時の空中状態を記録

	# 前進速度の設定（idle/walk時は同じ速度、run時はボーナス付き）
	if not started_airborne:  # 地上でのfighting時のみ前進
		var forward_speed: float = get_parameter("move_fighting_initial_speed")
		# 前の状態がRUNだった場合はボーナス速度を追加
		if is_running_state():
			forward_speed += get_parameter("move_fighting_run_bonus")
		# 現在の向きに応じて前進
		player.velocity.x = player.direction_x * forward_speed

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_fighting_animation_finished):
		animation_player.animation_finished.connect(_on_fighting_animation_finished)

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	end_fighting()
	started_airborne = false

## 入力処理
func handle_input(_delta: float) -> void:
	# 地上のみジャンプとしゃがみを受け付ける
	if can_jump():
		perform_jump()
		return

	if can_transition_to_squat():
		player.update_animation_state("SQUAT")
		return

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力適用
	if not player.is_on_floor():
		apply_gravity(delta)

	# 空中攻撃中に着地した場合、キャンセルして遷移
	if started_airborne and player.is_on_floor():
		end_fighting()
		_transition_on_landing()
		return

	# 地上fighting時に壁に衝突した場合、アニメーションをキャンセル
	if not started_airborne and player.is_on_floor() and player.is_on_wall():
		end_fighting()
		handle_action_end_transition()
		return

	# 通常の攻撃終了処理
	if not update_fighting_timer(delta):
		handle_action_end_transition()

## 着地時の状態遷移処理
func _transition_on_landing() -> void:
	if is_squat_input():
		player.squat_was_cancelled = false
		player.update_animation_state("SQUAT")
		return

	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		if is_dash_input():
			player.update_animation_state("RUN")
		else:
			player.update_animation_state("WALK")
	else:
		player.update_animation_state("IDLE")


# ======================== 戦闘状態制御メソッド ========================

## 戦闘タイマー更新
func update_fighting_timer(delta: float) -> bool:
	if not is_fighting_active:
		return false

	if fighting_timer > 0.0:
		fighting_timer -= delta
		if fighting_timer <= 0.0:
			end_fighting()
			return false
	return true

## 戦闘終了処理
func end_fighting() -> void:
	# 状態のリセット
	is_fighting_active = false
	fighting_timer = 0.0

	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animation_player and animation_player.animation_finished.is_connected(_on_fighting_animation_finished):
		animation_player.animation_finished.disconnect(_on_fighting_animation_finished)

	# 完了シグナルの発信
	fighting_finished.emit()

## アニメーション完了時のコールバック
func _on_fighting_animation_finished() -> void:
	end_fighting()

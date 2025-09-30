class_name FightingState
extends BaseState

# ======================== シグナル定義 ========================
signal fighting_finished

# ======================== 戦闘状態管理変数 ========================
var fighting_timer: float = 0.0
var is_fighting_active: bool = false

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 攻撃が有効でない場合は処理を停止
	if not get_parameter("fighting_enabled"):
		return

	# 戦闘状態初期化
	is_fighting_active = true
	fighting_timer = get_parameter("move_fighting_duration")

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_fighting_animation_finished):
		animation_player.animation_finished.connect(_on_fighting_animation_finished)

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	end_fighting()

## 入力処理（FIGHTING状態固有）
func handle_input(delta: float) -> void:
	# ジャンプ入力チェック
	if can_jump():
		perform_jump()
		return

	# しゃがみ入力チェック（遷移用）
	if can_transition_to_squat():
		player.update_animation_state("SQUAT")
		return

	# 攻撃入力と射撃入力は無視（キャンセル不可）

	# 移動入力のみ受け付ける（方向転換のため）
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		update_sprite_direction(movement_input)

## 物理演算処理
func physics_update(delta: float) -> void:
	# 攻撃タイマー更新
	if not update_fighting_timer(delta):
		# 攻撃終了時の状態遷移（共通メソッド使用）
		handle_action_end_transition()

	# 重力適用（空中攻撃の場合）
	if not player.is_on_floor():
		apply_gravity(delta)


# ======================== 戦闘状態制御メソッド ========================
## 戦闘タイマー更新（player.gdから呼び出し）
func update_fighting_timer(delta: float) -> bool:
	# 攻撃が有効でない場合または非アクティブ時は即座にfalseを返す
	if not get_parameter("fighting_enabled") or not is_fighting_active:
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
	# 攻撃が有効でない場合は何もしない
	if not get_parameter("fighting_enabled"):
		return

	end_fighting()

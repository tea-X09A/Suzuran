class_name PlayerSquatState
extends PlayerBaseState

# ======================== 状態初期化・クリーンアップ ========================

## 状態名を取得
func get_state_name() -> String:
	return "SQUAT"

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	set_animation_state("SQUAT")
	if player:
		player.velocity.x = 0.0

# ======================== 入力処理 ========================

## 入力処理（SQUAT状態固有）
func handle_input(delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(delta)
	if player.disable_input:
		return

	# 格闘後の硬直中の入力処理（共通メソッド使用）
	if handle_fighting_recovery():
		return

	# Examine入力チェック（最優先：examineエリア内でのみ有効）
	if handle_recovery_examine_input():
		return

	# ジャンプ入力チェック（しゃがみキャンセル）
	if can_jump():
		player.squat_was_cancelled = true  # キャンセルフラグを設定
		perform_jump()
		return

	# 攻撃入力チェック（しゃがみキャンセル）
	if is_fight_input():
		player.squat_was_cancelled = true  # キャンセルフラグを設定
		player.change_state("FIGHTING")
		return

	# 投擲入力チェック（しゃがみキャンセル）
	if is_throwing_input():
		player.squat_was_cancelled = true  # キャンセルフラグを設定
		player.change_state("THROWING")
		return

	# しゃがみ入力チェック - 離されたらIDLE状態に遷移
	if not is_squat_input():
		player.change_state("IDLE")
		return

	# 移動入力の処理（方向転換のみ、実際の移動はしない）
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		update_sprite_direction(movement_input)
		apply_friction(delta)

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	if not player:
		return

	# 地面にいない場合は重力を適用
	if not player.is_grounded:
		apply_gravity(delta)
		return

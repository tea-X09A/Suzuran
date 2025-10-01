class_name CaptureState
extends BaseState

# ======================== 定数定義 ========================

# CAPTURE状態から復帰時の無敵時間（秒）
const CAPTURE_RECOVERY_INVINCIBILITY_DURATION: float = 2.0

# ======================== 状態初期化 ========================

## CAPTURE状態開始時の初期化
func initialize_state() -> void:
	# AnimationTreeを一時的に無効化
	if player.animation_tree:
		player.animation_tree.active = false
	# CAPTURE状態用のアニメーションを再生
	_play_capture_animation()
	# 全てのenemyの移動をキャンセルし、その場で立ち止まらせる
	_stop_all_enemies()

## CAPTURE状態終了時のクリーンアップ
func cleanup_state() -> void:
	# AnimationTreeを再度有効化
	if player.animation_tree:
		player.animation_tree.active = true
	# 全てのenemyを表示し、通常のパトロールを再開させる
	_resume_all_enemies()

# ======================== 物理更新処理 ========================

## 物理演算ステップでの更新処理
func physics_update(delta: float) -> void:
	# CAPTURE状態では移動を完全に停止
	player.velocity.x = 0.0

	# 重力を適用
	apply_gravity(delta)

# ======================== 入力処理 ========================

## 入力処理（jumpのみでキャンセル可能）
func handle_input(_delta: float) -> void:
	# ジャンプ入力でCAPTURE状態をキャンセル
	if Input.is_action_just_pressed("jump"):
		# 復帰時に無敵状態を付与
		_apply_recovery_invincibility()

		# 地面にいる場合はジャンプ実行
		if player.is_on_floor():
			perform_jump()
		else:
			# 空中の場合はFALL状態に遷移
			player.update_animation_state("FALL")

# ======================== Enemy制御処理 ========================

## 全てのenemyの移動を停止し、非表示にする
func _stop_all_enemies() -> void:
	var enemies: Array = player.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("enter_capture_state"):
			enemy.enter_capture_state()

## 全てのenemyを表示し、パトロールを再開させる
func _resume_all_enemies() -> void:
	var enemies: Array = player.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("exit_capture_state"):
			enemy.exit_capture_state()

# ======================== アニメーション処理 ========================

## CAPTURE状態用のアニメーションを再生
func _play_capture_animation() -> void:
	# プレイヤーに設定されたアニメーション名を取得
	var animation_name: String = player.capture_animation_name
	# AnimationPlayerで直接再生
	if player.animation_player and player.animation_player.has_animation(animation_name):
		player.animation_player.play(animation_name)

# ======================== 無敵状態処理 ========================

## CAPTURE状態復帰時の無敵状態を付与
func _apply_recovery_invincibility() -> void:
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if down_state:
		# DownStateの復帰無敵フラグを有効化
		down_state.is_recovery_invincible = true
		down_state.recovery_invincibility_timer = CAPTURE_RECOVERY_INVINCIBILITY_DURATION
		# 視覚効果を設定
		player.invincibility_effect.set_invincible(CAPTURE_RECOVERY_INVINCIBILITY_DURATION)

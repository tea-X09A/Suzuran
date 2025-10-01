class_name CaptureState
extends BaseState

# ======================== 状態初期化 ========================

## CAPTURE状態開始時の初期化
func initialize_state() -> void:
	# 全てのenemyの移動をキャンセルし、その場で立ち止まらせる
	_stop_all_enemies()

## CAPTURE状態終了時のクリーンアップ
func cleanup_state() -> void:
	# 全てのenemyを表示し、通常のパトロールを再開させる
	_resume_all_enemies()

# ======================== 物理更新処理 ========================

## 物理演算ステップでの更新処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

# ======================== 入力処理 ========================

## 入力処理（jumpのみでキャンセル可能）
func handle_input(_delta: float) -> void:
	# ジャンプ入力でCAPTURE状態をキャンセル
	if Input.is_action_just_pressed("jump"):
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

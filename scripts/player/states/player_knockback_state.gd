class_name PlayerKnockbackState
extends PlayerBaseState

# ======================== 状態初期化・クリーンアップ ========================

## 状態名を取得
func get_state_name() -> String:
	return "KNOCKBACK"

## ノックバック状態初期化
func initialize_state() -> void:
	if player.down_state:
		player.down_state.was_in_air = false

	# ノックバック時に残像表示を停止
	player.stop_afterimage_display()

	# 全てのバフを解除
	player.clear_all_buffs()

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	if not player.down_state:
		return

	# タイマー更新
	player.down_state.update_down_state(delta)

	# 空中処理
	if not player.is_grounded:
		player.down_state.was_in_air = true
		apply_gravity(delta)
	# 着地判定（一度でも空中にいた場合のみ）
	elif player.down_state.was_in_air and player.down_state.is_in_knockback_state():
		player.down_state.start_down_state()

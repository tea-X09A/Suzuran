class_name FallState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 落下状態のハートボックスを設定
	switch_hurtbox(hurtbox.get_fall_hurtbox())

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 状態終了時のクリーンアップ（現在は特になし）
	pass
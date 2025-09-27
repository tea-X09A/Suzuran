class_name RunState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# ハートボックスを設定
	switch_hurtbox(hurtbox.get_run_hurtbox())

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 状態終了時のクリーンアップ（現在は特になし）
	pass
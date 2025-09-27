class_name IdleState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# AnimationTree状態設定（AnimationTreeが既に"IDLE"状態に遷移済み）
	switch_hurtbox(hurtbox.get_idle_hurtbox())

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 状態終了時のクリーンアップ（現在は特になし）
	pass
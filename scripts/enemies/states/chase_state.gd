class_name EnemyChaseState
extends BaseEnemyState

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	# 追跡開始時の処理
	pass

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# プレイヤー参照を取得
	var player: Node2D = get_player()

	# プレイヤーが存在しない場合はIDLE状態へ
	if not player:
		enemy.change_state("IDLE")
		return

	# プレイヤーの方向を計算
	var direction: float = sign(player.global_position.x - enemy.global_position.x)

	# プレイヤーの方向に移動
	apply_movement(direction, enemy.move_speed)

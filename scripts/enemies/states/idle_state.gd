class_name EnemyIdleState
extends BaseEnemyState

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	# 待機タイマーをリセット
	enemy.wait_timer = 0.0
	# 速度を0に設定
	enemy.velocity.x = 0.0

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# プレイヤーが検知されている場合は待機をスキップして追跡状態に移行
	if enemy.get_player():
		enemy.change_state("CHASE")
		return

	# 待機中
	enemy.velocity.x = 0.0
	enemy.wait_timer += delta

	# 待機時間が経過したらパトロール状態へ移行
	if enemy.wait_timer >= enemy.wait_duration:
		enemy.change_state("PATROL")

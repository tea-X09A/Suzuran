class_name EnemyIdleState
extends EnemyBaseState

# ======================== 定数 ========================

## FIGHTING状態後の待機時間（秒）
const FIGHTING_STUN_DURATION: float = 1.0

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	# 待機タイマーをリセット
	enemy.wait_timer = 0.0
	# 速度を0に設定
	enemy.velocity.x = 0.0

	if OS.is_debug_build():
		print("[EnemyIdleState] 待機状態に入りました")
	# ?アイコンは _on_player_lost() シグナルハンドラで既に表示されている

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# 待機中
	enemy.velocity.x = 0.0
	enemy.wait_timer += delta

	# FIGHTING状態後のIDLE状態の場合、特別な待機時間を使用
	var required_wait_time: float = FIGHTING_STUN_DURATION if enemy.is_after_fighting else enemy.wait_duration

	# 待機時間が経過していない場合
	if enemy.wait_timer < required_wait_time:
		# プレイヤーが検知された場合（通常のIDLE状態のみ）
		if not enemy.is_after_fighting and should_chase_player():
			return
		# まだ待機を継続
		return

	# 待機時間が経過した場合の状態遷移処理
	_handle_wait_timeout()

## 待機時間経過後の状態遷移処理
func _handle_wait_timeout() -> void:
	# FIGHTING状態後の場合
	if enemy.is_after_fighting:
		enemy.is_after_fighting = false
		# プレイヤーを見失っている場合はPATROL、そうでなければCHASE
		if enemy.has_lost_player:
			enemy.change_state("PATROL")
		else:
			enemy.change_state("CHASE")
	# 通常のIDLE状態の場合はPATROL状態に遷移
	else:
		enemy.change_state("PATROL")

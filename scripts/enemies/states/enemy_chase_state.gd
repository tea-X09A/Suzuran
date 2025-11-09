class_name EnemyChaseState
extends EnemyBaseState

# ======================== 定数 ========================

## プレイヤーとのX座標の差がこの値以下の場合は移動しない（振動防止）
const MIN_MOVE_THRESHOLD: float = 10.0

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

	# プレイヤーとのX座標の差を計算
	var x_diff: float = player.global_position.x - enemy.global_position.x
	var direction: float = 0.0

	if abs(x_diff) > MIN_MOVE_THRESHOLD:
		direction = sign(x_diff)

	# X座標の差が閾値以下の場合は移動しない
	if direction != 0.0:
		# 壁衝突判定
		if enemy.is_on_wall():
			var wall_normal: Vector2 = enemy.get_wall_normal()
			# wall_normalは壁から離れる方向を指す
			# 移動方向と壁法線の符号が異なる場合、壁に向かって移動している
			var moving_into_wall: bool = sign(wall_normal.x) != sign(direction)

			if moving_into_wall:
				# プレイヤーを見失う処理
				var detection_comp = enemy.detection_component
				if detection_comp:
					var lost_player: Node2D = detection_comp.get_player()
					if lost_player:
						# 検知状態をリセットしてから見失いシグナルを発火
						detection_comp.clear_player()
						detection_comp.player_lost.emit(lost_player)
				else:
					# detection_componentがない場合は直接IDLE状態へ
					enemy.change_state("IDLE")
				return

		# プレイヤーの方向に移動
		apply_movement(direction, enemy.chase_move_speed)

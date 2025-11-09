class_name EnemyChaseState
extends EnemyBaseState

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

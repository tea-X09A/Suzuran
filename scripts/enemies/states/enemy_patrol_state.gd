class_name EnemyPatrolState
extends EnemyBaseState

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	# パトロール目標位置を生成（常にランダム生成）
	_generate_random_patrol_target()

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# 壁衝突判定
	if enemy.is_on_wall():
		var wall_normal: Vector2 = enemy.get_wall_normal()
		var direction_to_target: float = sign(enemy.target_position.x - enemy.global_position.x)
		# wall_normalは壁から離れる方向を指す
		# 移動方向と壁法線の符号が異なる場合、壁に向かって移動している
		var moving_into_wall: bool = sign(wall_normal.x) != sign(direction_to_target)

		# 壁に向かって移動しようとしている場合のみ、逆方向へターゲットを再設定
		if moving_into_wall:
			# 逆方向移動のために現在の移動方向を記録
			enemy.last_movement_direction = direction_to_target
			_generate_reverse_patrol_target()
			return

	# パトロール移動
	_patrol_movement()

# ======================== プライベートメソッド ========================

## パトロール移動処理
func _patrol_movement() -> void:
	# 目標位置への方向を計算
	var direction: float = sign(enemy.target_position.x - enemy.global_position.x)
	var distance_to_target: float = abs(enemy.target_position.x - enemy.global_position.x)

	# 目標位置に到達したかチェック
	if distance_to_target <= enemy.arrival_threshold:
		enemy.change_state("IDLE")
	else:
		# 目標位置へ移動
		apply_movement(direction, enemy.patrol_move_speed)
		# 進もうとしている方向を記録
		enemy.last_movement_direction = direction

## ランダムなパトロール目標位置を生成
func _generate_random_patrol_target() -> void:
	# 左右のランダムな方向を決定(-1: 左, 1: 右)
	var direction: float = 1.0 if randf() > 0.5 else -1.0
	# 移動距離をランダムに生成
	var move_distance: float = randf_range(enemy.patrol_range * 0.5, enemy.patrol_range)
	# 現在位置から左右に目標位置を設定
	var target_x: float = enemy.global_position.x + (direction * move_distance)
	enemy.target_position = Vector2(target_x, enemy.global_position.y)

## 壁衝突後の逆方向パトロール目標位置を生成
func _generate_reverse_patrol_target() -> void:
	# 直前に進もうとした方向の逆方向に移動
	var reverse_direction: float = -enemy.last_movement_direction
	# 現在位置から逆方向にpatrol_rangeの距離だけ移動
	var move_distance: float = enemy.patrol_range
	# 現在位置から逆方向に目標位置を設定
	var target_x: float = enemy.global_position.x + (reverse_direction * move_distance)
	enemy.target_position = Vector2(target_x, enemy.global_position.y)

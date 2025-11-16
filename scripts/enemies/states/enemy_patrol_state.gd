class_name EnemyPatrolState
extends EnemyBaseState

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	# 見失い状態をリセット（PATROL状態に入った時点で見失い処理は完了）
	if enemy.has_lost_player:
		enemy.reset_lost_player_state()

	# パトロール目標位置を生成（常にランダム生成）
	_generate_random_patrol_target()

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# 現在の移動方向を計算（壁衝突と段差検出で共用）
	var direction_to_target: float = sign(enemy.target_position.x - enemy.global_position.x)

	# 壁衝突判定
	if enemy.is_on_wall():
		var wall_normal: Vector2 = enemy.get_wall_normal()
		# wall_normalは壁から離れる方向を指す
		# 移動方向と壁法線の符号が異なる場合、壁に向かって移動している
		var moving_into_wall: bool = sign(wall_normal.x) != sign(direction_to_target)

		# 壁に向かって移動しようとしている場合のみ、逆方向へターゲットを再設定
		if moving_into_wall:
			# 逆方向移動のために現在の移動方向を記録
			enemy.last_movement_direction = direction_to_target
			_generate_reverse_patrol_target()
			return

	# 段差検出判定
	if _is_cliff_ahead(direction_to_target):
		# デバッグ出力
		if OS.is_debug_build():
			print("[Enemy] 段差を検出しました。逆方向へ移動します。")
		# 現在の移動方向を記録
		enemy.last_movement_direction = direction_to_target
		# 壁衝突時と同じ処理で逆方向へ
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

## 進行方向に段差があるかチェック
## @param direction_to_target 目標位置への方向（-1: 左, 1: 右, 0: 静止）
## @return bool - 段差がある場合true
func _is_cliff_ahead(direction_to_target: float) -> bool:
	# 進行方向が0の場合は段差チェック不要
	if direction_to_target == 0.0:
		return false

	# 進行方向に応じて適切なRayCastを選択
	var edge_detector: RayCast2D = null
	if direction_to_target < 0:
		# 左方向へ移動中
		edge_detector = enemy.left_edge_detector
	elif direction_to_target > 0:
		# 右方向へ移動中
		edge_detector = enemy.right_edge_detector

	# RayCastが存在し、床を検出していない場合は段差あり
	if edge_detector and not edge_detector.is_colliding():
		return true

	return false

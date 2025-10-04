class_name EnemyPatrolState
extends BaseEnemyState

## ステート開始時の処理
func initialize_state() -> void:
	# パトロール目標位置を生成
	# 壁衝突後の場合は逆方向へ移動
	if enemy.hit_wall:
		_generate_reverse_patrol_target()
		enemy.distance_since_collision = 0.0
	else:
		_generate_random_patrol_target()

## ステート開始時の処理
var previous_position: Vector2 = Vector2.ZERO

## 物理演算処理
func physics_update(delta: float) -> void:
	# 前フレームの位置を記録
	if previous_position == Vector2.ZERO:
		previous_position = enemy.global_position

	# 重力を適用
	apply_gravity(delta)

	# パトロール移動
	_patrol_movement()

	# 壁衝突後の移動距離が一定以上の場合のみ壁衝突判定を行う
	if not (enemy.hit_wall and enemy.distance_since_collision < enemy.min_distance_from_wall) and enemy.is_on_wall():
		# 壁に衝突した場合の処理
		enemy.hit_wall = true
		enemy.distance_since_collision = 0.0
		# 待機状態へ移行
		enemy.change_state("IDLE")

	# 移動距離を更新（壁衝突後の場合）
	if enemy.hit_wall:
		enemy.distance_since_collision += enemy.global_position.distance_to(previous_position)

		if enemy.distance_since_collision >= enemy.min_distance_from_wall:
			# 十分な距離を移動したので hit_wall フラグをクリア
			enemy.hit_wall = false

	# 次フレームのために現在位置を記録
	previous_position = enemy.global_position

## パトロール移動処理
func _patrol_movement() -> void:
	# 目標位置への方向を計算
	var direction: float = sign(enemy.target_position.x - enemy.global_position.x)

	# 目標位置に到達したかチェック
	if abs(enemy.target_position.x - enemy.global_position.x) <= enemy.arrival_threshold:
		# 到達したら待機状態へ移行
		enemy.change_state("IDLE")
	else:
		# 目標位置へ移動
		apply_movement(direction, enemy.move_speed)
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
	# 直前に進もうとした方向の逆方向にランダムな位置を生成
	var reverse_direction: float = -enemy.last_movement_direction
	# 現在位置から逆方向に移動する距離をランダムに生成（patrol_rangeの50%～100%の距離）
	var move_distance: float = randf_range(enemy.patrol_range * 0.5, enemy.patrol_range)
	# 現在位置から逆方向に目標位置を設定
	var target_x: float = enemy.global_position.x + (reverse_direction * move_distance)
	enemy.target_position = Vector2(target_x, enemy.global_position.y)

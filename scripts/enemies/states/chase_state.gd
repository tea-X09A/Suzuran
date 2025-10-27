class_name EnemyChaseState
extends BaseEnemyState

# ======================== 変数定義 ========================

## 前フレームの位置を記録する変数
var previous_position: Vector2 = Vector2.ZERO

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	# 追跡開始時の処理
	previous_position = Vector2.ZERO

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 前フレームの位置を記録
	if previous_position == Vector2.ZERO:
		previous_position = enemy.global_position

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

	# 壁衝突後の移動距離が一定以上の場合のみ壁衝突判定を行う
	if not (enemy.hit_wall and enemy.distance_since_collision < enemy.min_distance_from_wall) and enemy.is_on_wall():
		# 壁の方向を取得
		var wall_normal: Vector2 = enemy.get_wall_normal()
		var moving_into_wall: bool = sign(wall_normal.x) == sign(direction)

		if moving_into_wall:
			# 壁に向かって移動しようとしている場合、壁衝突フラグを立てる
			enemy.hit_wall = true
			enemy.distance_since_collision = 0.0

	# 壁衝突フラグが立っている場合、壁から離れる方向に移動
	if enemy.hit_wall:
		# 壁の法線方向（壁から離れる方向）に移動
		var wall_normal: Vector2 = enemy.get_wall_normal()
		var escape_direction: float = sign(wall_normal.x)
		apply_movement(escape_direction, enemy.move_speed)

		# 移動距離を更新
		enemy.distance_since_collision += enemy.global_position.distance_to(previous_position)

		# 十分な距離を移動したら hit_wall フラグをクリア
		if enemy.distance_since_collision >= enemy.min_distance_from_wall:
			enemy.hit_wall = false
			enemy.distance_since_collision = 0.0
	else:
		# プレイヤーの方向に移動
		apply_movement(direction, enemy.move_speed)

	# 次フレームのために現在位置を記録
	previous_position = enemy.global_position

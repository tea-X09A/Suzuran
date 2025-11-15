class_name EnemyChaseState
extends EnemyBaseState

# ======================== 定数 ========================

## プレイヤーとのX座標の差がこの値以下の場合は移動しない（振動防止）
const MIN_MOVE_THRESHOLD: float = 10.0
## プレイヤーとの距離がこの値以下の場合、FIGHTING状態に遷移
const FIGHTING_DISTANCE: float = 300.0

# ======================== ステート初期化 ========================

## ステート初期化処理
func initialize_state() -> void:
	super.initialize_state()
	if OS.is_debug_build():
		print("[EnemyChaseState] チェイス状態に入りました")

	# チェイス開始時に見失い状態をリセット
	enemy.reset_lost_player_state()

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# プレイヤー検知状態を更新
	var player_detected: bool = false
	if enemy.detection_component:
		player_detected = enemy.detection_component.is_player_tracked()
		enemy.update_player_detection(player_detected)

	# プレイヤーを見失った場合の処理
	if enemy.has_lost_player:
		# IDLE状態へ遷移（待機してからパトロールに移行）
		# ?アイコンは _on_player_lost() シグナルハンドラで既に表示されている
		enemy.change_state("IDLE")
		return

	# プレイヤー参照を取得
	var player: Node2D = get_player()

	# プレイヤー参照が無効な場合はパトロール状態へ（安全策）
	# 通常は has_lost_player チェックで処理されるが、
	# detection_componentの状態とのズレが生じた場合のフォールバック
	if not player:
		enemy.change_state("PATROL")
		return

	# プレイヤーとの距離をチェック
	var distance_to_player: float = enemy.global_position.distance_to(player.global_position)

	# 距離が300px以下の場合、FIGHTING状態に遷移
	if distance_to_player <= FIGHTING_DISTANCE:
		enemy.change_state("FIGHTING")
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
					# 既に取得済みのplayer参照を使用
					if player:
						# 検知状態をリセットしてから見失いシグナルを発火
						detection_comp.clear_player()
						detection_comp.player_lost.emit(player)
				else:
					# detection_componentがない場合は直接IDLE状態へ
					enemy.change_state("IDLE")
				return

		# プレイヤーの方向に移動
		apply_movement(direction, enemy.chase_move_speed)

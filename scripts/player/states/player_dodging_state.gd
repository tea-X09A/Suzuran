class_name PlayerDodgingState
extends PlayerBaseState

# ======================== 定数 ========================

## ジャスト回避判定の範囲（ピクセル）
const JUST_DODGE_CHECK_RANGE: float = 200.0

# ======================== 状態初期化・クリーンアップ ========================

## 状態名を取得
func get_state_name() -> String:
	return "DODGING"

# 回避状態管理変数
var distance_traveled: float = 0.0  # 移動距離
var max_dodging_distance: float = 0.0  # 最大回避距離（ピクセル）（パラメータから設定）
var start_position: Vector2 = Vector2.ZERO  # 開始位置

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 回避状態初期化
	distance_traveled = 0.0
	start_position = player.global_position
	max_dodging_distance = get_parameter("move_dodging_distance")

	# 空中での回避の場合、使用済みフラグを設定
	if not player.is_grounded:
		player.has_used_air_dodge = true

	# ジャスト回避判定
	if check_just_dodge():
		if OS.is_debug_build():
			print("ジャスト回避成功")
		# 速度上昇バフを適用（パラメータから取得）
		var buff_duration: float = get_parameter("just_dodge_buff_duration")
		var speed_buff: SpeedBoostBuff = SpeedBoostBuff.new(player, buff_duration)
		player.apply_buff(speed_buff)

	# 前進速度の設定（run状態の倍率適用で素早く回避）
	var base_run_speed: float = get_speed_parameter("move_run_speed")
	var speed_multiplier: float = get_parameter("move_dodging_speed_multiplier")
	var forward_speed: float = base_run_speed * speed_multiplier
	# Sprite2Dの向きに応じて前進
	var direction: float = 1.0 if sprite_2d.flip_h else -1.0
	player.velocity.x = direction * forward_speed
	# 空中での回避時に高度を維持するため、垂直速度を0にする
	player.velocity.y = 0.0

# ======================== 状態クリーンアップ ========================

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 回避終了後の硬直時間を設定
	player.dodge_recovery_time = get_parameter("dodging_recovery_duration")
	# 速度をゼロにして慣性を消す
	player.velocity.x = 0.0

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(_delta: float) -> void:
	# 空中での回避時は重力を適用せず高度を維持
	# 地上での回避時も重力は不要（地面を滑るように移動）

	# 壁に衝突した場合、回避を中止して適切な状態へ遷移
	if player.is_on_wall():
		# 地上ならIDLE、空中ならFALLに遷移
		if player.is_grounded:
			player.change_state("IDLE")
		else:
			player.change_state("FALL")
		return

	# 移動距離を計算
	distance_traveled = abs(player.global_position.x - start_position.x)

	# 最大回避距離に達した場合、適切な状態へ遷移
	if distance_traveled >= max_dodging_distance:
		# 地上ならIDLE、空中ならFALLに遷移
		if player.is_grounded:
			player.change_state("IDLE")
		else:
			player.change_state("FALL")
		return

# ======================== ジャスト回避判定 ========================

## 範囲内の敵の攻撃をチェックしてジャスト回避判定
func check_just_dodge() -> bool:
	var enemies: Array = player.get_tree().get_nodes_in_group("enemies")
	var just_dodge_success: bool = false

	for enemy in enemies:
		# Enemyクラスでない場合はスキップ
		if not enemy is Enemy:
			continue

		# 距離チェック
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance > JUST_DODGE_CHECK_RANGE:
			continue

		# hitboxがアクティブかチェック（攻撃中判定）
		if enemy.hitbox and enemy.hitbox.visible and enemy.hitbox.monitoring:
			just_dodge_success = true
			break

	# ジャスト回避成功時、検知していた全エネミーを見失わせる
	if just_dodge_success:
		make_enemies_lose_player(enemies)

	return just_dodge_success

## ジャスト回避成功時に全エネミーにプレイヤーを見失わせる
func make_enemies_lose_player(enemies: Array) -> void:

	for enemy in enemies:
		# Enemyクラスでない場合はスキップ
		if not enemy is Enemy:
			continue

		# detection_componentが存在し、プレイヤーを追跡している場合
		var detection_comp = enemy.detection_component
		if not detection_comp:
			continue

		if not detection_comp.is_player_tracked():
			continue

		# ジャスト回避によるプレイヤー喪失処理を呼び出す
		# エネミー側でhas_lost_playerフラグが設定される
		enemy.on_player_just_dodged()
		if OS.is_debug_build():
			print("[PlayerDodgingState] エネミーにジャスト回避を通知しました")

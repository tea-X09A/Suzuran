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
var min_dodging_distance: float = 0.0  # 最小回避距離（ピクセル）（パラメータから設定）
var max_dodging_distance: float = 0.0  # 最大回避距離（ピクセル）（パラメータから設定）
var current_target_distance: float = 0.0  # 現在の目標距離（長押しで延長された値を保持）
var start_position: Vector2 = Vector2.ZERO  # 開始位置
var elapsed_time: float = 0.0  # 回避開始からの経過時間
var is_cancelled: bool = false  # 他のアクションでキャンセルされたかどうか

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 回避状態初期化
	distance_traveled = 0.0
	elapsed_time = 0.0
	is_cancelled = false
	start_position = player.global_position
	min_dodging_distance = get_parameter("move_dodging_min_distance")
	# 最大距離に速度倍率を適用（バフ時は自動的に距離が延長される）
	max_dodging_distance = get_parameter("move_dodging_max_distance") * player.speed_multiplier
	# 初期目標距離は最小距離から開始
	current_target_distance = min_dodging_distance

	# 回避使用済みフラグを設定（地上・空中共通）
	player.has_used_ground_dodge = true

	# 残像表示を開始（他のステートでも継続表示）
	player.start_afterimage_display()

	# 回避中は無敵：全hurtboxを無効化
	if player.collision_component:
		player.collision_component.disable_all_collision_boxes()

	# ジャスト回避判定
	if check_just_dodge():
		if OS.is_debug_build():
			print("ジャスト回避成功")
		# 速度上昇バフを適用
		var speed_buff: SpeedBoostBuff = SpeedBoostBuff.new(player)
		player.apply_buff(speed_buff)

	# 前進速度の設定（初速は高めに設定）
	# 回避速度はバフの影響を受けないよう、基本走行速度を使用
	var base_run_speed: float = get_parameter("move_run_speed")
	var initial_speed_multiplier: float = get_parameter("move_dodging_initial_speed_multiplier")
	var forward_speed: float = base_run_speed * initial_speed_multiplier
	# Sprite2Dの向きに応じて前進
	var direction: float = 1.0 if sprite_2d.flip_h else -1.0
	player.velocity.x = direction * forward_speed
	# 空中での回避時に高度を維持するため、垂直速度を0にする
	player.velocity.y = 0.0

# ======================== 状態クリーンアップ ========================

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 回避後の硬直時間を設定
	player.dodge_recovery_time = get_parameter("dodging_recovery_duration")

	# 回避終了：全hurtboxを有効化
	if player.collision_component:
		player.collision_component.enable_all_collision_boxes()

	# 回避終了時に速度をゼロにする
	# ただし、キャンセルされた場合（地上・空中問わず）または速度倍率が適用されている場合は慣性を維持
	if not is_cancelled and player.speed_multiplier <= 1.0:
		player.velocity.x = 0.0

	# キャンセルされずに回避が終了した場合は残像表示を停止
	# ただし、速度倍率が適用されていて空中の場合は着地まで残像を継続表示する
	# キャンセルされた場合は遷移先のステート（Fighting/Throwing）で停止される
	if not is_cancelled:
		# 速度倍率が1.0以下の場合、または地上で終了した場合は残像を停止
		if player.speed_multiplier <= 1.0 or player.is_grounded:
			player.stop_afterimage_display()

# ======================== 入力処理 ========================

## 入力処理（DODGING状態固有）
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	# 回避開始から一定時間経過後のみ攻撃入力を受け付ける
	var input_delay: float = get_parameter("dodging_input_delay")
	if elapsed_time < input_delay:
		return

	# 地上でのジャンプ入力チェック
	if player.is_grounded and can_jump():
		is_cancelled = true
		perform_jump()
		return

	# 攻撃入力チェック
	if is_fight_input():
		is_cancelled = true
		player.change_state("FIGHTING")
		return

	# 投擲入力チェック
	if is_throwing_input():
		# クールタイム中は投擲不可
		if not player.can_throw():
			return
		is_cancelled = true
		player.change_state("THROWING")
		return

# ======================== 物理演算処理 ========================

## 回避終了時の状態遷移処理（地上/空中に応じて適切な状態へ遷移）
func transition_to_appropriate_state() -> void:
	if player.is_grounded:
		player.change_state("IDLE")
	else:
		player.change_state("FALL")

## 物理演算処理
func physics_update(_delta: float) -> void:
	# 経過時間をカウント
	elapsed_time += _delta

	# 空中での回避時は重力を適用せず高度を維持
	# 地上での回避時も重力は不要（地面を滑るように移動）

	# 移動距離を計算（最初に計算して後続の処理で使用）
	distance_traveled = abs(player.global_position.x - start_position.x)

	# パラメータから値を取得
	var hold_duration: float = get_parameter("dodging_hold_duration")
	var deceleration: float = get_parameter("dodging_deceleration")

	# 長押し判定
	var is_holding: bool = elapsed_time < hold_duration and is_dodge_pressed()

	# 長押し中は目標距離を延長（一度延長された距離は維持される）
	if is_holding:
		# 長押し受付時間内かつボタンが押されている場合、距離を延長
		var progress: float = elapsed_time / hold_duration
		current_target_distance = lerp(min_dodging_distance, max_dodging_distance, progress)

	# 速度処理（速度倍率が適用されている場合は減速率を低下）
	var speed_direction: float = sign(player.velocity.x)
	var current_speed: float = abs(player.velocity.x)

	# 速度倍率が1.0より大きい場合は減速率を30%に低下
	var effective_deceleration: float = deceleration
	if player.speed_multiplier > 1.0:
		effective_deceleration *= 0.3

	current_speed = max(0.0, current_speed - effective_deceleration * _delta)
	player.velocity.x = speed_direction * current_speed

	# 壁に衝突した場合、回避を中止して適切な状態へ遷移
	if player.is_on_wall():
		transition_to_appropriate_state()
		return

	# 目標距離に達した場合、または速度が0になった場合、適切な状態へ遷移
	if distance_traveled >= current_target_distance or current_speed <= 0.0:
		transition_to_appropriate_state()
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

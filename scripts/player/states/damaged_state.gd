class_name DamagedState
extends BaseState

# ダメージ処理完了時のシグナル
signal damaged_finished

# ダメージ状態の各種タイマー
var damage_timer: float = 0.0
var invincibility_timer: float = 0.0
var knockback_timer: float = 0.0
var down_timer: float = 0.0
var recovery_invincibility_timer: float = 0.0

# ダメージ状態フラグ
var is_damaged: bool = false
var is_invincible: bool = false
var is_in_down_state: bool = false
var is_recovery_invincible: bool = false

# ノックバック関連
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_force_value: float = 0.0
var current_animation_type: String = ""

func enter() -> void:
	player.state = Player.PLAYER_STATE.DAMAGED
	# ダメージ状態は State Machine で管理（is_damaged() メソッドで判定）

# ダメージ状態では全パラメータ（移動+ダメージ）を統合システムから取得
func get_parameters() -> Dictionary:
	return PlayerParameters.get_all_parameters(condition)

func process_physics(delta: float) -> void:
	# タイマー更新処理
	update_damaged_timer(delta)
	update_invincibility_timer(delta)

	# ダメージが終了したかチェック
	if not is_damaged:
		# ダメージ終了後は適切な状態に遷移
		transition_to_appropriate_state()
		return

	# ノックバック着地状態の場合は限定的な移動を許可
	if is_in_knockback_landing_state():
		var direction_x: float = Input.get_axis("left", "right")
		player.direction_x = direction_x
		# ダメージ中の制限された移動処理
		handle_movement(direction_x, false, false)

func handle_input(event: InputEvent) -> void:
	# ダメージ状態でのジャンプ入力処理
	if event.is_action_pressed("jump"):
		var can_jump: bool = is_in_knockback_state() or is_in_knockback_landing_state()
		if can_jump:
			handle_recovery_jump()
			player.handle_jump()

func exit() -> void:
	is_damaged = false
	# ダメージ状態は State Machine で管理（状態遷移で自動解除）

# ======================== ダメージ処理 ========================

func handle_damage(_damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	is_damaged = true
	# ダメージ状態は State Machine で管理（is_damaged() メソッドで判定）
	current_animation_type = animation_type

	# ノックバック中は無敵状態を維持
	is_invincible = true
	invincibility_timer = get_parameter("invincibility_duration")

	# 無敵状態開始時：全hurtboxを無効化
	player.deactivate_all_hurtboxes()

	# コリジョンは地形との当たり判定のため有効のまま維持
	damage_timer = get_parameter("damage_duration")
	knockback_timer = get_parameter("knockback_duration")
	knockback_direction = direction
	knockback_force_value = force

	var knockback_multiplier: float = get_parameter("knockback_multiplier")
	player.velocity.x = direction.x * force * knockback_multiplier
	player.velocity.y = -get_parameter("knockback_vertical_force")

	var log_prefix: String = get_parameter("log_prefix")
	var prefix_text: String = (log_prefix + "ダメージアニメーション開始: ") if log_prefix != "" else "ダメージアニメーション開始: "
	print(prefix_text, animation_type)

	var condition_prefix: String = get_parameter("animation_prefix")
	# 常にdamagedアニメーションを再生
	animated_sprite.play(condition_prefix + "_damaged")

# ======================== タイマー更新処理 ========================

func update_damaged_timer(delta: float) -> void:
	if not is_damaged:
		return

	damage_timer -= delta
	invincibility_timer -= delta
	knockback_timer -= delta

	if knockback_timer > 0.0:
		apply_continuous_knockback()

	# down状態の処理
	if is_in_down_state:
		down_timer -= delta

func apply_continuous_knockback() -> void:
	var knockback_multiplier: float = get_parameter("knockback_multiplier")

	# 地上でのノックバックは摩擦を適用して減衰させる
	if player.is_on_floor():
		# 地上では摩擦による減衰を適用
		var friction_factor: float = 0.85
		player.velocity.x = knockback_direction.x * knockback_force_value * knockback_multiplier * friction_factor
	else:
		# 空中では元の力を維持
		player.velocity.x = knockback_direction.x * knockback_force_value * knockback_multiplier

# ======================== ダウン状態処理 ========================

func start_down_state() -> void:
	if is_in_down_state:
		return

	is_in_down_state = true
	down_timer = get_parameter("down_duration")

	# down状態では無敵を解除（特殊なイベント実行のため）
	is_invincible = false
	invincibility_timer = 0.0

	# down状態開始時：down_hurtboxを有効化
	player.switch_hurtbox(player.down_hurtbox)

	var log_prefix: String = get_parameter("log_prefix")
	var prefix_text: String = (log_prefix + "ダウン状態開始") if log_prefix != "" else "ダウン状態開始"
	if log_prefix == "":
		prefix_text += " - 無敵解除"
	print(prefix_text)

	var condition_prefix: String = get_parameter("animation_prefix")
	animated_sprite.play(condition_prefix + "_down_01")

func finish_damaged() -> void:
	is_damaged = false
	# ダメージ状態は State Machine で管理（状態遷移で自動解除）
	is_in_down_state = false
	damage_timer = 0.0
	knockback_timer = 0.0
	down_timer = 0.0

	# down状態からの移行時に無敵時間を付与
	is_recovery_invincible = true
	recovery_invincibility_timer = get_parameter("recovery_invincibility_duration")

	var log_prefix: String = get_parameter("log_prefix")
	var prefix_text: String = (log_prefix + "ダメージ状態終了 - 無敵時間付与") if log_prefix != "" else "ダメージ状態終了 - 無敵時間付与"
	print(prefix_text)
	damaged_finished.emit()

func cancel_damaged() -> void:
	if is_damaged:
		finish_damaged()

# ======================== 無敵状態管理 ========================

func update_invincibility_timer(delta: float) -> void:
	if is_invincible and invincibility_timer > 0.0:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false
			# 無敵状態解除時：hurtboxを再有効化
			player.reactivate_current_hurtbox()

	update_recovery_invincibility_timer(delta)

func is_in_invincible_state() -> bool:
	return is_invincible or is_recovery_invincible

func is_in_knockback_landing_state() -> bool:
	return is_in_down_state

func is_in_knockback_state() -> bool:
	return is_damaged and not is_in_down_state

# ======================== 復帰処理 ========================

func handle_recovery_jump() -> void:
	if is_in_down_state:
		# down状態からのジャンプ: 無敵解除と復帰処理
		is_invincible = false
		is_recovery_invincible = false
		invincibility_timer = 0.0
		recovery_invincibility_timer = 0.0
		# 無敵強制解除時：hurtboxを再有効化
		player.reactivate_current_hurtbox()
		# 水平速度をリセットして垂直ジャンプにする
		player.velocity.x = 0.0
		finish_damaged()
	elif is_damaged and not is_in_down_state:
		# ノックバック状態からのジャンプ: モーションキャンセルと無敵時間付与
		var log_prefix: String = get_parameter("log_prefix")
		var prefix_text: String = (log_prefix + "ノックバック状態からのジャンプ復帰") if log_prefix != "" else "ノックバック状態からのジャンプ復帰"
		print(prefix_text)
		# ノックバック効果をキャンセル
		knockback_timer = 0.0
		knockback_direction = Vector2.ZERO
		knockback_force_value = 0.0
		# 水平速度をリセットして垂直ジャンプにする
		player.velocity.x = 0.0
		# ダメージ状態を終了し復帰無敵時間を付与
		finish_damaged()

func update_recovery_invincibility_timer(delta: float) -> void:
	if is_recovery_invincible and recovery_invincibility_timer > 0.0:
		recovery_invincibility_timer -= delta
		if recovery_invincibility_timer <= 0.0:
			is_recovery_invincible = false
			# 復帰無敵解除時：hurtboxを再有効化
			player.reactivate_current_hurtbox()
			var log_prefix: String = get_parameter("log_prefix")
			var prefix_text: String = (log_prefix + " recovery無敵時間終了") if log_prefix != "" else "recovery無敵時間終了"
			print(prefix_text)
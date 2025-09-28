class_name DownState
extends BaseState

# ダウン処理完了時のシグナル
signal down_finished

# ダウン状態の各種タイマー
var down_duration_timer: float = 0.0
var invincibility_timer: float = 0.0
var knockback_timer: float = 0.0
var down_timer: float = 0.0
var recovery_invincibility_timer: float = 0.0

# ダウン状態フラグ
var is_down: bool = false
var is_invincible: bool = false
var is_in_down_state: bool = false
var is_recovery_invincible: bool = false

# ノックバック関連
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_force_value: float = 0.0
var current_animation_type: String = ""

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	pass

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	is_down = false

## 入力処理（DOWN状態固有）
func handle_input(delta: float) -> void:
	# ダウン状態では復帰ジャンプのみ受け付ける
	try_recovery_jump()

	# ダウン中の移動処理
	handle_down_movement(delta)

	# 他の入力は無視

## 物理演算処理
func physics_update(delta: float) -> void:
	# ダウン状態更新
	if not update_down_state(delta):
		# ダウン終了時は状態遷移
		transition_to_appropriate_state()

	# 重力適用
	if not player.is_on_floor():
		apply_gravity(delta)


## ジャンプ入力チェック（DOWN状態では復帰ジャンプのみ）
func can_jump() -> bool:
	return is_in_knockback_state() or is_in_knockback_landing_state()

# ======================== ダメージ処理 ========================

func handle_damage(_damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	is_down = true
	# ダウン状態は State Machine で管理（is_down() メソッドで判定）
	current_animation_type = animation_type

	# ノックバック中は無敵状態を維持
	is_invincible = true
	invincibility_timer = get_parameter("invincibility_duration")


	# コリジョンは地形との当たり判定のため有効のまま維持
	down_duration_timer = get_parameter("damage_duration")
	knockback_timer = get_parameter("knockback_duration")
	knockback_direction = direction
	knockback_force_value = force

	var knockback_multiplier: float = get_parameter("knockback_multiplier")
	player.velocity.x = direction.x * force * knockback_multiplier
	player.velocity.y = -get_parameter("knockback_vertical_force")


	# ダメージアニメーションはAnimationTreeで自動実行

# ======================== ダウン状態制御（player.gdから呼び出し） ========================
## ダウン状態更新（player.gdから呼び出し）
func update_down_state(delta: float) -> bool:
	if not is_down:
		return false

	down_duration_timer -= delta
	invincibility_timer -= delta
	knockback_timer -= delta

	if knockback_timer > 0.0:
		apply_continuous_knockback()

	# down状態の処理
	if is_in_down_state:
		down_timer -= delta

	update_invincibility_timer(delta)
	return is_down

## ダウン中の移動処理（player.gdから呼び出し）
func handle_down_movement(_delta: float) -> void:
	# ノックバック着地状態の場合は限定的な移動を許可
	if is_in_knockback_landing_state():
		var direction_x: float = Input.get_axis("left", "right")
		player.direction_x = direction_x
		# ダメージ中の制限された移動処理
		if direction_x != 0.0:
			var walk_speed: float = get_parameter("move_walk_speed") * 0.5  # ダメージ中は速度半分
			player.velocity.x = direction_x * walk_speed
		else:
			player.velocity.x = 0.0

## ダウン状態でのジャンプ入力処理（player.gdから呼び出し）
func try_recovery_jump() -> bool:
	if Input.is_action_just_pressed("jump"):
		var can_jump: bool = is_in_knockback_state() or is_in_knockback_landing_state()
		if can_jump:
			handle_recovery_jump()
			return true
	return false

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


	# AnimationTreeが自動で適切なアニメーションを処理

func finish_down() -> void:
	is_down = false
	# ダメージ状態は State Machine で管理（状態遷移で自動解除）
	is_in_down_state = false
	down_duration_timer = 0.0
	knockback_timer = 0.0
	down_timer = 0.0

	# down状態からの移行時に無敵時間を付与
	is_recovery_invincible = true
	recovery_invincibility_timer = get_parameter("recovery_invincibility_duration")

	down_finished.emit()

func cancel_down() -> void:
	if is_down:
		finish_down()

# ======================== 無敵状態管理 ========================

func update_invincibility_timer(delta: float) -> void:
	if is_invincible and invincibility_timer > 0.0:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false

	update_recovery_invincibility_timer(delta)

func is_in_invincible_state() -> bool:
	return is_invincible or is_recovery_invincible

func is_in_knockback_landing_state() -> bool:
	return is_in_down_state

func is_in_knockback_state() -> bool:
	return is_down and not is_in_down_state

# ======================== 復帰処理 ========================

func handle_recovery_jump() -> void:
	if is_in_down_state:
		# down状態からのジャンプ: 無敵解除と復帰処理
		is_invincible = false
		is_recovery_invincible = false
		invincibility_timer = 0.0
		recovery_invincibility_timer = 0.0
		# 水平速度をリセットして垂直ジャンプにする
		player.velocity.x = 0.0
		finish_down()
	elif is_down and not is_in_down_state:
		# ノックバック状態からのジャンプ: モーションキャンセルと無敵時間付与
		# ノックバック効果をキャンセル
		knockback_timer = 0.0
		knockback_direction = Vector2.ZERO
		knockback_force_value = 0.0
		# 水平速度をリセットして垂直ジャンプにする
		player.velocity.x = 0.0
		# ダメージ状態を終了し復帰無敵時間を付与
		finish_down()

func update_recovery_invincibility_timer(delta: float) -> void:
	if is_recovery_invincible and recovery_invincibility_timer > 0.0:
		recovery_invincibility_timer -= delta
		if recovery_invincibility_timer <= 0.0:
			is_recovery_invincible = false

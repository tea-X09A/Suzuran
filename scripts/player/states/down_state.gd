class_name DownState
extends BaseState

signal down_finished


# ============================================================
# 変数定義
# ============================================================

# タイマー
var down_duration_timer: float = 0.0
var invincibility_timer: float = 0.0
var knockback_timer: float = 0.0
var down_timer: float = 0.0
var recovery_invincibility_timer: float = 0.0

# 状態フラグ
var is_down: bool = false
var is_invincible: bool = false
var is_in_down_state: bool = false
var is_recovery_invincible: bool = false
var was_in_air: bool = false

# ノックバック関連
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_force_value: float = 0.0
var current_animation_type: String = ""
var effect_type: String = ""


# ============================================================
# オーバーライドメソッド
# ============================================================

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	is_down = false


## 入力処理
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	try_recovery_jump()


## 物理演算処理
func physics_update(delta: float) -> void:
	# ダウン状態更新
	if not update_down_state(delta):
		# ダウン終了時の状態遷移
		if not player.is_grounded:
			player.change_state("FALL")
		else:
			handle_landing_transition()
			return

	# 重力適用
	if not player.is_grounded:
		apply_gravity(delta)


# ============================================================
# ダメージ・ダウン処理
# ============================================================

## ダメージ処理
func handle_damage(_damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	is_down = true
	current_animation_type = animation_type
	effect_type = animation_type

	down_duration_timer = get_parameter("damage_duration")
	knockback_timer = get_parameter("knockback_duration")
	knockback_direction = direction
	knockback_force_value = force

	# 効果タイプに応じた処理
	var knockback_multiplier: float = get_parameter("knockback_multiplier")
	# down効果の場合は吹き飛びを大きくする
	if effect_type == "down":
		knockback_multiplier *= 1.5
	player.velocity.x = direction.x * force * knockback_multiplier
	player.velocity.y = -get_parameter("knockback_vertical_force")

	if effect_type == "knockback":
		# knockback: 無敵状態付与
		is_invincible = true
		invincibility_timer = get_parameter("damage_duration")
	else:
		# down: 無敵なし
		is_invincible = false
		invincibility_timer = 0.0

	# KNOCKBACKステートへ遷移
	player.change_state("KNOCKBACK")


## ダウン状態更新
func update_down_state(delta: float) -> bool:
	if not is_down:
		return false

	# タイマー更新
	down_duration_timer -= delta
	knockback_timer -= delta
	if is_in_down_state:
		down_timer -= delta

	# ノックバック継続処理
	if knockback_timer > 0.0:
		apply_continuous_knockback()

	# 無敵時間更新
	if is_invincible and invincibility_timer > 0.0:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false

	return is_down


## ダウン状態開始
func start_down_state() -> void:
	if is_in_down_state:
		return

	# 共通処理
	was_in_air = false
	is_invincible = false
	invincibility_timer = 0.0
	player.velocity.x = 0.0

	if effect_type == "knockback":
		# knockback効果: IDLE状態へ遷移（無敵付与）
		is_down = false
		is_in_down_state = false
		down_duration_timer = 0.0
		knockback_timer = 0.0
		down_timer = 0.0
		effect_type = ""

		# 着地時に復帰無敵を付与
		is_recovery_invincible = true
		recovery_invincibility_timer = get_parameter("recovery_invincibility_duration")
		player.invincibility_effect.set_invincible(recovery_invincibility_timer)

		player.change_state("IDLE")
		down_finished.emit()
	else:
		# down効果: DOWN状態へ遷移
		is_in_down_state = true
		down_timer = get_parameter("down_duration")
		player.change_state("DOWN")


## ダウン状態終了
func finish_down(apply_invincibility: bool = true) -> void:
	is_down = false
	is_in_down_state = false
	down_duration_timer = 0.0
	knockback_timer = 0.0
	down_timer = 0.0
	effect_type = ""
	was_in_air = false

	if apply_invincibility:
		is_recovery_invincible = true
		recovery_invincibility_timer = get_parameter("recovery_invincibility_duration")
		player.invincibility_effect.set_invincible(recovery_invincibility_timer)

	down_finished.emit()


## ダウンキャンセル
func cancel_down() -> void:
	if is_down:
		finish_down()


# ============================================================
# ノックバック処理
# ============================================================

## ノックバック継続適用
func apply_continuous_knockback() -> void:
	var air_friction: float = 0.96
	player.velocity.x *= air_friction


# ============================================================
# ジャンプ・入力処理
# ============================================================

## ジャンプ入力チェック
func can_jump() -> bool:
	return is_in_knockback_state() or is_in_knockback_landing_state()


## ダウン状態でのジャンプ入力処理
func try_recovery_jump() -> bool:
	var jump_key: int = GameSettings.get_key_binding("jump")
	if _check_physical_key_just_pressed(jump_key, ALWAYS_ALLOWED_JUMP_KEYS, "jump") and can_jump():
		handle_recovery_jump()
		return true
	return false


## 復帰ジャンプ処理
func handle_recovery_jump() -> void:
	# 共通処理：速度リセットとジャンプ
	is_invincible = false
	invincibility_timer = 0.0
	player.velocity.x = 0.0
	player.velocity.y = get_parameter("jump_initial_velocity")

	# ノックバック状態からの場合は効果をキャンセル
	if is_in_knockback_state():
		knockback_timer = 0.0
		knockback_direction = Vector2.ZERO
		knockback_force_value = 0.0

	finish_down()
	player.change_state("JUMP")


# ============================================================
# 状態チェック
# ============================================================

## 無敵状態チェック
func is_in_invincible_state() -> bool:
	return is_invincible or is_recovery_invincible


## ノックバック状態チェック
func is_in_knockback_state() -> bool:
	return is_down and not is_in_down_state


## ノックバック着地状態チェック
func is_in_knockback_landing_state() -> bool:
	return is_in_down_state


# ============================================================
# 無敵時間管理
# ============================================================

## 復帰無敵時間更新
func update_recovery_invincibility_timer(delta: float) -> void:
	if is_recovery_invincible and recovery_invincibility_timer > 0.0:
		recovery_invincibility_timer -= delta
		if recovery_invincibility_timer <= 0.0:
			is_recovery_invincible = false
			player.invincibility_effect.clear_invincible()

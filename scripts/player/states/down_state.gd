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
var effect_type: String = ""  # "down" or "knockback"

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
		# ダウン終了時の状態遷移
		if not player.is_on_floor():
			player.update_animation_state("FALL")
		else:
			# squatボタンが押されていればsquat状態へ遷移
			if is_squat_input():
				player.squat_was_cancelled = false  # フラグをクリア
				player.update_animation_state("SQUAT")
				return

			# 地上での状態判定（移動入力に応じて遷移）
			var movement_input: float = get_movement_input()
			if movement_input != 0.0:
				if is_dash_input():
					player.update_animation_state("RUN")
				else:
					player.update_animation_state("WALK")
			else:
				player.update_animation_state("IDLE")

	# knockback中に着地した場合、downアニメーションに遷移
	if is_in_knockback_state() and player.is_on_floor():
		start_down_state()

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
	effect_type = animation_type

	# コリジョンは地形との当たり判定のため有効のまま維持
	down_duration_timer = get_parameter("damage_duration")
	knockback_timer = get_parameter("knockback_duration")
	knockback_direction = direction
	knockback_force_value = force

	# 効果タイプに応じた処理
	if effect_type == "knockback":
		# knockback: 緩やかなノックバック + 無敵状態付与
		var gentle_multiplier: float = 0.5  # downの半分の力
		player.velocity.x = direction.x * force * gentle_multiplier
		player.velocity.y = -get_parameter("knockback_vertical_force") * 0.7  # 垂直方向も緩やか

		# 無敵状態を付与
		is_invincible = true
		invincibility_timer = get_parameter("damage_duration")
	else:
		# down: 強いノックバック + 無敵なし
		var knockback_multiplier: float = get_parameter("knockback_multiplier")
		player.velocity.x = direction.x * force * knockback_multiplier
		player.velocity.y = -get_parameter("knockback_vertical_force")

		# ダウン時は無敵を付与しない
		is_invincible = false
		invincibility_timer = 0.0

	# KNOCKBACKステートへ遷移
	player.update_animation_state("KNOCKBACK")

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
	# ダウン中は左右入力を無効化
	pass

## ダウン状態でのジャンプ入力処理（player.gdから呼び出し）
func try_recovery_jump() -> bool:
	if Input.is_action_just_pressed("jump"):
		# knockback指定の場合はジャンプでキャンセルできない
		if effect_type == "knockback":
			return false

		var can_jump: bool = is_in_knockback_state() or is_in_knockback_landing_state()
		if can_jump:
			handle_recovery_jump()
			return true
	return false

func apply_continuous_knockback() -> void:
	# 空中では空気抵抗で緩やかに減衰
	var air_friction: float = 0.96  # 空中での摩擦係数（1フレームあたり4%減速）
	player.velocity.x *= air_friction

# ======================== ダウン状態処理 ========================

func start_down_state() -> void:
	if is_in_down_state:
		return

	# 効果タイプに応じた処理
	if effect_type == "knockback":
		# knockback: idle状態へ遷移
		finish_down()
		player.update_animation_state("IDLE")
	else:
		# down: down状態へ遷移
		is_in_down_state = true
		down_timer = get_parameter("down_duration")

		# down状態では無敵を解除（特殊なイベント実行のため）
		is_invincible = false
		invincibility_timer = 0.0

		# 着地時に水平速度をリセットしてその場で倒れる
		player.velocity.x = 0.0

		# DOWNステートへ遷移
		player.update_animation_state("DOWN")

func finish_down() -> void:
	is_down = false
	# ダメージ状態は State Machine で管理（状態遷移で自動解除）
	is_in_down_state = false
	down_duration_timer = 0.0
	knockback_timer = 0.0
	down_timer = 0.0
	effect_type = ""  # 効果タイプをクリア

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
		# down状態からのジャンプ: 無敵時間を付与して復帰
		is_invincible = false
		invincibility_timer = 0.0
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

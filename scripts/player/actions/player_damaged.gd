class_name PlayerDamaged
extends RefCounted

signal damaged_finished

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# 当たり判定コライダーへの参照
var collision_shape: CollisionShape2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# パラメータの定義 - conditionに応じて選択される
var damage_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"damage_duration": 0.6,                    # ダメージアニメーションの継続時間（秒）
		"knockback_vertical_force": 200.0,         # ノックバック時の垂直方向の力（ピクセル/秒）
		"invincibility_duration": 2.0,             # ダメージ時の無敵状態継続時間（秒）
		"knockback_duration": 0.3,                 # ノックバック効果の継続時間（秒）
		"down_duration": 1.0,                      # ダウン状態の継続時間（秒）
		"recovery_invincibility_duration": 2.0,    # 復帰後の無敵時間（秒）
		"log_prefix": "",                          # ログ出力のプレフィックス文字列
		"knockback_multiplier": 1.0                # ノックバック力の倍率
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"damage_duration": 0.8,                    # ダメージアニメーションの継続時間（秒）
		"knockback_vertical_force": 250.0,         # ノックバック時の垂直方向の力（ピクセル/秒）
		"invincibility_duration": 3.0,             # ダメージ時の無敵状態継続時間（秒）
		"knockback_duration": 0.4,                 # ノックバック効果の継続時間（秒）
		"down_duration": 1.2,                      # ダウン状態の継続時間（秒）
		"recovery_invincibility_duration": 3.5,    # 復帰後の無敵時間（秒）
		"log_prefix": "Expansion",                 # ログ出力のプレフィックス文字列
		"knockback_multiplier": 1.2                # ノックバック力の倍率
	}
}

# ダメージアニメーションの残り時間
var damage_timer: float = 0.0
# 無敵状態の残り時間
var invincibility_timer: float = 0.0
# ノックバックの残り時間
var knockback_timer: float = 0.0
# ダメージ状態フラグ
var is_damaged: bool = false
# 無敵状態フラグ
var is_invincible: bool = false
# ノックバック方向（正規化されたベクトル）
var knockback_direction: Vector2 = Vector2.ZERO
# ノックバック力の値（ピクセル/秒）
var knockback_force_value: float = 0.0
# アニメーションタイプ
var current_animation_type: String = ""
# down状態関連
var is_in_down_state: bool = false
var down_timer: float = 0.0
var is_recovery_invincible: bool = false
var recovery_invincibility_timer: float = 0.0

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = player.get_node("IdleCollision") as CollisionShape2D

func get_parameter(key: String) -> Variant:
	return damage_parameters[condition][key]

# ======================== ダメージ処理 ========================

func handle_damage(_damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	is_damaged = true
	current_animation_type = animation_type

	# ノックバック中は無敵状態を維持
	is_invincible = true
	invincibility_timer = get_parameter("invincibility_duration")

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

	var condition_prefix: String = "expansion" if condition == Player.PLAYER_CONDITION.EXPANSION else "normal"
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

	var log_prefix: String = get_parameter("log_prefix")
	var prefix_text: String = (log_prefix + "ダウン状態開始") if log_prefix != "" else "ダウン状態開始"
	if log_prefix == "":
		prefix_text += " - 無敵解除"
	print(prefix_text)

	var condition_prefix: String = "expansion" if condition == Player.PLAYER_CONDITION.EXPANSION else "normal"
	animated_sprite.play(condition_prefix + "_down_01")

func finish_damaged() -> void:
	is_damaged = false
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
			var log_prefix: String = get_parameter("log_prefix")
			var prefix_text: String = (log_prefix + " recovery無敵時間終了") if log_prefix != "" else "recovery無敵時間終了"
			print(prefix_text)

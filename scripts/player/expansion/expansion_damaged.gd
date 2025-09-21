class_name ExpansionDamaged
extends RefCounted

signal damaged_finished

# ダメージアニメーションの持続時間（秒、拡張状態用）
@export var damage_duration: float = 0.8
# 垂直方向のノックバック力（上方向への力、ピクセル/秒、拡張状態用）
@export var knockback_vertical_force: float = 250.0
# 無敵状態の持続時間（秒、拡張状態用）
@export var invincibility_duration: float = 3.0
# ノックバックモーションの持続時間（秒、拡張状態用）
@export var knockback_duration: float = 0.4
# down状態の持続時間（秒、拡張状態用）
@export var down_duration: float = 1.2
# down状態からの移行時に付与する無敵時間（秒、拡張状態用）
@export var recovery_invincibility_duration: float = 3.5

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# 当たり判定コライダーへの参照
var collision_shape: CollisionShape2D

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
# down状態関連（拡張状態用）
var is_in_down_state: bool = false
var down_timer: float = 0.0
var is_recovery_invincible: bool = false
var recovery_invincibility_timer: float = 0.0

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = player.get_node("CollisionShape2D") as CollisionShape2D

func handle_damage(damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	is_damaged = true
	current_animation_type = animation_type

	# ノックバック中は無敵状態を維持（拡張状態用）
	is_invincible = true
	invincibility_timer = invincibility_duration

	# コリジョンは地形との当たり判定のため有効のまま維持
	damage_timer = damage_duration
	knockback_timer = knockback_duration
	knockback_direction = direction
	knockback_force_value = force

	player.velocity.x = direction.x * force * 1.2
	player.velocity.y = -knockback_vertical_force

	print("Expansionダメージアニメーション開始: ", animation_type)
	var condition_prefix: String = "expansion" if player.condition == Player.PLAYER_CONDITION.EXPANSION else "normal"

	# 常にdamagedアニメーションを再生（拡張状態用）
	animated_sprite.play(condition_prefix + "_damaged")

func update_damaged_timer(delta: float) -> void:
	if not is_damaged:
		return

	damage_timer -= delta
	invincibility_timer -= delta
	knockback_timer -= delta

	if knockback_timer > 0.0:
		apply_continuous_knockback()


	# down状態の処理（拡張状態用）
	if is_in_down_state:
		down_timer -= delta

func apply_continuous_knockback() -> void:
	# 地上でのノックバックは摩擦を適用して減衰させる
	if player.is_on_floor():
		# 地上では摩擦による減衰を適用
		var friction_factor: float = 0.85
		player.velocity.x = knockback_direction.x * knockback_force_value * 1.2 * friction_factor
	else:
		# 空中では元の力を維持
		player.velocity.x = knockback_direction.x * knockback_force_value * 1.2

func start_down_state() -> void:
	if is_in_down_state:
		return

	is_in_down_state = true
	down_timer = down_duration

	# down状態開始時に無敵解除
	is_invincible = false
	invincibility_timer = 0.0

	print("Expansionダウン状態開始")
	var condition_prefix: String = "expansion" if player.condition == Player.PLAYER_CONDITION.EXPANSION else "normal"
	animated_sprite.play(condition_prefix + "_down_01")

func finish_damaged() -> void:
	is_damaged = false
	is_in_down_state = false
	damage_timer = 0.0
	knockback_timer = 0.0
	down_timer = 0.0

	# down状態からの移行時に無敵時間を付与（拡張状態用）
	is_recovery_invincible = true
	recovery_invincibility_timer = recovery_invincibility_duration

	print("Expansionダメージ状態終了 - 無敵時間付与")
	damaged_finished.emit()

func cancel_damaged() -> void:
	if is_damaged:
		finish_damaged()

func update_invincibility_timer(delta: float) -> void:
	if is_invincible and invincibility_timer > 0.0:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false

	update_recovery_invincibility_timer(delta)

func is_in_invincible_state() -> bool:
	return is_invincible or is_recovery_invincible

func is_in_knockback_state() -> bool:
	return is_damaged and not is_in_down_state

func is_in_knockback_landing_state() -> bool:
	return is_in_down_state

func handle_recovery_jump() -> void:
	if is_in_down_state:
		# down状態からのジャンプ: 無敵解除と復帰処理（拡張状態用）
		is_invincible = false
		is_recovery_invincible = false
		invincibility_timer = 0.0
		recovery_invincibility_timer = 0.0
		finish_damaged()
	elif is_damaged and not is_in_down_state:
		# ノックバック状態からのジャンプ: モーションキャンセルと無敵時間付与（拡張状態用）
		print("Expansionノックバック状態からのジャンプ復帰")
		# ノックバック効果をキャンセル
		knockback_timer = 0.0
		knockback_direction = Vector2.ZERO
		knockback_force_value = 0.0
		# ダメージ状態を終了し復帰無敵時間を付与
		finish_damaged()

func update_recovery_invincibility_timer(delta: float) -> void:
	if is_recovery_invincible and recovery_invincibility_timer > 0.0:
		recovery_invincibility_timer -= delta
		if recovery_invincibility_timer <= 0.0:
			is_recovery_invincible = false
			print("Expansion recovery無敵時間終了")

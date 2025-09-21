class_name NormalDamaged
extends RefCounted

signal damaged_finished

# ダメージアニメーションの持続時間（秒）
@export var damage_duration: float = 0.6
# 垂直方向のノックバック力（上方向への力、ピクセル/秒）
@export var knockback_vertical_force: float = 200.0
# 無敵状態の持続時間（秒）
@export var invincibility_duration: float = 2.0
# ノックバックモーションの持続時間（秒）
@export var knockback_duration: float = 0.3

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

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = player.get_node("CollisionShape2D") as CollisionShape2D

func handle_damage(damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	is_damaged = true
	is_invincible = true
	# 無敵状態時は当たり判定を無効化
	collision_shape.disabled = true
	damage_timer = damage_duration
	invincibility_timer = invincibility_duration
	knockback_timer = knockback_duration
	knockback_direction = direction
	knockback_force_value = force

	player.velocity.x = direction.x * force
	player.velocity.y = -knockback_vertical_force

	print("ダメージアニメーション開始: ", animation_type)
	var condition_prefix: String = "expansion" if player.condition == Player.PLAYER_CONDITION.EXPANSION else "normal"
	animated_sprite.play(condition_prefix + "_" + animation_type)

func update_damaged_timer(delta: float) -> void:
	if not is_damaged:
		return

	damage_timer -= delta
	invincibility_timer -= delta
	knockback_timer -= delta

	if knockback_timer > 0.0:
		apply_continuous_knockback()

	if invincibility_timer <= 0.0:
		is_invincible = false
		# 無敵状態終了時は当たり判定を有効化
		collision_shape.disabled = false

	if damage_timer <= 0.0:
		finish_damaged()

func apply_continuous_knockback() -> void:
	player.velocity.x = knockback_direction.x * knockback_force_value

func finish_damaged() -> void:
	is_damaged = false
	damage_timer = 0.0
	knockback_timer = 0.0
	print("ダメージアニメーション終了")
	damaged_finished.emit()

func cancel_damaged() -> void:
	if is_damaged:
		finish_damaged()

func update_invincibility_timer(delta: float) -> void:
	if is_invincible and invincibility_timer > 0.0:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false
			# 無敵状態終了時は当たり判定を有効化
			collision_shape.disabled = false

func is_in_invincible_state() -> bool:
	return is_invincible

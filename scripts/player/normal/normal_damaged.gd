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
# アニメーションタイプ
var current_animation_type: String = ""

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = player.get_node("CollisionShape2D") as CollisionShape2D

func handle_damage(damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	is_damaged = true
	current_animation_type = animation_type

	# downアニメーションの場合は無敵状態にしない
	if animation_type == "down":
		is_invincible = false
		invincibility_timer = 0.0
	else:
		is_invincible = true
		invincibility_timer = invincibility_duration

	# コリジョンは地形との当たり判定のため有効のまま維持
	damage_timer = damage_duration
	knockback_timer = knockback_duration
	knockback_direction = direction
	knockback_force_value = force

	player.velocity.x = direction.x * force
	player.velocity.y = -knockback_vertical_force

	print("ダメージアニメーション開始: ", animation_type)
	var condition_prefix: String = "expansion" if player.condition == Player.PLAYER_CONDITION.EXPANSION else "normal"

	# downアニメーションの場合でも、最初はdamagedアニメーションを再生
	if animation_type == "down":
		animated_sprite.play(condition_prefix + "_damaged")
	else:
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

	# downアニメーションの場合は着地するまで待つ
	if damage_timer <= 0.0:
		if current_animation_type == "down" and not player.is_on_floor():
			# 空中にいる間は着地まで待機（damagedアニメーションを維持）
			pass
		else:
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

func is_in_invincible_state() -> bool:
	return is_invincible

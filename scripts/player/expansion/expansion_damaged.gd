class_name ExpansionDamaged
extends RefCounted

signal damaged_finished

@export var damage_duration: float = 0.8
@export var knockback_vertical_force: float = 250.0
@export var invincibility_duration: float = 1.2
@export var knockback_duration: float = 0.4

var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D

var damage_timer: float = 0.0
var invincibility_timer: float = 0.0
var knockback_timer: float = 0.0
var is_damaged: bool = false
var is_invincible: bool = false
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_force_value: float = 0.0

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

func handle_damage(damage: int, animation_type: String, direction: Vector2, force: float) -> void:
	if is_invincible:
		return

	is_damaged = true
	is_invincible = true
	damage_timer = damage_duration
	invincibility_timer = invincibility_duration
	knockback_timer = knockback_duration
	knockback_direction = direction
	knockback_force_value = force

	player.velocity.x = direction.x * force * 1.2
	player.velocity.y = -knockback_vertical_force

	print("Expansionダメージアニメーション開始: ", animation_type)
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

	if damage_timer <= 0.0:
		finish_damaged()

func apply_continuous_knockback() -> void:
	player.velocity.x = knockback_direction.x * knockback_force_value * 1.2

func finish_damaged() -> void:
	is_damaged = false
	damage_timer = 0.0
	knockback_timer = 0.0
	print("Expansionダメージアニメーション終了")
	damaged_finished.emit()

func cancel_damaged() -> void:
	if is_damaged:
		finish_damaged()

func is_in_invincible_state() -> bool:
	return is_invincible
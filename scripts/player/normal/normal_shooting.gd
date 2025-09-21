class_name NormalShooting
extends RefCounted

const KUNAI_SCENE = preload("res://scenes/bullets/kunai.tscn")

@export var shooting_kunai_speed: float = 500.0
@export var shooting_cooldown: float = 0.3
@export var shooting_animation_duration: float = 0.5
@export var shooting_offset_x: float = 40.0
@export var jump_force: float = 380.0

var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var shooting_cooldown_timer: float = 0.0
var can_back_jump: bool = false
var shooting_timer: float = 0.0
var shooting_grounded: bool = false

signal shooting_finished

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

func handle_shooting() -> void:
	shooting_cooldown_timer = shooting_cooldown
	shooting_timer = shooting_animation_duration
	shooting_grounded = player.is_on_floor()

	spawn_kunai()

	if player.is_on_floor():
		animated_sprite.play(get_grounded_animation_name())
		can_back_jump = true
	else:
		animated_sprite.play(get_airborne_animation_name())
		can_back_jump = false

	if not animated_sprite.animation_finished.is_connected(_on_shooting_animation_finished):
		animated_sprite.animation_finished.connect(_on_shooting_animation_finished)

func handle_back_jump_shooting() -> void:
	if not can_back_jump:
		return

	can_back_jump = false

	var current_direction: float = 1.0 if animated_sprite.flip_h else -1.0
	var back_direction: float = -current_direction

	var back_velocity: float = back_direction * player.get_current_movement().get_move_walk_speed()

	player.velocity.y = -jump_force
	player.velocity.x = back_velocity

	# jump_horizontal_velocityも設定して、handle_movement()での上書きを防ぐ
	player.get_current_movement().set_jump_horizontal_velocity(back_velocity)

	shooting_cooldown_timer = shooting_cooldown
	shooting_timer = shooting_animation_duration

	spawn_kunai()
	animated_sprite.play(get_airborne_animation_name())

	shooting_grounded = false

func spawn_kunai() -> void:
	var shooting_direction: float
	if player.direction_x != 0.0:
		shooting_direction = player.direction_x
	else:
		shooting_direction = 1.0 if animated_sprite.flip_h else -1.0

	var kunai_instance: Area2D = KUNAI_SCENE.instantiate()
	player.get_tree().current_scene.add_child(kunai_instance)

	var spawn_offset: Vector2 = Vector2(shooting_direction * shooting_offset_x, 0.0)
	kunai_instance.global_position = animated_sprite.global_position + spawn_offset

	if kunai_instance.has_method("initialize"):
		kunai_instance.initialize(shooting_direction, shooting_kunai_speed, player)

func update_shooting_cooldown(delta: float) -> void:
	shooting_cooldown_timer = max(0.0, shooting_cooldown_timer - delta)

func update_shooting_timer(delta: float) -> bool:
	if shooting_timer > 0.0:
		shooting_timer -= delta
		if shooting_timer <= 0.0:
			end_shooting()
			return false
	return true

func can_shoot() -> bool:
	return shooting_cooldown_timer <= 0.0

func get_grounded_animation_name() -> String:
	return "normal_shooting_01_001"

func get_airborne_animation_name() -> String:
	return "normal_shooting_01_002"

func end_shooting() -> void:
	if animated_sprite.animation_finished.is_connected(_on_shooting_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_shooting_animation_finished)

	can_back_jump = false
	shooting_timer = 0.0
	shooting_grounded = false
	shooting_finished.emit()

func _on_shooting_animation_finished() -> void:
	end_shooting()
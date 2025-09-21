class_name NormalFighting
extends RefCounted

@export var move_fighting_initial_speed: float = 250.0
@export var move_fighting_run_bonus: float = 100.0
@export var move_fighting_duration: float = 0.5

var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var fighting_direction: float = 0.0
var current_fighting_speed: float = 0.0
var fighting_grounded: bool = false
var fighting_timer: float = 0.0

signal fighting_finished

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

func handle_fighting() -> void:
	if player.direction_x != 0.0:
		fighting_direction = player.direction_x
	else:
		fighting_direction = 1.0 if animated_sprite.flip_h else -1.0

	fighting_grounded = player.is_on_floor()

	if fighting_grounded:
		current_fighting_speed = move_fighting_initial_speed
		if player.is_running:
			current_fighting_speed += move_fighting_run_bonus
	else:
		current_fighting_speed = 0.0

	fighting_timer = move_fighting_duration

	animated_sprite.play(get_animation_name())

	if not animated_sprite.animation_finished.is_connected(_on_fighting_animation_finished):
		animated_sprite.animation_finished.connect(_on_fighting_animation_finished)

func apply_fighting_movement() -> void:
	if fighting_grounded:
		player.velocity.x = fighting_direction * current_fighting_speed

func update_fighting_timer(delta: float) -> bool:
	if fighting_timer > 0.0:
		fighting_timer -= delta
		if fighting_timer <= 0.0:
			end_fighting()
			return false
	return true

func end_fighting() -> void:
	if animated_sprite.animation_finished.is_connected(_on_fighting_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_fighting_animation_finished)

	fighting_direction = 0.0
	current_fighting_speed = 0.0
	fighting_grounded = false
	fighting_timer = 0.0
	fighting_finished.emit()

func get_animation_name() -> String:
	return "normal_attack_01"

func _on_fighting_animation_finished() -> void:
	end_fighting()
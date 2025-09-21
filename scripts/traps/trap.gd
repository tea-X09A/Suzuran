class_name Trap
extends Area2D

@export var damage: int = 10
@export var animation_type: String = "damaged"
@export var knockback_force: float = 300.0

var damaged_players: Array[Player] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var player: Player = body as Player
		if not damaged_players.has(player):
			apply_damage_to_player(player)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		var player: Player = body as Player
		if damaged_players.has(player):
			damaged_players.erase(player)

func apply_damage_to_player(player: Player) -> void:
	if player.get_current_damaged().is_in_invincible_state():
		return

	var knockback_direction: Vector2 = Vector2.ZERO

	if player.global_position.x < global_position.x:
		knockback_direction = Vector2.LEFT
	else:
		knockback_direction = Vector2.RIGHT

	damaged_players.append(player)
	player.take_damage(damage, animation_type, knockback_direction, knockback_force)

	await get_tree().create_timer(2.0).timeout
	if damaged_players.has(player):
		damaged_players.erase(player)


class_name Trap01
extends StaticBody2D

# プレイヤーに与えるダメージ量（整数値）
@export var damage: int = 10
# 再生するダメージアニメーションの種類（アニメーション名）
@export var animation_type: String = "damaged"
# プレイヤーをノックバックさせる力の強さ（ピクセル/秒）
@export var knockback_force: float = 300.0

# Area2Dの参照をキャッシュ
@onready var area_2d: Area2D = $Area2D

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	check_overlapping_bodies()

func apply_damage_to_player(player: Player) -> void:
	if player.get_current_damaged().is_in_invincible_state():
		return

	var knockback_direction: Vector2 = Vector2.ZERO

	if player.global_position.x < global_position.x:
		knockback_direction = Vector2.LEFT
	else:
		knockback_direction = Vector2.RIGHT

	player.take_damage(damage, animation_type, knockback_direction, knockback_force)

func check_overlapping_bodies() -> void:
	var overlapping_bodies: Array[Node2D] = area_2d.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body is Player:
			var player: Player = body as Player
			apply_damage_to_player(player)

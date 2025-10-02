class_name BaseEnemy
extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var detection_area: Area2D = $DetectionArea
@onready var vision_shape: Polygon2D = $DetectionArea/VisionShape
@onready var detection_collision: CollisionPolygon2D = $DetectionArea/DetectionCollision
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

@export var move_speed: float = 50.0
@export var patrol_range: float = 100.0
@export var wait_duration: float = 2.0
@export var lose_sight_delay: float = 2.0
@export var capture_cooldown: float = 0.5
@export var vision_ray_count: int = 20
@export var vision_distance: float = 509.0
@export var vision_angle: float = 10.0

var processing_enabled: bool = false
var player: Node2D = null
var GRAVITY: float
var patrol_center: Vector2
var target_position: Vector2
var current_state: String = "waiting"
var wait_timer: float = 0.0
var arrival_threshold: float = 5.0
var hit_wall: bool = false
var last_movement_direction: float = 0.0
var distance_since_collision: float = 0.0
var min_distance_from_wall: float = 20.0
var player_out_of_range: bool = false
var time_out_of_range: float = 0.0
var last_capture_time: float = 0.0
var raycasts: Array[RayCast2D] = []

func _ready() -> void:
	add_to_group("enemies")
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	patrol_center = global_position

	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)

	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	_disable_collision_areas()
	_setup_vision_raycasts()

func _generate_random_patrol_target() -> void:
	var random_offset: float = randf_range(-patrol_range, patrol_range)
	target_position = Vector2(patrol_center.x + random_offset, patrol_center.y)

func _generate_reverse_patrol_target() -> void:
	var reverse_direction: float = -last_movement_direction
	var move_distance: float = randf_range(patrol_range * 0.5, patrol_range)
	var target_x: float = global_position.x + (reverse_direction * move_distance)
	target_position = Vector2(target_x, patrol_center.y)

func _patrol_movement() -> void:
	var direction: float = sign(target_position.x - global_position.x)

	if abs(target_position.x - global_position.x) <= arrival_threshold:
		current_state = "waiting"
		wait_timer = 0.0
		velocity.x = 0.0
	else:
		velocity.x = direction * move_speed
		last_movement_direction = direction

func _physics_process(delta: float) -> void:
	if not processing_enabled:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if player_out_of_range and current_state == "chasing":
		time_out_of_range += delta
		if time_out_of_range >= lose_sight_delay:
			_lose_player()

	match current_state:
		"chasing":
			if player:
				_chase_player()
			if is_on_wall():
				hit_wall = true
				last_movement_direction = sign(velocity.x) if velocity.x != 0 else last_movement_direction

		"waiting":
			velocity.x = 0.0
			wait_timer += delta
			if wait_timer >= wait_duration:
				current_state = "patrol"
				if hit_wall:
					_generate_reverse_patrol_target()
					distance_since_collision = 0.0
				else:
					_generate_random_patrol_target()

		"patrol":
			_patrol_movement()
			if not (hit_wall and distance_since_collision < min_distance_from_wall) and is_on_wall():
				_reset_to_waiting()
				hit_wall = true
				distance_since_collision = 0.0

	var previous_position: Vector2 = global_position
	move_and_slide()

	if hit_wall and current_state == "patrol":
		distance_since_collision += global_position.distance_to(previous_position)
		if distance_since_collision >= min_distance_from_wall:
			hit_wall = false

	_update_facing_direction()
	_update_vision()
	check_player_collision()

func _setup_vision_raycasts() -> void:
	if not detection_area:
		return

	for raycast in raycasts:
		raycast.queue_free()
	raycasts.clear()

	for i in range(vision_ray_count):
		var raycast: RayCast2D = RayCast2D.new()
		var angle_step: float = (vision_angle * 2.0) / float(vision_ray_count - 1) if vision_ray_count > 1 else 0.0
		var angle_deg: float = -vision_angle + (angle_step * float(i))
		var angle_rad: float = deg_to_rad(angle_deg)

		raycast.target_position = Vector2(cos(angle_rad) * vision_distance, sin(angle_rad) * vision_distance)
		raycast.collision_mask = 1
		raycast.enabled = true
		raycast.visible = false

		detection_area.add_child(raycast)
		raycasts.append(raycast)

func _update_vision() -> void:
	if not vision_shape or not detection_collision or raycasts.is_empty():
		return

	var new_polygon: PackedVector2Array = PackedVector2Array([Vector2.ZERO])

	for raycast in raycasts:
		raycast.force_raycast_update()
		if raycast.is_colliding():
			new_polygon.append(detection_area.to_local(raycast.get_collision_point()))
		else:
			new_polygon.append(raycast.target_position)

	vision_shape.polygon = new_polygon
	detection_collision.polygon = new_polygon
	vision_shape.color = Color(0.858824, 0.305882, 0.501961, 0.419608) if current_state == "chasing" else Color(0.309804, 0.65098, 0.835294, 0.2)

func _update_facing_direction() -> void:
	if velocity.x == 0:
		return

	var direction: float = sign(velocity.x)
	if sprite:
		sprite.scale.x = 3.0 * direction
	for node in [detection_area, hitbox, hurtbox]:
		if node:
			node.scale.x = direction

func _chase_player() -> void:
	pass

func _reset_to_waiting() -> void:
	current_state = "waiting"
	wait_timer = 0.0
	velocity.x = 0.0

func _reset_state_flags() -> void:
	hit_wall = false
	distance_since_collision = 0.0
	player_out_of_range = false
	time_out_of_range = 0.0

func _lose_player() -> void:
	var lost_player: Node2D = player
	player = null
	velocity.x = 0.0
	patrol_center = global_position
	_reset_to_waiting()
	if not is_on_wall():
		_reset_state_flags()
	else:
		player_out_of_range = false
		time_out_of_range = 0.0
	_on_player_lost(lost_player)

func check_player_collision() -> void:
	if not hitbox:
		return

	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_capture_time < capture_cooldown:
		return

	for area in hitbox.get_overlapping_areas():
		var parent_node: Node = area.get_parent()
		if parent_node and parent_node.is_in_group("player"):
			if apply_capture_to_player(parent_node):
				last_capture_time = current_time
			break

func apply_capture_to_player(body: Node2D) -> bool:
	if body.has_method("is_invincible") and body.is_invincible():
		return false

	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	var player_state_name: String = ""
	if body.has_method("get_animation_tree"):
		var anim_tree: AnimationTree = body.get_animation_tree()
		if anim_tree:
			var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
			if state_machine:
				player_state_name = state_machine.get_current_node()

	var capture_animation: String = get_capture_animation_down() if player_state_name in ["DOWN", "KNOCKBACK"] else get_capture_animation_normal()
	body.capture_animation_name = capture_animation

	if body.has_method("update_animation_state"):
		body.update_animation_state("CAPTURE")

	print("敵がプレイヤーをキャプチャ: アニメーション=", capture_animation)
	return true

func get_capture_animation_normal() -> String:
	push_error("get_capture_animation_normal() must be overridden in derived class")
	return ""

func get_capture_animation_down() -> String:
	push_error("get_capture_animation_down() must be overridden in derived class")
	return ""

func _set_collision_areas(enabled: bool) -> void:
	for area in [hitbox, hurtbox]:
		if area:
			area.monitoring = enabled
			area.monitorable = enabled
	if detection_area:
		detection_area.monitoring = enabled

func _enable_collision_areas() -> void:
	_set_collision_areas(true)

func _disable_collision_areas() -> void:
	_set_collision_areas(false)

func _on_screen_entered() -> void:
	processing_enabled = true
	_enable_collision_areas()

func _on_screen_exited() -> void:
	processing_enabled = false
	_disable_collision_areas()
	velocity = Vector2.ZERO
	player = null
	_reset_to_waiting()
	_reset_state_flags()
	_update_vision()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		current_state = "chasing"
		player_out_of_range = false
		time_out_of_range = 0.0
		_on_player_detected(body)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_out_of_range = true
		time_out_of_range = 0.0

func _on_player_detected(_body: Node2D) -> void:
	pass

func _on_player_lost(_body: Node2D) -> void:
	pass

func enter_capture_state() -> void:
	velocity = Vector2.ZERO
	_reset_to_waiting()
	processing_enabled = false
	visible = false

func exit_capture_state() -> void:
	visible = true
	processing_enabled = true
	_reset_to_waiting()
	patrol_center = global_position

class_name ShootingState
extends BaseState

# ======================== 射撃パラメータ定義 ========================
const KUNAI_SCENE = preload("res://scenes/bullets/kunai.tscn")

# 射撃状態管理
var can_back_jump: bool = false
var shooting_timer: float = 0.0
var shooting_grounded: bool = false

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 射撃処理を実行
	handle_shooting()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animation_player and animation_player.animation_finished.is_connected(_on_shooting_animation_finished):
		animation_player.animation_finished.disconnect(_on_shooting_animation_finished)

	# 状態のリセット
	can_back_jump = false
	shooting_timer = 0.0
	shooting_grounded = false

# ======================== 射撃処理 ========================

func handle_shooting() -> void:
	player.set_shooting_cooldown(get_parameter("shooting_cooldown"))
	shooting_timer = get_parameter("shooting_animation_duration")
	shooting_grounded = player.is_on_floor()

	spawn_kunai()

	can_back_jump = shooting_grounded

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_shooting_animation_finished):
		animation_player.animation_finished.connect(_on_shooting_animation_finished)

func handle_back_jump_shooting() -> void:
	if not can_back_jump:
		return

	can_back_jump = false

	# バックジャンプ射撃は地上でのみ実行可能（空中での軌道干渉を防止）
	if not player.is_on_floor():
		return

	var current_direction: float = 1.0 if sprite_2d.flip_h else -1.0
	var back_direction: float = -current_direction

	var back_velocity: float = back_direction * get_parameter("move_walk_speed")

	# 物理演算への影響は地上でのみ適用（空中軌道保護）
	player.velocity.y = -get_parameter("jump_force")
	player.velocity.x = back_velocity

	# バックジャンプの水平速度を保護（着地時に自動的にfalseになる）
	player.ignore_jump_horizontal_velocity = true

	player.set_shooting_cooldown(get_parameter("shooting_cooldown"))
	shooting_timer = get_parameter("shooting_animation_duration")

	spawn_kunai()
	# AnimationTreeが自動で適切なアニメーションを処理

	shooting_grounded = false

func spawn_kunai() -> void:
	var shooting_direction: float
	if player.direction_x != 0.0:
		shooting_direction = player.direction_x
	else:
		shooting_direction = 1.0 if sprite_2d.flip_h else -1.0

	var kunai_instance: Area2D = KUNAI_SCENE.instantiate()
	player.get_tree().current_scene.add_child(kunai_instance)

	var spawn_offset: Vector2 = Vector2(shooting_direction * get_parameter("shooting_offset_x"), 0.0)
	kunai_instance.global_position = sprite_2d.global_position + spawn_offset

	if kunai_instance.has_method("initialize"):
		kunai_instance.initialize(shooting_direction, get_parameter("shooting_kunai_speed"), player)

# ======================== 射撃状態制御（player.gdから呼び出し） ========================
## 射撃状態更新（player.gdから呼び出し）
func update_shooting_state(delta: float) -> bool:
	if shooting_timer > 0.0:
		shooting_timer -= delta
		if shooting_timer <= 0.0:
			return false
	return true

## バックジャンプ射撃処理（player.gdから呼び出し）
func try_back_jump_shooting() -> bool:
	if can_back_jump and Input.is_action_just_pressed("back_jump_shooting"):
		handle_back_jump_shooting()
		return true
	return false

## 空中射撃かどうかの判定
func is_airborne_attack() -> bool:
	return not shooting_grounded

## 空中でのアクション実行中かどうかの判定（物理分離用）
func is_airborne_action_active() -> bool:
	return is_airborne_attack() and shooting_timer > 0.0

## アニメーション完了時のコールバック
func _on_shooting_animation_finished() -> void:
	# 射撃終了をトリガー
	shooting_timer = 0.0

class_name ShootingState
extends BaseState

# ======================== 射撃パラメータ定義 ========================
const KUNAI_SCENE = preload("res://scenes/bullets/kunai.tscn")

# 射撃状態管理
var shooting_timer: float = 0.0
var is_shooting_02: bool = false  # shooting_02アニメーションを使用中かのフラグ

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	handle_shooting()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animation_player and animation_player.animation_finished.is_connected(_on_shooting_animation_finished):
		animation_player.animation_finished.disconnect(_on_shooting_animation_finished)

	# 状態のリセット
	shooting_timer = 0.0
	is_shooting_02 = false

## 入力処理
func handle_input(_delta: float) -> void:
	# shooting_02のアニメーション中は、入力でキャンセル不可
	if is_shooting_02:
		return

	# 地上のみジャンプとしゃがみを受け付ける（shooting_01の場合）
	if can_jump():
		perform_jump()
		return

	if can_transition_to_squat():
		player.update_animation_state("SQUAT")
		return

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地上shooting_01の場合は慣性を止める（その場で足を止めて攻撃）
	if player.is_on_floor() and not is_shooting_02:
		player.velocity.x = 0.0

	# 重力適用
	if not player.is_on_floor():
		apply_gravity(delta)

	# shooting_02中に着地した場合、キャンセルして遷移
	if is_shooting_02 and player.is_on_floor():
		shooting_timer = 0.0
		is_shooting_02 = false
		_transition_on_landing()
		return

	# shooting_02の場合は、着地するまでアニメーションを維持（タイマー無視）
	if is_shooting_02:
		return

	# 通常の射撃終了処理（shooting_01のみ）
	if not update_shooting_state(delta):
		handle_action_end_transition()

## 着地時の状態遷移処理
func _transition_on_landing() -> void:
	if is_squat_input():
		player.squat_was_cancelled = false
		player.update_animation_state("SQUAT")
		return

	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		if is_dash_input():
			player.update_animation_state("RUN")
		else:
			player.update_animation_state("WALK")
	else:
		player.update_animation_state("IDLE")


# ======================== 射撃処理 ========================

## 射撃初期化処理
func handle_shooting() -> void:
	# 弾数チェック（弾がない場合は射撃をキャンセル）
	if not player.has_ammo():
		handle_action_end_transition()
		return

	shooting_timer = get_parameter("shooting_animation_duration")

	# 空中の場合はshooting_02を使用
	if not player.is_on_floor():
		is_shooting_02 = true
		_set_shooting_animation("normal_shooting_02")
	else:
		is_shooting_02 = false
		_set_shooting_animation("normal_shooting_01")

	spawn_kunai()

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_shooting_animation_finished):
		animation_player.animation_finished.connect(_on_shooting_animation_finished)

## 苦無生成処理
func spawn_kunai() -> void:
	# 弾数を消費
	if not player.consume_ammo():
		return

	# 現在の移動入力を取得
	var current_input: float = get_movement_input()

	var shooting_direction: float
	# 移動入力がある場合はその方向に発射
	if current_input != 0.0:
		shooting_direction = current_input
	# 移動入力がない場合はSprite2Dの向きに発射
	else:
		shooting_direction = 1.0 if sprite_2d.flip_h else -1.0

	var kunai_instance: Area2D = KUNAI_SCENE.instantiate()
	player.get_tree().current_scene.add_child(kunai_instance)

	var spawn_offset: Vector2 = Vector2(shooting_direction * get_parameter("shooting_offset_x"), 0.0)
	kunai_instance.global_position = sprite_2d.global_position + spawn_offset

	if kunai_instance.has_method("initialize"):
		var damage_value: int = get_parameter("shooting_damage")
		kunai_instance.initialize(shooting_direction, get_parameter("shooting_kunai_speed"), player, damage_value)

# ======================== 射撃状態制御 ========================

## 射撃タイマー更新
func update_shooting_state(delta: float) -> bool:
	if shooting_timer > 0.0:
		shooting_timer -= delta
		if shooting_timer <= 0.0:
			return false
	return true

## アニメーション完了コールバック
func _on_shooting_animation_finished() -> void:
	shooting_timer = 0.0

## SHOOTINGノードのアニメーションを変更する
func _set_shooting_animation(animation_name: String) -> void:
	if animation_tree and animation_tree.tree_root:
		var state_machine_node: AnimationNodeStateMachine = animation_tree.tree_root as AnimationNodeStateMachine
		if state_machine_node:
			var shooting_node: AnimationNodeAnimation = state_machine_node.get_node("SHOOTING") as AnimationNodeAnimation
			if shooting_node:
				shooting_node.animation = animation_name
				# アニメーション変更後、再度SHOOTINGステートに遷移して新しいアニメーションを適用
				if state_machine:
					state_machine.start("SHOOTING")

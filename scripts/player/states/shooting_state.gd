class_name ShootingState
extends BaseState

# ======================== 射撃パラメータ定義 ========================

const KUNAI_SCENE = preload("res://scenes/bullets/kunai.tscn")

# 射撃状態管理
var can_back_jump: bool = false
var shooting_timer: float = 0.0
var shooting_grounded: bool = false

# ======================== パラメータ取得 ========================

# 射撃状態では全パラメータ（移動+射撃）を統合システムから取得
func get_parameters() -> Dictionary:
	return PlayerParameters.get_all_parameters(condition)

# ======================== State Machine処理 ========================

func enter() -> void:
	player.state = Player.PLAYER_STATE.SHOOTING
	# 射撃状態は State Machine で管理（is_shooting() メソッドで判定）
	# 射撃用hurtboxに切り替え
	player.switch_hurtbox(player.shooting_hurtbox)
	# 射撃処理を直接実行
	handle_shooting()

func process_physics(delta: float) -> void:
	# 射撃タイマーの更新
	update_shooting_timer(delta)

	# 射撃が終了したかチェック
	if shooting_timer <= 0.0:
		# 射撃終了後は適切な状態に遷移
		transition_to_appropriate_state()
		return

	# 射撃中のバックジャンプ射撃対応
	if Input.is_action_just_pressed("back_jump_shooting"):
		handle_back_jump_shooting()
		return

	# 射撃中でも戦闘アクションへの遷移は可能
	if check_for_fighting_input():
		player.change_state("fighting")
		return

func exit() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	disconnect_animation_signal(_on_shooting_animation_finished)

	# 射撃状態は State Machine で管理（状態遷移で自動解除）
	# 射撃開始前の走行状態を復元
	player.is_running = player.running_state_when_action_started
	# アニメーション状態をリセット
	player.player_state.reset_animation_state()

	# 状態のリセット
	can_back_jump = false
	shooting_timer = 0.0
	shooting_grounded = false

func handle_input(event: InputEvent) -> void:
	# 射撃中の入力処理
	pass

# ======================== 射撃処理 ========================

func handle_shooting() -> void:
	player.set_shooting_cooldown(get_parameter("shooting_cooldown"))
	shooting_timer = get_parameter("shooting_animation_duration")
	shooting_grounded = player.is_on_floor()

	spawn_kunai()

	if player.is_on_floor():
		animated_sprite.play(get_grounded_animation_name())
		can_back_jump = true
	else:
		animated_sprite.play(get_airborne_animation_name())
		can_back_jump = false

	# アニメーション完了シグナルの接続（重複接続を防止）
	connect_animation_signal(_on_shooting_animation_finished)

func handle_back_jump_shooting() -> void:
	if not can_back_jump:
		return

	can_back_jump = false

	# バックジャンプ射撃は地上でのみ実行可能（空中での軌道干渉を防止）
	if not player.is_on_floor():
		return

	var current_direction: float = 1.0 if animated_sprite.flip_h else -1.0
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

	var spawn_offset: Vector2 = Vector2(shooting_direction * get_parameter("shooting_offset_x"), 0.0)
	kunai_instance.global_position = animated_sprite.global_position + spawn_offset

	if kunai_instance.has_method("initialize"):
		kunai_instance.initialize(shooting_direction, get_parameter("shooting_kunai_speed"), player)

# ======================== 状態管理 ========================

## 射撃タイマーの更新
func update_shooting_timer(delta: float) -> bool:
	if shooting_timer > 0.0:
		shooting_timer -= delta
		if shooting_timer <= 0.0:
			return false
	return true

## 射撃可能かどうかの判定
func can_shoot() -> bool:
	return player.can_shoot()

## 空中射撃かどうかの判定
func is_airborne_attack() -> bool:
	return not shooting_grounded

## 空中でのアクション実行中かどうかの判定（物理分離用）
func is_airborne_action_active() -> bool:
	return is_airborne_attack() and shooting_timer > 0.0

func get_grounded_animation_name() -> String:
	var prefix: String = get_parameter("animation_prefix")
	return prefix + "_shooting_01_001"

func get_airborne_animation_name() -> String:
	var prefix: String = get_parameter("animation_prefix")
	return prefix + "_shooting_01_002"

func _on_shooting_animation_finished() -> void:
	# 射撃終了をトリガー
	shooting_timer = 0.0
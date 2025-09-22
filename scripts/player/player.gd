class_name Player
extends CharacterBody2D

# プレイヤーの状態定義
enum PLAYER_CONDITION { NORMAL, EXPANSION }
enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING, SHOOTING, DAMAGED }

# ノード参照（_ready()でキャッシュ）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: PlayerHurtbox = $Hurtbox

# エクスポート変数
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
@export var jump_buffer_time: float = 0.1
@export var jump_coyote_time: float = 0.1

# プレイヤーの基本状態
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
var state: PLAYER_STATE = PLAYER_STATE.IDLE

# モジュール参照
var player_movement: PlayerMovement
var player_fighting: PlayerFighting
var player_shooting: PlayerShooting
var player_jump: PlayerJump
var player_damaged: PlayerDamaged

# 入力・移動状態
var direction_x: float = 0.0
var is_running: bool = false
var is_squatting: bool = false
var was_grounded: bool = false
var is_grounded: bool = false

# アクション状態
var is_fighting: bool = false
var is_shooting: bool = false
var is_damaged: bool = false

# ジャンプ制御
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var is_jumping_by_input: bool = false
var ignore_jump_horizontal_velocity: bool = false

# 視覚効果
var blink_timer: float = 0.0

# デバッグ用（前フレームとの比較）
var previous_direction_x: float = 0.0
var previous_is_running: bool = false
var previous_is_squatting: bool = false

func _ready() -> void:
	# 初期設定
	condition = initial_condition
	animated_sprite_2d.flip_h = true

	# モジュールの初期化
	_initialize_modules()

	# シグナル接続
	_connect_signals()

func _initialize_modules() -> void:
	player_movement = PlayerMovement.new(self, condition)
	player_jump = PlayerJump.new(self, player_movement, condition)
	player_fighting = PlayerFighting.new(self, condition)
	player_shooting = PlayerShooting.new(self, condition)
	player_damaged = PlayerDamaged.new(self, condition)

func _connect_signals() -> void:
	player_fighting.fighting_finished.connect(_on_fighting_finished)
	player_shooting.shooting_finished.connect(_on_shooting_finished)
	player_damaged.damaged_finished.connect(_on_damaged_finished)

	# Hurtboxのシグナル接続
	hurtbox.enemy_attack_detected.connect(_on_enemy_attack_detected)
	hurtbox.trap_detected.connect(_on_trap_detected)
	hurtbox.item_detected.connect(_on_item_detected)
	hurtbox.projectile_detected.connect(_on_projectile_detected)

func _process(delta: float) -> void:
	_update_visual_effects(delta)

func _update_visual_effects(delta: float) -> void:
	blink_timer += delta

	if player_damaged.is_in_invincible_state():
		# 無敵状態時の点滅効果（sinカーブ、周期0.2秒）
		var blink_alpha: float = (sin(blink_timer * PI * 10.0) + 1.0) / 2.0
		animated_sprite_2d.modulate.a = 0.3 + (blink_alpha * 0.7)
	else:
		animated_sprite_2d.modulate.a = 1.0

func _physics_process(delta: float) -> void:
	# 基本状態更新
	_update_ground_state()
	update_timers(delta)

	# 物理処理
	_apply_physics(delta)

	# 入力処理
	_handle_input_based_on_state()

	# アクション更新
	update_fighting_shooting_damaged(delta)

	# 移動と状態更新
	move_and_slide()
	update_state()

func _update_ground_state() -> void:
	was_grounded = is_grounded
	is_grounded = is_on_floor()

func _apply_physics(delta: float) -> void:
	get_current_movement().apply_gravity(delta)
	get_current_movement().apply_variable_jump(delta)

func _handle_input_based_on_state() -> void:
	if not is_damaged:
		handle_input()
		handle_movement()
	else:
		handle_damaged_input()
		if player_damaged.is_in_knockback_landing_state():
			handle_movement()

# =====================================================
# モジュールアクセサーメソッド
# =====================================================

func get_current_movement() -> PlayerMovement:
	return player_movement

func get_current_fighting() -> PlayerFighting:
	return player_fighting

func get_current_shooting() -> PlayerShooting:
	return player_shooting

func get_current_jump() -> PlayerJump:
	return player_jump

func get_current_damaged() -> PlayerDamaged:
	return player_damaged

func get_hurtbox() -> PlayerHurtbox:
	return hurtbox

# =====================================================
# タイマー管理
# =====================================================

func update_timers(delta: float) -> void:
	_handle_landing_events()
	_update_jump_timers(delta)

func _handle_landing_events() -> void:
	if not was_grounded and is_grounded:
		# 着地時のリセット処理
		is_jumping_by_input = false
		ignore_jump_horizontal_velocity = false

		# ダメージ状態の処理
		if is_damaged and player_damaged.is_in_knockback_state():
			player_damaged.start_down_state()

		# 空中アクションのキャンセル
		if is_fighting and get_current_fighting().is_airborne_attack():
			get_current_fighting().cancel_fighting()
		if is_shooting and get_current_shooting().is_airborne_attack():
			get_current_shooting().cancel_shooting()

func _update_jump_timers(delta: float) -> void:
	if is_grounded:
		coyote_timer = jump_coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

# =====================================================
# 入力処理
# =====================================================

func handle_input() -> void:
	_handle_action_inputs()
	_handle_movement_inputs()
	_handle_jump_inputs()

func _handle_action_inputs() -> void:
	is_squatting = is_grounded and Input.is_action_pressed("squat") and _can_perform_action()

	if Input.is_action_just_pressed("fight") and _can_perform_action():
		handle_fighting()

	if Input.is_action_just_pressed("shooting"):
		if _can_perform_action():
			handle_shooting()
		elif is_shooting and not is_damaged:
			handle_back_jump_shooting()

func _handle_movement_inputs() -> void:
	var left_key: bool = Input.is_action_pressed("left")
	var right_key: bool = Input.is_action_pressed("right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if _can_move():
		_set_movement_direction(left_key, right_key, shift_pressed)
	else:
		direction_x = 0.0
		if is_grounded:
			is_running = false

func _handle_jump_inputs() -> void:
	if Input.is_action_just_pressed("jump") and _can_jump():
		jump_buffer_timer = jump_buffer_time

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		handle_jump()

func _can_perform_action() -> bool:
	return not is_fighting and not is_shooting and not is_damaged

func _can_move() -> bool:
	return not is_squatting and _can_perform_action()

func _can_jump() -> bool:
	return not is_squatting and _can_perform_action()

func _set_movement_direction(left_key: bool, right_key: bool, shift_pressed: bool) -> void:
	if is_grounded:
		if left_key:
			direction_x = -1.0
			is_running = shift_pressed
		elif right_key:
			direction_x = 1.0
			is_running = shift_pressed
		else:
			direction_x = 0.0
			is_running = false
	else:
		if left_key:
			direction_x = -1.0
		elif right_key:
			direction_x = 1.0
		else:
			direction_x = 0.0
		is_running = shift_pressed and (left_key or right_key)

func handle_damaged_input() -> void:
	# ダメージ中は移動を制限
	direction_x = 0.0
	is_running = false

	# 特定状態でのジャンプ入力処理
	var can_jump: bool = player_damaged.is_in_knockback_state() or player_damaged.is_in_knockback_landing_state()
	if can_jump and Input.is_action_just_pressed("jump"):
		player_damaged.handle_recovery_jump()
		handle_jump()

# =====================================================
# 移動処理
# =====================================================

func handle_movement() -> void:
	_log_movement_changes()
	get_current_movement().handle_movement(direction_x, is_running, is_squatting)

func _log_movement_changes() -> void:
	if _has_movement_changed():
		var direction_text: String = _get_direction_text()
		var movement_type: String = _get_movement_type_text()
		var condition_text: String = "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal"

		print("プレイヤー移動アクション実行: ", direction_text, " (", movement_type, ") - ", condition_text)

		_update_previous_movement_state()

func _has_movement_changed() -> bool:
	return (direction_x != previous_direction_x or
			is_running != previous_is_running or
			is_squatting != previous_is_squatting)

func _get_direction_text() -> String:
	if direction_x > 0:
		return "右"
	elif direction_x < 0:
		return "左"
	else:
		return "停止"

func _get_movement_type_text() -> String:
	if is_squatting:
		return "しゃがみ"
	elif is_running:
		return "走り"
	else:
		return "歩き"

func _update_previous_movement_state() -> void:
	previous_direction_x = direction_x
	previous_is_running = is_running
	previous_is_squatting = is_squatting

# =====================================================
# アクション処理
# =====================================================

func handle_fighting() -> void:
	_log_action("戦闘")
	is_fighting = true
	state = PLAYER_STATE.FIGHTING
	get_current_fighting().handle_fighting()

func handle_shooting() -> void:
	if get_current_shooting().can_shoot():
		_log_action("射撃")
		is_shooting = true
		state = PLAYER_STATE.SHOOTING
		get_current_shooting().handle_shooting()

func handle_back_jump_shooting() -> void:
	_log_action("後方ジャンプ射撃")
	get_current_shooting().handle_back_jump_shooting()

func handle_jump() -> void:
	_log_action("ジャンプ")
	get_current_jump().handle_jump()
	_reset_jump_timers()

func _log_action(action_name: String) -> void:
	var condition_text: String = "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal"
	print("プレイヤー", action_name, "アクション実行: ", condition_text)

func _reset_jump_timers() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	is_jumping_by_input = true

# =====================================================
# アクション状態更新
# =====================================================

func update_fighting_shooting_damaged(delta: float) -> void:
	_update_fighting_state(delta)
	_update_shooting_state(delta)
	_update_damaged_state(delta)

func _update_fighting_state(delta: float) -> void:
	if is_fighting:
		if get_current_fighting().update_fighting_timer(delta):
			get_current_fighting().apply_fighting_movement()

func _update_shooting_state(delta: float) -> void:
	if is_shooting:
		get_current_shooting().update_shooting_timer(delta)
	get_current_shooting().update_shooting_cooldown(delta)

func _update_damaged_state(delta: float) -> void:
	if is_damaged:
		player_damaged.update_damaged_timer(delta)
	elif player_damaged.is_in_invincible_state():
		player_damaged.update_invincibility_timer(delta)

# =====================================================
# シグナルハンドラー
# =====================================================

func _on_fighting_finished() -> void:
	is_fighting = false

func _on_shooting_finished() -> void:
	is_shooting = false

func _on_damaged_finished() -> void:
	is_damaged = false

# =====================================================
# Hurtboxシグナルハンドラー
# =====================================================

func _on_enemy_attack_detected(attacker: Node2D, damage: int, knockback_direction: Vector2, knockback_force: float) -> void:
	# 敵の攻撃がプレイヤーに当たった時の処理
	# 指定されたダメージとノックバック効果でダメージ処理を実行
	take_damage(damage, "damaged", knockback_direction, knockback_force)

func _on_trap_detected(trap: Node2D, damage: int, effect_type: String) -> void:
	# トラップがプレイヤーに作動した時の処理
	# プレイヤーからトラップの方向とは逆方向にノックバック
	var knockback_direction: Vector2 = (global_position - trap.global_position).normalized()
	take_damage(damage, "damaged", knockback_direction, 100.0)

func _on_item_detected(item: Node2D, item_type: String, value: int) -> void:
	# アイテムがプレイヤーに触れた時の処理
	# アイテムタイプに応じたピックアップ処理を実行
	_handle_item_pickup(item, item_type, value)

func _on_projectile_detected(projectile: Node2D, damage: int, knockback_direction: Vector2) -> void:
	# 発射物（弾丸など）がプレイヤーに当たった時の処理
	# 80.0の固定ノックバック力でダメージ処理を実行
	take_damage(damage, "damaged", knockback_direction, 80.0)

func _handle_item_pickup(item: Node2D, item_type: String, value: int) -> void:
	# 体力回復アイテムの処理
	if item_type == "health":
		_restore_health(value)
	else:
		print("未知のアイテムタイプ:", item_type)

	# アイテムを削除
	if item and is_instance_valid(item):
		item.queue_free()

func _restore_health(amount: int) -> void:
	print("体力回復:", amount)
	# 体力システムが実装されたら、ここで体力を回復する処理を追加

# =====================================================
# 状態管理
# =====================================================

func update_state() -> void:
	if _is_in_action_state():
		return

	var new_state: PLAYER_STATE = _determine_new_state()
	set_state(new_state)

func _is_in_action_state() -> bool:
	return is_fighting or is_shooting or is_damaged

func _determine_new_state() -> PLAYER_STATE:
	var current_grounded: bool = is_on_floor()

	if current_grounded:
		return _get_grounded_state()
	else:
		return _get_airborne_state()

func _get_grounded_state() -> PLAYER_STATE:
	if is_squatting:
		return PLAYER_STATE.SQUAT
	elif velocity.x == 0.0:
		return PLAYER_STATE.IDLE
	else:
		return PLAYER_STATE.RUN if is_running else PLAYER_STATE.WALK

func _get_airborne_state() -> PLAYER_STATE:
	if is_jumping_by_input and velocity.y < 0.0:
		return PLAYER_STATE.JUMP
	else:
		return PLAYER_STATE.FALL

func set_state(new_state: PLAYER_STATE) -> void:
	if new_state == state:
		return

	_log_state_change(new_state)
	state = new_state
	update_animation()

func _log_state_change(new_state: PLAYER_STATE) -> void:
	var state_names: Dictionary = {
		PLAYER_STATE.IDLE: "待機",
		PLAYER_STATE.WALK: "歩き",
		PLAYER_STATE.RUN: "走り",
		PLAYER_STATE.JUMP: "ジャンプ",
		PLAYER_STATE.FALL: "落下",
		PLAYER_STATE.SQUAT: "しゃがみ",
		PLAYER_STATE.FIGHTING: "戦闘",
		PLAYER_STATE.SHOOTING: "射撃",
		PLAYER_STATE.DAMAGED: "ダメージ"
	}

	var old_state_name: String = state_names.get(state, "不明")
	var new_state_name: String = state_names.get(new_state, "不明")
	print("プレイヤー状態変更: ", old_state_name, " → ", new_state_name)

# =====================================================
# アニメーション管理
# =====================================================

func update_animation() -> void:
	var animation_name: String = _get_animation_name()
	if animation_name != "":
		animated_sprite_2d.play(animation_name)

func _get_animation_name() -> String:
	var condition_prefix: String = _get_condition_prefix()

	match state:
		PLAYER_STATE.IDLE:
			return condition_prefix + "_idle"
		PLAYER_STATE.WALK:
			return condition_prefix + "_walk"
		PLAYER_STATE.RUN:
			return condition_prefix + "_run"
		PLAYER_STATE.JUMP:
			return condition_prefix + "_jump"
		PLAYER_STATE.FALL:
			return condition_prefix + "_fall"
		PLAYER_STATE.SQUAT:
			return condition_prefix + "_squat"
		PLAYER_STATE.DAMAGED:
			return condition_prefix + "_damaged"
		PLAYER_STATE.FIGHTING, PLAYER_STATE.SHOOTING:
			return ""
		_:
			return ""

func _get_condition_prefix() -> String:
	return "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal"

# =====================================================
# 条件管理とダメージ処理
# =====================================================

func get_condition() -> PLAYER_CONDITION:
	return condition

func set_condition(new_condition: PLAYER_CONDITION) -> void:
	condition = new_condition
	_update_modules_condition(new_condition)

func _update_modules_condition(new_condition: PLAYER_CONDITION) -> void:
	if player_fighting:
		player_fighting.update_condition(new_condition)
	if player_shooting:
		player_shooting.update_condition(new_condition)

func take_damage(damage: int, animation_type: String, knockback_direction: Vector2, knockback_force: float) -> void:
	if is_damaged:
		return

	_log_damage_received(damage, animation_type, knockback_direction)
	_cancel_current_actions()
	_apply_damage_effects(damage, knockback_direction, knockback_force)

func _log_damage_received(damage: int, animation_type: String, knockback_direction: Vector2) -> void:
	print("プレイヤーダメージ処理: ダメージ", damage, ", アニメーション:", animation_type, ", 方向:", knockback_direction)

func _cancel_current_actions() -> void:
	if is_fighting:
		get_current_fighting().cancel_fighting()
		is_fighting = false

	if is_shooting:
		get_current_shooting().cancel_shooting()
		is_shooting = false

func _apply_damage_effects(damage: int, knockback_direction: Vector2, knockback_force: float) -> void:
	is_damaged = true
	state = PLAYER_STATE.DAMAGED
	ignore_jump_horizontal_velocity = true
	player_damaged.handle_damage(damage, "damaged", knockback_direction, knockback_force)

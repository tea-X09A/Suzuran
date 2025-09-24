class_name PlayerManager
extends RefCounted

# ======================== 参照変数 ========================

# プレイヤーノードへの参照
var player: CharacterBody2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# ======================== アニメーション管理変数 ========================

# 現在のアニメーション名（重複再生を避けるため）
var current_animation: String = ""

# アニメーション名プレフィックス（conditionに依存）
var animation_prefix_map: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: "normal",
	Player.PLAYER_CONDITION.EXPANSION: "expansion"
}

# ======================== タイマー関連パラメータ ========================

# タイマー関連パラメータの定義 (基本仕様として固定)
var jump_buffer_time: float = 0.1              # ジャンプバッファ時間（秒）
var jump_coyote_time: float = 0.1              # コヨーテタイム（秒）
var action_buffer_time: float = 0.05           # アクションバッファ時間（秒）
var state_lock_time: float = 0.1               # 状態ロック時間（秒）

# タイマー変数
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var action_buffer_timer: float = 0.0
var state_lock_timer: float = 0.0

# 前フレームの接地状態
var was_grounded: bool = false

# カスタムタイマー管理
var custom_timers: Dictionary = {}

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# ======================== 入力処理機能（旧PlayerInputから統合） ========================

## メイン入力処理
func handle_input() -> void:
	_handle_action_inputs()
	_handle_movement_inputs()
	_handle_jump_inputs()

## ダメージ中の入力処理
func handle_damaged_input() -> void:
	# ダメージ中は移動を制限
	player.direction_x = 0.0
	player.is_running = false

	# 特定状態でのジャンプ入力処理
	var damaged_state = player.get_current_damaged()
	var can_jump: bool = damaged_state.is_in_knockback_state() or damaged_state.is_in_knockback_landing_state()
	if can_jump and Input.is_action_just_pressed("jump"):
		damaged_state.handle_recovery_jump()
		player.handle_jump()

# ======================== 個別入力処理 ========================

func _handle_action_inputs() -> void:
	player.is_squatting = player.is_grounded and Input.is_action_pressed("squat") and _can_perform_action()

	if Input.is_action_just_pressed("fighting") and _can_perform_action():
		player.handle_fighting()

	if Input.is_action_just_pressed("shooting"):
		if _can_perform_action() and _can_shoot():
			# 射撃開始時の走行状態を保存（射撃終了後に復元するため）
			player.running_state_when_action_started = player.is_running
			# ShootingStateに状態遷移（状態設定とhurtbox切り替えはenter()で行われる）
			player.change_state("shooting")

func _handle_movement_inputs() -> void:
	var left_key: bool = Input.is_action_pressed("left")
	var right_key: bool = Input.is_action_pressed("right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if _can_move():
		_set_movement_direction(left_key, right_key, shift_pressed)
	else:
		# fighting/shooting中でも左右入力は処理する（空中制御のため）
		if _is_airborne_state() and (player.is_fighting() or player.is_shooting()):
			_set_direction_only(left_key, right_key)
		else:
			player.direction_x = 0.0
			# アクション中でない場合のみ running 状態をリセット
			if player.is_grounded and not (player.is_fighting() or player.is_shooting()):
				player.is_running = false

func _handle_jump_inputs() -> void:
	if Input.is_action_just_pressed("jump") and _can_jump():
		set_jump_buffer()

	if can_buffer_jump():
		player.handle_jump()

# ======================== 入力条件チェック ========================

func _can_perform_action() -> bool:
	return not player.is_fighting() and not player.is_shooting() and not player.is_damaged()

func _can_shoot() -> bool:
	# Playerクラスから直接射撃可能かどうかを判定
	return player.can_shoot()

func _can_move() -> bool:
	# しゃがみ中は移動不可
	if player.is_squatting:
		return false

	# 空中（jump/fall状態）では常に左右移動を許可
	if _is_airborne_state():
		return true

	# 地上では通常のアクション制限を適用
	return _can_perform_action()

func _can_jump() -> bool:
	return not player.is_squatting and _can_perform_action()

func _set_movement_direction(left_key: bool, right_key: bool, shift_pressed: bool) -> void:
	if player.is_grounded:
		if left_key:
			player.direction_x = -1.0
			# アクション中でない場合のみ running 状態を更新
			if not (player.is_fighting() or player.is_shooting()):
				player.is_running = shift_pressed
		elif right_key:
			player.direction_x = 1.0
			# アクション中でない場合のみ running 状態を更新
			if not (player.is_fighting() or player.is_shooting()):
				player.is_running = shift_pressed
		else:
			player.direction_x = 0.0
			# アクション中でない場合のみ running 状態をリセット
			if not (player.is_fighting() or player.is_shooting()):
				player.is_running = false
	else:
		# 空中では方向のみ設定し、running状態は変更しない（保存された状態を維持）
		_set_direction_only(left_key, right_key)

func _set_direction_only(left_key: bool, right_key: bool) -> void:
	# 方向のみを設定し、running 状態は変更しない
	if left_key:
		player.direction_x = -1.0
	elif right_key:
		player.direction_x = 1.0
	else:
		player.direction_x = 0.0

# ======================== タイマー管理機能（旧PlayerTimerから統合） ========================

## メインタイマー更新
func update_timers(delta: float) -> void:
	_handle_landing_events()
	_update_jump_timers(delta)
	_update_action_timers(delta)
	_update_state_timers(delta)
	update_custom_timers(delta)

func _handle_landing_events() -> void:
	if not was_grounded and player.is_grounded:
		# 着地時のリセット処理
		player.is_jumping_by_input = false
		player.ignore_jump_horizontal_velocity = false

		# ダメージ状態の処理
		if player.is_damaged() and player.get_current_damaged().is_in_knockback_state():
			player.get_current_damaged().start_down_state()

		# 空中アクションのキャンセル（State Machineから呼び出し）
		if player.is_fighting() and player.current_state != null and player.current_state.has_method("is_airborne_attack") and player.current_state.is_airborne_attack():
			if player.current_state.has_method("cancel_fighting"):
				player.current_state.cancel_fighting()
		if player.is_shooting() and player.current_state != null and player.current_state.has_method("is_airborne_attack") and player.current_state.is_airborne_attack():
			if player.current_state.has_method("cancel_shooting"):
				player.current_state.cancel_shooting()

# ======================== ジャンプタイマー管理 ========================

func _update_jump_timers(delta: float) -> void:
	# コヨーテタイマー（地面から離れた後の猶予時間）
	if player.is_grounded:
		coyote_timer = jump_coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# ジャンプバッファタイマー（ジャンプ入力の先行受付時間）
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

func set_jump_buffer() -> void:
	jump_buffer_timer = jump_buffer_time

func reset_jump_timers() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

func can_buffer_jump() -> bool:
	return jump_buffer_timer > 0.0 and coyote_timer > 0.0

# ======================== アクションタイマー管理 ========================

func _update_action_timers(delta: float) -> void:
	action_buffer_timer = max(0.0, action_buffer_timer - delta)

func set_action_buffer() -> void:
	action_buffer_timer = action_buffer_time

func can_buffer_action() -> bool:
	return action_buffer_timer > 0.0

# ======================== 状態タイマー管理 ========================

func _update_state_timers(delta: float) -> void:
	state_lock_timer = max(0.0, state_lock_timer - delta)

func set_state_lock() -> void:
	state_lock_timer = state_lock_time

func is_state_locked() -> bool:
	return state_lock_timer > 0.0

# ======================== 接地状態管理 ========================

func update_ground_state() -> void:
	was_grounded = player.is_grounded
	player.is_grounded = player.is_on_floor()

func just_landed() -> bool:
	return not was_grounded and player.is_grounded

func just_left_ground() -> bool:
	return was_grounded and not player.is_grounded

# ======================== カスタムタイマー管理 ========================

func add_custom_timer(name: String, duration: float) -> void:
	custom_timers[name] = duration

func update_custom_timers(delta: float) -> void:
	for timer_name in custom_timers.keys():
		custom_timers[timer_name] = max(0.0, custom_timers[timer_name] - delta)
		if custom_timers[timer_name] <= 0.0:
			custom_timers.erase(timer_name)

func get_custom_timer(name: String) -> float:
	return custom_timers.get(name, 0.0)

func has_custom_timer(name: String) -> bool:
	return custom_timers.has(name) and custom_timers[name] > 0.0

func remove_custom_timer(name: String) -> void:
	custom_timers.erase(name)

# ======================== アニメーション管理機能（旧PlayerStateから必要部分のみ移行） ========================

## アニメーション状態をリセット（重複再生回避を解除）
func reset_animation_state() -> void:
	current_animation = ""

## 条件プレフィックス取得（各状態から利用可能）
func get_condition_prefix() -> String:
	return animation_prefix_map[condition]

# ======================== 状態判定ヘルパー ========================

func _is_airborne_state() -> bool:
	# 空中状態の簡易判定（Player.gdのロジックに依存せず独立判定）
	return not player.is_on_floor()

# ======================== デバッグ・情報取得機能 ========================

func get_input_state_info() -> Dictionary:
	return {
		"can_perform_action": _can_perform_action(),
		"can_move": _can_move(),
		"can_jump": _can_jump(),
		"direction_x": player.direction_x,
		"is_running": player.is_running,
		"is_squatting": player.is_squatting
	}

func get_timer_info() -> Dictionary:
	return {
		"jump_buffer_timer": jump_buffer_timer,
		"coyote_timer": coyote_timer,
		"action_buffer_timer": action_buffer_timer,
		"state_lock_timer": state_lock_timer,
		"can_buffer_jump": can_buffer_jump(),
		"can_buffer_action": can_buffer_action(),
		"is_state_locked": is_state_locked(),
		"just_landed": just_landed(),
		"just_left_ground": just_left_ground(),
		"custom_timers": custom_timers.duplicate()
	}

func validate_input_state() -> bool:
	# 入力状態の整合性チェック
	if player.is_squatting and (player.is_fighting() or player.is_shooting()):
		return false

	if player.is_damaged() and (player.is_fighting() or player.is_shooting()):
		return false

	return true

func debug_print_timers() -> void:
	print("=== Player Manager Timers ===")
	print("Jump Buffer: ", jump_buffer_timer)
	print("Coyote Time: ", coyote_timer)
	print("Action Buffer: ", action_buffer_timer)
	print("State Lock: ", state_lock_timer)
	if custom_timers.size() > 0:
		print("Custom Timers: ", custom_timers)
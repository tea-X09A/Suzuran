class_name PlayerTimer
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# タイマー関連パラメータの定義 - conditionに応じて選択される
var timer_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"jump_buffer_time": 0.1,              # ジャンプバッファ時間（秒）
		"jump_coyote_time": 0.1,              # コヨーテタイム（秒）
		"action_buffer_time": 0.05,           # アクションバッファ時間（秒）
		"state_lock_time": 0.1                # 状態ロック時間（秒）
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"jump_buffer_time": 0.12,             # 拡張状態でのジャンプバッファ時間（秒）
		"jump_coyote_time": 0.12,             # 拡張状態でのコヨーテタイム（秒）
		"action_buffer_time": 0.06,           # 拡張状態でのアクションバッファ時間（秒）
		"state_lock_time": 0.08               # 拡張状態での状態ロック時間（秒）
	}
}

# タイマー変数
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var action_buffer_timer: float = 0.0
var state_lock_timer: float = 0.0

# 前フレームの接地状態
var was_grounded: bool = false

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition

func get_parameter(key: String) -> Variant:
	return timer_parameters[condition][key]

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# =====================================================
# メインタイマー更新
# =====================================================

func update_timers(delta: float) -> void:
	_handle_landing_events()
	_update_jump_timers(delta)
	_update_action_timers(delta)
	_update_state_timers(delta)

func _handle_landing_events() -> void:
	if not was_grounded and player.is_grounded:
		# 着地時のリセット処理
		player.is_jumping_by_input = false
		player.ignore_jump_horizontal_velocity = false

		# ダメージ状態の処理
		if player.is_damaged and player.player_damaged.is_in_knockback_state():
			player.player_damaged.start_down_state()

		# 空中アクションのキャンセル
		if player.is_fighting and player.get_current_fighting().is_airborne_attack():
			player.get_current_fighting().cancel_fighting()
		if player.is_shooting and player.get_current_shooting().is_airborne_attack():
			player.get_current_shooting().cancel_shooting()

# =====================================================
# ジャンプタイマー管理
# =====================================================

func _update_jump_timers(delta: float) -> void:
	# コヨーテタイマー（地面から離れた後の猶予時間）
	if player.is_grounded:
		coyote_timer = get_parameter("jump_coyote_time")
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# ジャンプバッファタイマー（ジャンプ入力の先行受付時間）
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

func set_jump_buffer() -> void:
	jump_buffer_timer = get_parameter("jump_buffer_time")

func reset_jump_timers() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

func can_buffer_jump() -> bool:
	return jump_buffer_timer > 0.0 and coyote_timer > 0.0

func get_jump_buffer_time() -> float:
	return get_parameter("jump_buffer_time")

func get_coyote_time() -> float:
	return get_parameter("jump_coyote_time")

# =====================================================
# アクションタイマー管理
# =====================================================

func _update_action_timers(delta: float) -> void:
	action_buffer_timer = max(0.0, action_buffer_timer - delta)

func set_action_buffer() -> void:
	action_buffer_timer = get_parameter("action_buffer_time")

func can_buffer_action() -> bool:
	return action_buffer_timer > 0.0

func get_action_buffer_time() -> float:
	return get_parameter("action_buffer_time")

# =====================================================
# 状態タイマー管理
# =====================================================

func _update_state_timers(delta: float) -> void:
	state_lock_timer = max(0.0, state_lock_timer - delta)

func set_state_lock() -> void:
	state_lock_timer = get_parameter("state_lock_time")

func is_state_locked() -> bool:
	return state_lock_timer > 0.0

func get_state_lock_time() -> float:
	return get_parameter("state_lock_time")

# =====================================================
# 接地状態管理
# =====================================================

func update_ground_state() -> void:
	was_grounded = player.is_grounded
	player.is_grounded = player.is_on_floor()

func just_landed() -> bool:
	return not was_grounded and player.is_grounded

func just_left_ground() -> bool:
	return was_grounded and not player.is_grounded

# =====================================================
# カスタムタイマー管理
# =====================================================

var custom_timers: Dictionary = {}

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

# =====================================================
# タイマー情報取得
# =====================================================

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

func debug_print_timers() -> void:
	print("=== Player Timers ===")
	print("Jump Buffer: ", jump_buffer_timer)
	print("Coyote Time: ", coyote_timer)
	print("Action Buffer: ", action_buffer_timer)
	print("State Lock: ", state_lock_timer)
	if custom_timers.size() > 0:
		print("Custom Timers: ", custom_timers)
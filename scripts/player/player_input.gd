class_name PlayerInput
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# ======================== メイン入力処理 ========================

func handle_input() -> void:
	_handle_action_inputs()
	_handle_movement_inputs()
	_handle_jump_inputs()

func handle_damaged_input() -> void:
	# ダメージ中は移動を制限
	player.direction_x = 0.0
	player.is_running = false

	# 特定状態でのジャンプ入力処理
	var can_jump: bool = player.player_damaged.is_in_knockback_state() or player.player_damaged.is_in_knockback_landing_state()
	if can_jump and Input.is_action_just_pressed("jump"):
		player.player_damaged.handle_recovery_jump()
		player.handle_jump()

# ======================== 個別入力処理 ========================

func _handle_action_inputs() -> void:
	player.is_squatting = player.is_grounded and Input.is_action_pressed("squat") and _can_perform_action()

	if Input.is_action_just_pressed("fight") and _can_perform_action():
		player.handle_fighting()

	if Input.is_action_just_pressed("shooting"):
		if _can_perform_action():
			player.handle_shooting()
		elif player.is_shooting and not player.is_damaged:
			player.handle_back_jump_shooting()

func _handle_movement_inputs() -> void:
	var left_key: bool = Input.is_action_pressed("left")
	var right_key: bool = Input.is_action_pressed("right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if _can_move():
		_set_movement_direction(left_key, right_key, shift_pressed)
	else:
		# fighting/shooting中でも左右入力は処理する（空中制御のため）
		if player.player_state.is_airborne_state() and (player.is_fighting or player.is_shooting):
			_set_direction_only(left_key, right_key)
		else:
			player.direction_x = 0.0
			# アクション中でない場合のみ running 状態をリセット
			if player.is_grounded and not (player.is_fighting or player.is_shooting):
				player.is_running = false

func _handle_jump_inputs() -> void:
	if Input.is_action_just_pressed("jump") and _can_jump():
		player.player_timer.set_jump_buffer()

	if player.player_timer.can_buffer_jump():
		player.handle_jump()

# ======================== 入力条件チェック ========================

func _can_perform_action() -> bool:
	return not player.is_fighting and not player.is_shooting and not player.is_damaged

func _can_move() -> bool:
	# しゃがみ中は移動不可
	if player.is_squatting:
		return false

	# 空中（jump/fall状態）では常に左右移動を許可
	if player.player_state.is_airborne_state():
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
			if not (player.is_fighting or player.is_shooting):
				player.is_running = shift_pressed
		elif right_key:
			player.direction_x = 1.0
			# アクション中でない場合のみ running 状態を更新
			if not (player.is_fighting or player.is_shooting):
				player.is_running = shift_pressed
		else:
			player.direction_x = 0.0
			# アクション中でない場合のみ running 状態をリセット
			if not (player.is_fighting or player.is_shooting):
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

# ======================== 入力バリデーション ========================

func validate_input_state() -> bool:
	# 入力状態の整合性チェック
	if player.is_squatting and (player.is_fighting or player.is_shooting):
		return false

	if player.is_damaged and (player.is_fighting or player.is_shooting):
		return false

	return true

func get_input_state_info() -> Dictionary:
	return {
		"can_perform_action": _can_perform_action(),
		"can_move": _can_move(),
		"can_jump": _can_jump(),
		"direction_x": player.direction_x,
		"is_running": player.is_running,
		"is_squatting": player.is_squatting
	}
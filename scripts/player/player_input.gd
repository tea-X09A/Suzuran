class_name PlayerInput
extends RefCounted

# ======================== プレイヤー参照 ========================
var player: CharacterBody2D

# タイマー定数
const JUMP_BUFFER_TIME: float = 0.1
const JUMP_COYOTE_TIME: float = 0.1

# タイマー関連パラメータ
var jump_buffer_time: float = JUMP_BUFFER_TIME
var jump_coyote_time: float = JUMP_COYOTE_TIME

# タイマー変数
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0

# 前フレームの接地状態
var was_grounded: bool = false

# ======================== 初期化処理 ========================
func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance

# ======================== メイン入力処理 ========================
## 通常状態の入力処理
func handle_input() -> void:
	_handle_movement_inputs()
	_handle_action_inputs()
	_handle_jump_inputs()

## ダメージ状態時の入力処理
func handle_damaged_input() -> void:
	# ダメージ中は移動を制限
	player.direction_x = 0.0
	player.is_running = false

	# 特定ダメージ状態でのジャンプ入力処理
	var damaged_state: DamagedState = player.get_current_damaged()
	if damaged_state != null:
		var can_jump: bool = damaged_state.is_in_knockback_state() or damaged_state.is_in_knockback_landing_state()
		if can_jump and Input.is_action_just_pressed("jump"):
			# recovery_jump処理はDamagedState内で完結するため、handle_jump()の追加呼び出しは不要
			damaged_state.handle_recovery_jump()

# ======================== 個別入力処理 ========================
func _handle_movement_inputs() -> void:
	var left_key: bool = Input.is_action_pressed("left")
	var right_key: bool = Input.is_action_pressed("right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if _can_move():
		_set_movement_direction(left_key, right_key, shift_pressed)
	else:
		# 空中でのアクション中は方向のみ設定
		if _is_airborne() and (player.state == Player.PLAYER_STATE.FIGHTING or player.state == Player.PLAYER_STATE.SHOOTING):
			_set_direction_only(left_key, right_key)
		else:
			player.direction_x = 0.0
			# 地上でアクション中でない場合はrunning状態をリセット
			if player.is_grounded and not (player.state == Player.PLAYER_STATE.FIGHTING or player.state == Player.PLAYER_STATE.SHOOTING):
				player.is_running = false

func _handle_action_inputs() -> void:
	# しゃがみ入力
	player.is_squatting = player.is_grounded and Input.is_action_pressed("squat") and _can_perform_action()

	# 戦闘入力
	if Input.is_action_just_pressed("fighting_01") and _can_perform_action():
		player.handle_fighting()

	# 射撃入力
	if Input.is_action_just_pressed("shooting") and _can_perform_action() and player.can_shoot():
		# 射撃開始時の走行状態を保存
		player.running_state_when_action_started = player.is_running
		player.change_state("shooting")

func _handle_jump_inputs() -> void:
	if Input.is_action_just_pressed("jump") and _can_jump():
		set_jump_buffer()

	if can_buffer_jump():
		player.handle_jump()

# ======================== 入力条件チェック ========================
func _can_perform_action() -> bool:
	return not (player.state == Player.PLAYER_STATE.FIGHTING or player.state == Player.PLAYER_STATE.SHOOTING or player.state == Player.PLAYER_STATE.DAMAGED)

func _can_move() -> bool:
	# しゃがみ中は移動不可
	if player.is_squatting:
		return false

	# 空中では常に左右移動を許可
	if _is_airborne():
		return true

	# 地上では通常のアクション制限を適用
	return _can_perform_action()

func _can_jump() -> bool:
	return not player.is_squatting and _can_perform_action()

# ======================== 移動方向設定 ========================
func _set_movement_direction(left_key: bool, right_key: bool, shift_pressed: bool) -> void:
	if player.is_grounded:
		if left_key:
			player.direction_x = -1.0
			# アクション中でない場合のみrunning状態を更新
			if not (player.state == Player.PLAYER_STATE.FIGHTING or player.state == Player.PLAYER_STATE.SHOOTING):
				player.is_running = shift_pressed
		elif right_key:
			player.direction_x = 1.0
			# アクション中でない場合のみrunning状態を更新
			if not (player.state == Player.PLAYER_STATE.FIGHTING or player.state == Player.PLAYER_STATE.SHOOTING):
				player.is_running = shift_pressed
		else:
			player.direction_x = 0.0
			# アクション中でない場合のみrunning状態をリセット
			if not (player.state == Player.PLAYER_STATE.FIGHTING or player.state == Player.PLAYER_STATE.SHOOTING):
				player.is_running = false
	else:
		# 空中では方向のみ設定（running状態は保存された状態を維持）
		_set_direction_only(left_key, right_key)

func _set_direction_only(left_key: bool, right_key: bool) -> void:
	if left_key:
		player.direction_x = -1.0
	elif right_key:
		player.direction_x = 1.0
	else:
		player.direction_x = 0.0

# ======================== ジャンプバッファ・コヨーテタイム管理 ========================
## タイマー更新処理
func update_timers(delta: float) -> void:
	_handle_ground_state_changes()
	_update_jump_timers(delta)

func _handle_ground_state_changes() -> void:
	if not was_grounded and player.is_grounded:
		# 着地時の処理
		player.is_jumping_by_input = false
		player.ignore_jump_horizontal_velocity = false

func _update_jump_timers(delta: float) -> void:
	# コヨーテタイマー（地面から離れた後の猶予時間）
	if player.is_grounded:
		coyote_timer = jump_coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# ジャンプバッファタイマー（ジャンプ入力の先行受付時間）
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

## 接地状態の更新
func update_ground_state() -> void:
	was_grounded = player.is_grounded
	player.is_grounded = player.is_on_floor()

## ジャンプバッファ設定
func set_jump_buffer() -> void:
	jump_buffer_timer = jump_buffer_time

## ジャンプタイマーリセット
func reset_jump_timers() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

## バッファジャンプ可能判定
func can_buffer_jump() -> bool:
	return jump_buffer_timer > 0.0 and coyote_timer > 0.0

# ======================== ユーティリティメソッド ========================
func _is_airborne() -> bool:
	return not player.is_on_floor()

## 着地判定
func just_landed() -> bool:
	return not was_grounded and player.is_grounded

## 地面離脱判定
func just_left_ground() -> bool:
	return was_grounded and not player.is_grounded

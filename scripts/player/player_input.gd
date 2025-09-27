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
## 入力処理（State Machine対応済み）
func handle_input() -> void:
	_handle_movement_inputs()
	_handle_action_inputs()
	_handle_jump_inputs()

# ======================== 個別入力処理 ========================
func _handle_movement_inputs() -> void:
	var left_key: bool = Input.is_action_pressed("left")
	var right_key: bool = Input.is_action_pressed("right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	_set_movement_direction(left_key, right_key, shift_pressed)

func _handle_action_inputs() -> void:
	# 戦闘入力
	if Input.is_action_just_pressed("fighting_01"):
		player.handle_fighting()

func _handle_jump_inputs() -> void:
	if Input.is_action_just_pressed("jump"):
		set_jump_buffer()

	if can_buffer_jump():
		player.handle_jump()

# ======================== 移動方向設定 ========================
func _set_movement_direction(left_key: bool, right_key: bool, shift_pressed: bool) -> void:
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
	pass  # 着地時の処理はState Machineに移譲

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
## 着地判定
func just_landed() -> bool:
	return not was_grounded and player.is_grounded

## 地面離脱判定
func just_left_ground() -> bool:
	return was_grounded and not player.is_grounded

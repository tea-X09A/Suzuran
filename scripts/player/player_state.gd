class_name PlayerState
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# 状態名の辞書（ログ用）
var state_names: Dictionary = {
	Player.PLAYER_STATE.IDLE: "待機",
	Player.PLAYER_STATE.WALK: "歩き",
	Player.PLAYER_STATE.RUN: "走り",
	Player.PLAYER_STATE.JUMP: "ジャンプ",
	Player.PLAYER_STATE.FALL: "落下",
	Player.PLAYER_STATE.SQUAT: "しゃがみ",
	Player.PLAYER_STATE.FIGHTING: "戦闘",
	Player.PLAYER_STATE.SHOOTING: "射撃",
	Player.PLAYER_STATE.DAMAGED: "ダメージ"
}

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# =====================================================
# 状態更新メイン処理
# =====================================================

func update_state() -> void:
	if _is_in_action_state():
		return

	var new_state: Player.PLAYER_STATE = _determine_new_state()
	set_state(new_state)

func _is_in_action_state() -> bool:
	return player.is_fighting or player.is_shooting or player.is_damaged

func _determine_new_state() -> Player.PLAYER_STATE:
	var current_grounded: bool = player.is_on_floor()

	if current_grounded:
		return _get_grounded_state()
	else:
		return _get_airborne_state()

func _get_grounded_state() -> Player.PLAYER_STATE:
	if player.is_squatting:
		return Player.PLAYER_STATE.SQUAT
	elif player.velocity.x == 0.0:
		return Player.PLAYER_STATE.IDLE
	else:
		return Player.PLAYER_STATE.RUN if player.is_running else Player.PLAYER_STATE.WALK

func _get_airborne_state() -> Player.PLAYER_STATE:
	if player.is_jumping_by_input and player.velocity.y < 0.0:
		return Player.PLAYER_STATE.JUMP
	else:
		return Player.PLAYER_STATE.FALL

# =====================================================
# 状態設定
# =====================================================

func set_state(new_state: Player.PLAYER_STATE) -> void:
	if new_state == player.state:
		return

	_log_state_change(new_state)
	player.state = new_state
	player.update_animation()

func force_state(new_state: Player.PLAYER_STATE) -> void:
	# 強制的に状態を変更（アクション状態でも変更可能）
	_log_state_change(new_state)
	player.state = new_state
	player.update_animation()

# =====================================================
# 条件管理
# =====================================================

func get_condition() -> Player.PLAYER_CONDITION:
	return condition

func set_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition
	_update_modules_condition(new_condition)

func _update_modules_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	if player.player_fighting:
		player.player_fighting.update_condition(new_condition)
	if player.player_shooting:
		player.player_shooting.update_condition(new_condition)

# =====================================================
# 状態チェック関数
# =====================================================

func is_grounded_state() -> bool:
	return player.state in [Player.PLAYER_STATE.IDLE, Player.PLAYER_STATE.WALK, Player.PLAYER_STATE.RUN, Player.PLAYER_STATE.SQUAT]

func is_airborne_state() -> bool:
	return player.state in [Player.PLAYER_STATE.JUMP, Player.PLAYER_STATE.FALL]

func is_action_state() -> bool:
	return player.state in [Player.PLAYER_STATE.FIGHTING, Player.PLAYER_STATE.SHOOTING, Player.PLAYER_STATE.DAMAGED]

func is_moving_state() -> bool:
	return player.state in [Player.PLAYER_STATE.WALK, Player.PLAYER_STATE.RUN]

func can_transition_to(target_state: Player.PLAYER_STATE) -> bool:
	# 状態遷移が可能かどうかをチェック
	if _is_in_action_state():
		return target_state in [Player.PLAYER_STATE.FIGHTING, Player.PLAYER_STATE.SHOOTING, Player.PLAYER_STATE.DAMAGED]

	return true

# =====================================================
# ログ処理
# =====================================================

func _log_state_change(new_state: Player.PLAYER_STATE) -> void:
	var old_state_name: String = state_names.get(player.state, "不明")
	var new_state_name: String = state_names.get(new_state, "不明")
	print("プレイヤー状態変更: ", old_state_name, " → ", new_state_name)

# =====================================================
# 状態情報取得
# =====================================================

func get_state_info() -> Dictionary:
	return {
		"current_state": player.state,
		"state_name": state_names.get(player.state, "不明"),
		"condition": condition,
		"is_grounded": is_grounded_state(),
		"is_airborne": is_airborne_state(),
		"is_action": is_action_state(),
		"is_moving": is_moving_state(),
		"can_transition": not _is_in_action_state()
	}

func get_state_name(state: Player.PLAYER_STATE = Player.PLAYER_STATE.IDLE) -> String:
	if state == Player.PLAYER_STATE.IDLE:
		state = player.state
	return state_names.get(state, "不明")
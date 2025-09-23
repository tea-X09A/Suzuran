class_name PlayerJump
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# ムーブメントアクションへの参照（NormalMovement/ExpansionMovement）
var movement_action: RefCounted
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# パラメータの定義 - conditionに応じて選択される
var jump_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"jump_force": 380.0,                    # 基本ジャンプ力（ピクセル/秒）
		"jump_vertical_bonus": 80.0,            # run中のジャンプ時の垂直ボーナス（ピクセル/秒）
		"animation_prefix": "normal"            # アニメーション名のプレフィックス
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"jump_force": 437.0,                    # 基本ジャンプ力（380.0 * 1.15）（ピクセル/秒）
		"jump_vertical_bonus": 92.0,            # run中のジャンプ時の垂直ボーナス（80.0 * 1.15）（ピクセル/秒）
		"animation_prefix": "expansion"         # アニメーション名のプレフィックス
	}
}

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, movement_ref: RefCounted, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	movement_action = movement_ref
	condition = player_condition

func get_parameter(key: String) -> Variant:
	return jump_parameters[condition][key]

# ======================== ジャンプ処理 ========================

func handle_jump() -> void:
	var effective_jump_force: float = get_parameter("jump_force")

	if player.is_running:
		# run中の場合、垂直ボーナスを適用
		effective_jump_force += get_parameter("jump_vertical_bonus")

	# 垂直速度を設定
	player.velocity.y = -effective_jump_force
	# ジャンプ状態を設定
	movement_action.set_jumping_state(true, 0.0)

# ======================== アクセサー関数 ========================

func get_jump_force() -> float:
	return get_parameter("jump_force")

func get_animation_prefix() -> String:
	return get_parameter("animation_prefix")
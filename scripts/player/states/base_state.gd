class_name BaseState
extends RefCounted

# ======================== 基本参照 ========================
var player: CharacterBody2D
var sprite_2d: Sprite2D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var state_machine: AnimationNodeStateMachinePlayback
var condition: Player.PLAYER_CONDITION

# ======================== 初期化処理 ========================
func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	# 安全な参照取得: プレイヤーのキャッシュされた各ノードを利用
	sprite_2d = player.sprite_2d
	animation_player = player.animation_player
	animation_tree = player.animation_tree
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	condition = player.condition

# ======================== AnimationTree連携メソッド ========================
## 状態初期化（AnimationTreeからのコールバック用）
func initialize_state() -> void:
	# 各Stateで実装: AnimationTree状態開始時の処理
	pass

## 状態クリーンアップ（AnimationTreeからのコールバック用）
func cleanup_state() -> void:
	# 各Stateで実装: AnimationTree状態終了時の処理
	pass

# ======================== 共通ユーティリティメソッド ========================
## パラメータ取得
func get_parameter(key: String) -> Variant:
	return PlayerParameters.get_parameter(condition, key)

## 条件更新
func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

## AnimationTree状態設定（最小限のアニメーション制御）
func set_animation_state(state_name: String) -> void:
	if state_machine:
		state_machine.travel(state_name.to_upper())

# ======================== State Machine連携ユーティリティ ========================

## 現在のstate machine状態を取得
func get_current_state_name() -> String:
	if state_machine:
		return state_machine.get_current_node()
	return ""

## 走行状態かどうかを判定
func is_running_state() -> bool:
	return get_current_state_name() == "RUN"

## 移動入力を取得
func get_movement_input() -> float:
	return Input.get_axis("left", "right")

## スプライト方向を更新
func update_sprite_direction(direction: float) -> void:
	if direction != 0.0 and sprite_2d:
		sprite_2d.flip_h = direction > 0.0
c

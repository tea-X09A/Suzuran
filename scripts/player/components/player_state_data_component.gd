## プレイヤー状態データ管理コンポーネント
## プレイヤーの状態保存・復元機能を管理
class_name PlayerStateDataComponent
extends RefCounted

# ======================== 変数 ========================

## プレイヤーへの弱参照（循環参照防止）
var _player_ref: WeakRef = null

# ======================== 初期化 ========================

## コンポーネントの初期化
## @param player CharacterBody2D プレイヤーインスタンス
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)

# ======================== 状態保存・復元 ========================

## プレイヤーの現在の状態を取得（シーン遷移時に使用）
## @return Dictionary 現在の状態を含む辞書
func get_player_state() -> Dictionary:
	var player: CharacterBody2D = _player_ref.get_ref()
	if not player:
		return {}

	return {
		"hp_count": player.health_component.current_hp if player.health_component else PlayerHealthComponent.DEFAULT_MAX_HP,
		"condition": player.condition,
		"position_x": player.position.x,
		"position_y": player.position.y,
		"direction_x": player.direction_x
	}

## プレイヤーの状態を復元（シーン遷移後に使用）
## @param state Dictionary 復元する状態の辞書
func restore_player_state(state: Dictionary) -> void:
	var player: CharacterBody2D = _player_ref.get_ref()
	if not player:
		return

	if state.is_empty():
		return

	# HPを復元（setterメソッドを使用）
	if player.health_component and state.has("hp_count"):
		player.health_component.set_hp(state["hp_count"])

	# 変身状態を復元
	if state.has("condition"):
		player.condition = state["condition"]

	# 座標を復元
	if state.has("position_x") and state.has("position_y"):
		player.position = Vector2(state["position_x"], state["position_y"])

	# 向きを復元
	if state.has("direction_x"):
		player.direction_x = state["direction_x"]
		player.sprite_2d.flip_h = player.direction_x > 0.0
		if player.collision_component:
			player.collision_component.update_box_positions(player.direction_x > 0.0)

	# UI更新
	if player.ui_component:
		player.ui_component.set_initial_values(
			player.health_component.current_hp if player.health_component else PlayerHealthComponent.DEFAULT_MAX_HP,
			player.health_component.max_hp if player.health_component else PlayerHealthComponent.DEFAULT_MAX_HP
		)

# ======================== クリーンアップ ========================

## クリーンアップ処理（メモリリーク防止）
func cleanup() -> void:
	_player_ref = null

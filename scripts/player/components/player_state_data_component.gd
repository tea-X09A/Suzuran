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

	# アクティブなバフのIDリストを取得
	var buff_ids: Array[String] = []
	for buff in player.active_buffs:
		buff_ids.append(buff.buff_id)

	return {
		"hp_count": player.health_component.current_hp if player.health_component else PlayerHealthComponent.DEFAULT_MAX_HP,
		"condition": player.condition,
		"position_x": player.position.x,
		"position_y": player.position.y,
		"direction_x": player.direction_x,
		"active_buff_ids": buff_ids
	}

## プレイヤーの状態を復元（シーン遷移後に使用）
## @param state Dictionary 復元する状態の辞書
func restore_player_state(state: Dictionary) -> void:
	var player: CharacterBody2D = _player_ref.get_ref()
	if not player:
		return

	if state.is_empty():
		return

	# UILayerが準備完了するまで1フレーム待機
	# （レベル遷移時・セーブデータロード時の両方で確実にUI更新を行うため）
	await player.get_tree().process_frame

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

	# バフを復元（UI初期化後に実行）
	if state.has("active_buff_ids"):
		var buff_ids: Array = state["active_buff_ids"]
		for buff_id in buff_ids:
			# バフIDに応じてバフを再適用
			match buff_id:
				"speed_boost":
					var speed_buff: SpeedBoostBuff = SpeedBoostBuff.new(player)
					player.apply_buff(speed_buff)

# ======================== クリーンアップ ========================

## クリーンアップ処理（メモリリーク防止）
func cleanup() -> void:
	_player_ref = null

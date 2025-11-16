## PlayerUIComponent
## プレイヤーのUI表示を管理するコンポーネント
class_name PlayerUIComponent
extends RefCounted

# ======================== UI参照 ========================

## HPゲージへの参照
var hp_gauge: Control = null

# ======================== 内部参照 ========================

## プレイヤーへの弱参照（循環参照防止）
var _player_ref: WeakRef = null

# ======================== 初期化 ========================

## コンポーネントの初期化
## @param player プレイヤーインスタンス
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)
	_find_ui_references()
	_connect_component_signals(player)

## UI参照の取得
func _find_ui_references() -> void:
	var ui_layer: CanvasLayer = _get_ui_layer()
	if not ui_layer:
		return

	# HPゲージ取得
	hp_gauge = ui_layer.get_node_or_null("HPGauge")
	if not hp_gauge:
		push_warning("[PlayerUIComponent] HPGauge not found in UILayer")

## UILayer取得
func _get_ui_layer() -> CanvasLayer:
	var player: CharacterBody2D = _player_ref.get_ref()
	if not player:
		return null

	var ui_layers: Array = player.get_tree().get_nodes_in_group("ui_layer")
	if ui_layers.is_empty():
		push_warning("[PlayerUIComponent] ui_layer group is empty")
		return null
	return ui_layers[0] as CanvasLayer

## 他のコンポーネントのシグナルに接続
func _connect_component_signals(player: CharacterBody2D) -> void:
	# HealthComponent のシグナルに接続
	if player.health_component:
		player.health_component.health_changed.connect(_on_health_changed)

## HealthComponent からの HP 変更通知
func _on_health_changed(hp: int, max_hp: int) -> void:
	update_hp_display(hp, max_hp)

# ======================== HP表示更新 ========================

## HP表示更新
## @param hp 現在のHP
## @param max_hp 最大HP
func update_hp_display(hp: int, max_hp: int) -> void:
	if hp_gauge:
		hp_gauge.hp_progress = _calculate_hp_progress(hp, max_hp)

# ======================== 初期値設定 ========================

## 初期値設定（_ready後に呼ばれる想定）
## @param hp 初期HP
## @param max_hp 最大HP
func set_initial_values(hp: int, max_hp: int) -> void:
	if hp_gauge:
		# ダメージ演出をスキップして初期値を設定
		hp_gauge.initialize_hp(_calculate_hp_progress(hp, max_hp))

# ======================== 内部ヘルパー ========================

## HP進行度を計算（0.0～1.0）
## @param hp 現在のHP
## @param max_hp 最大HP
## @return float HP進行度
func _calculate_hp_progress(hp: int, max_hp: int) -> float:
	return float(hp) / float(max_hp) if max_hp > 0 else 0.0

# ======================== クリーンアップ ========================

## クリーンアップ処理
func cleanup() -> void:
	# シグナル切断（メモリリーク防止）
	var player: CharacterBody2D = _player_ref.get_ref() if _player_ref else null
	if player:
		if player.health_component:
			if player.health_component.health_changed.is_connected(_on_health_changed):
				player.health_component.health_changed.disconnect(_on_health_changed)

	hp_gauge = null
	_player_ref = null

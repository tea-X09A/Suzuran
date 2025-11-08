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
## 現在表示中のダメージ表記への参照（重複表示防止）
var _current_damage_number: DamageNumber = null

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
		player.health_component.damage_taken.connect(_on_damage_taken)

## HealthComponent からの HP 変更通知
func _on_health_changed(hp: int, max_hp: int) -> void:
	update_hp_display(hp, max_hp)

## HealthComponent からのダメージ通知
func _on_damage_taken(damage: int, _effect_type: String) -> void:
	show_damage_number(damage)

# ======================== HP表示更新 ========================

## HP表示更新
## @param hp 現在のHP
## @param max_hp 最大HP
func update_hp_display(hp: int, max_hp: int) -> void:
	if hp_gauge:
		var progress: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
		hp_gauge.hp_progress = progress

# ======================== ダメージ表記表示 ========================

## ダメージ表記を表示
## @param damage ダメージ量
func show_damage_number(damage: int) -> void:
	var player: CharacterBody2D = _player_ref.get_ref()
	if not player:
		return

	# 既存のダメージ表記が残っていたら削除
	if _current_damage_number and is_instance_valid(_current_damage_number):
		_current_damage_number.queue_free()
		_current_damage_number = null

	# DamageNumberを直接インスタンス化
	var damage_number: DamageNumber = DamageNumber.new()
	damage_number.display_value = damage

	# 位置調整
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		var sprite_height: float = sprite.texture.get_height()
		var offset_y: float = -sprite_height / 2.0 - 20.0
		damage_number.position = Vector2(0, offset_y)
	else:
		damage_number.position = Vector2(0, -80)

	player.add_child(damage_number)
	_current_damage_number = damage_number

# ======================== 初期値設定 ========================

## 初期値設定（_ready後に呼ばれる想定）
## @param hp 初期HP
## @param max_hp 最大HP
func set_initial_values(hp: int, max_hp: int) -> void:
	update_hp_display(hp, max_hp)

# ======================== クリーンアップ ========================

## クリーンアップ処理
func cleanup() -> void:
	# シグナル切断（メモリリーク防止）
	var player: CharacterBody2D = _player_ref.get_ref() if _player_ref else null
	if player:
		if player.health_component:
			if player.health_component.health_changed.is_connected(_on_health_changed):
				player.health_component.health_changed.disconnect(_on_health_changed)
			if player.health_component.damage_taken.is_connected(_on_damage_taken):
				player.health_component.damage_taken.disconnect(_on_damage_taken)

	# 残存しているダメージ表記を削除
	if _current_damage_number and is_instance_valid(_current_damage_number):
		_current_damage_number.queue_free()
		_current_damage_number = null

	hp_gauge = null
	_player_ref = null

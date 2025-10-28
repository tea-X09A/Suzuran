## PlayerUIComponent
## プレイヤーのUI表示を管理するコンポーネント
class_name PlayerUIComponent
extends RefCounted

# ======================== UI参照 ========================

## EPゲージへの参照
var ep_gauge: Control = null
## 弾倉ゲージへの参照
var ammo_gauge: Control = null

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

	# EPゲージ取得
	ep_gauge = ui_layer.get_node_or_null("EPGauge")
	if not ep_gauge:
		push_warning("[PlayerUIComponent] EPGauge not found in UILayer")

	# Ammoゲージ取得
	ammo_gauge = ui_layer.get_node_or_null("AmmoGauge")
	if not ammo_gauge:
		push_warning("[PlayerUIComponent] AmmoGauge not found in UILayer")

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

	# EnergyComponent のシグナルに接続
	if player.energy_component:
		player.energy_component.energy_changed.connect(_on_energy_changed)

	# AmmoComponent のシグナルに接続
	if player.ammo_component:
		player.ammo_component.ammo_changed.connect(_on_ammo_changed)

## HealthComponent からの HP 変更通知
func _on_health_changed(hp: int, max_hp: int) -> void:
	update_hp_display(hp, max_hp)

## EnergyComponent からの EP 変更通知
func _on_energy_changed(ep: float, max_ep: float) -> void:
	update_ep_display(ep, max_ep)

## AmmoComponent からの弾数変更通知
func _on_ammo_changed(ammo: int) -> void:
	update_ammo_display(ammo)

## HealthComponent からのダメージ通知
func _on_damage_taken(damage: int, _effect_type: String) -> void:
	show_damage_number(damage)

# ======================== HP表示更新 ========================

## HP表示更新
## @param hp 現在のHP
## @param _max_hp 最大HP
func update_hp_display(hp: int, _max_hp: int) -> void:
	if ep_gauge:
		ep_gauge.hp_value = hp

# ======================== EP表示更新 ========================

## EP表示更新
## @param ep 現在のEP
## @param max_ep 最大EP
func update_ep_display(ep: float, max_ep: float) -> void:
	if ep_gauge:
		var progress: float = ep / max_ep if max_ep > 0 else 0.0
		ep_gauge.ep_progress = progress

# ======================== 弾数表示更新 ========================

## 弾数表示更新
## @param ammo 現在の弾数
func update_ammo_display(ammo: int) -> void:
	if ammo_gauge:
		ammo_gauge.ammo_count = ammo

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
## @param ep 初期EP
## @param max_ep 最大EP
## @param ammo 初期弾数
func set_initial_values(hp: int, max_hp: int, ep: float, max_ep: float, ammo: int) -> void:
	update_hp_display(hp, max_hp)
	update_ep_display(ep, max_ep)
	update_ammo_display(ammo)

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

		if player.energy_component:
			if player.energy_component.energy_changed.is_connected(_on_energy_changed):
				player.energy_component.energy_changed.disconnect(_on_energy_changed)

		if player.ammo_component:
			if player.ammo_component.ammo_changed.is_connected(_on_ammo_changed):
				player.ammo_component.ammo_changed.disconnect(_on_ammo_changed)

	# 残存しているダメージ表記を削除
	if _current_damage_number and is_instance_valid(_current_damage_number):
		_current_damage_number.queue_free()
		_current_damage_number = null

	ep_gauge = null
	ammo_gauge = null
	_player_ref = null

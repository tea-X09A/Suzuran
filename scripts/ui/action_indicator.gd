class_name ActionIndicator
extends Control

## アクションキー表示用のインジケーターUI
##
## プレイヤーや調査可能オブジェクトの上に表示され、
## インタラクション可能であることを視覚的に示します。
##
## 使用例:
## ```
## var indicator = ActionIndicator.new()
## add_child(indicator)
## indicator.update_position(sprite_2d)
## indicator.show_indicator()
## ```

# ======================== エクスポートプロパティ ========================

## 背景色
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.9)

## テキスト色
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## フォントサイズ
@export var font_size: int = 18

## 角の丸み
@export var corner_radius: int = 4

## 縦方向のオフセット（デフォルト値、負の値で上方向）
@export var vertical_offset: float = -60.0

## 枠線の太さ
@export var border_width: int = 2

## 枠線の色
@export var border_color: Color = Color(0.8, 0.8, 0.8, 1.0)

# ======================== 内部ノード参照 ========================

## PanelContainerへの参照
var _panel: PanelContainer = null

## Labelへの参照
var _label: Label = null

# ======================== 初期化処理 ========================

func _ready() -> void:
	_create_ui()
	visible = false  # デフォルトは非表示

	# 初期キーテキストを設定
	_update_key_text()

	# 入力デバイス変更シグナルに接続
	GameSettings.input_device_changed.connect(_on_input_device_changed)

	# 言語変更シグナルに接続
	GameSettings.language_changed.connect(_on_language_changed)

## UI要素を作成
func _create_ui() -> void:
	# PanelContainer作成
	_panel = PanelContainer.new()

	# スタイル設定
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color

	_panel.add_theme_stylebox_override("panel", style)

	# Label作成
	_label = Label.new()
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.custom_minimum_size = Vector2(24, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_panel.add_child(_label)
	add_child(_panel)

	# パネルサイズ変更時に位置を自動更新
	_panel.resized.connect(_on_panel_resized)

func _exit_tree() -> void:
	# シグナルの切断
	if _panel and _panel.resized.is_connected(_on_panel_resized):
		_panel.resized.disconnect(_on_panel_resized)
	if GameSettings.input_device_changed.is_connected(_on_input_device_changed):
		GameSettings.input_device_changed.disconnect(_on_input_device_changed)
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)

# ======================== 表示制御 ========================

## インジケーターを表示
func show_indicator() -> void:
	visible = true

## インジケーターを非表示
func hide_indicator() -> void:
	visible = false

# ======================== 位置更新 ========================

## インジケーターの位置を更新
##
## @param target_sprite 位置計算の基準となるSprite2D（nullの場合はデフォルト位置）
func update_position(target_sprite: Sprite2D = null) -> void:
	var offset_y: float = vertical_offset

	# Sprite2Dが指定されている場合、その高さに基づいて位置調整
	if target_sprite and target_sprite.texture:
		offset_y = -(target_sprite.texture.get_height() / 2.0 + 20.0)

	# パネルの幅を取得（まだ計算されていない場合はデフォルト値）
	var indicator_width: float = _panel.size.x if _panel and _panel.size.x > 0 else 30.0
	# インジケーターの中心がSpriteの上に来るように調整
	position = Vector2(-indicator_width / 2.0, offset_y)

## パネルリサイズ時のコールバック
##
## テキスト変更によりパネルサイズが変わった際、自動的に位置を再計算して中央揃えを維持します。
func _on_panel_resized() -> void:
	# 親ノード（Player）からSprite2Dを取得
	var parent_node: Node = get_parent()
	if parent_node:
		var player_sprite: Sprite2D = parent_node.get_node_or_null("Sprite2D")
		if player_sprite:
			update_position(player_sprite)

# ======================== カスタマイズ ========================

## キーテキストを動的に変更
##
## @param new_key 新しいキーテキスト
func set_action_key(new_key: String) -> void:
	if _label:
		_label.text = new_key

## 背景色を動的に変更
##
## @param new_color 新しい背景色
func set_background_color(new_color: Color) -> void:
	background_color = new_color
	if _panel:
		var style: StyleBoxFlat = _panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = new_color

## テキスト色を動的に変更
##
## @param new_color 新しいテキスト色
func set_text_color(new_color: Color) -> void:
	text_color = new_color
	if _label:
		_label.add_theme_color_override("font_color", new_color)

# ======================== 入力デバイス・言語対応 ========================

## 入力デバイス変更時のコールバック
func _on_input_device_changed(_device_type: int) -> void:
	_update_key_text()

## 言語変更時のコールバック
func _on_language_changed(_new_language: String) -> void:
	_update_key_text()

## デバイスと言語に応じたキーテキストを更新
func _update_key_text() -> void:
	var key_text: String = _get_appropriate_key_text()
	set_action_key(key_text)

## 現在のデバイスと言語に応じた適切なキーテキストを取得
func _get_appropriate_key_text() -> String:
	var device: GameSettings.InputDevice = GameSettings.get_last_used_device()
	var language: GameSettings.Language = GameSettings.current_language

	# キーボードの場合
	if device == GameSettings.InputDevice.KEYBOARD:
		if language == GameSettings.Language.JAPANESE:
			return "Z"
		else:  # English
			return " Enter "
	# ゲームパッドの場合
	else:  # GAMEPAD
		if language == GameSettings.Language.JAPANESE:
			return "⚪︎"
		else:  # English
			return "×"

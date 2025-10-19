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

## 表示するキーテキスト
@export var action_key_text: String = "Z"

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
	_label.text = action_key_text
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.custom_minimum_size = Vector2(24, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_panel.add_child(_label)
	add_child(_panel)

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

# ======================== カスタマイズ ========================

## キーテキストを動的に変更
##
## @param new_key 新しいキーテキスト
func set_action_key(new_key: String) -> void:
	action_key_text = new_key
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

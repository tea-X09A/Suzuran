extends Button

## 会話システムの選択肢ボタン
##
## プレイヤーが選択できる会話の分岐オプションを表示します。
## 選択状態と非選択状態で異なるスタイルを適用します。
## sow.mdの要件に基づいて実装されています。

# ======================== シグナル定義 ========================

## 選択肢が選択された時に発信（choice_indexを含む）
signal choice_selected(choice_index: int)

# ======================== フォントサイズ設定 ========================

## 選択肢のフォントサイズ
@export var choice_font_size: int = 32

# ======================== 状態管理変数 ========================

## この選択肢のインデックス
var choice_index: int = 0

## 選択状態
var is_selected_state: bool = false

# ======================== スタイル定義（@onreadyでキャッシュ） ========================

## 選択状態のスタイル
@onready var selected_style: StyleBoxFlat = _create_selected_style()

## 非選択状態のスタイル
@onready var normal_style: StyleBoxFlat = _create_normal_style()

# ======================== 初期化処理 ========================

func _ready() -> void:
	# フォントサイズを動的に設定
	add_theme_font_size_override("font_size", choice_font_size)

	# ボタンのpressedシグナルに接続
	pressed.connect(_on_button_pressed)

	# 初期状態は非選択
	set_selected(false)

# ======================== 公開API ========================

## 選択肢を設定する
##
## @param choice_text String 選択肢のテキスト
## @param index int 選択肢のインデックス
func setup(choice_text: String, index: int) -> void:
	text = choice_text
	choice_index = index

## 選択状態を設定する
##
## @param selected bool 選択状態（true=選択中、false=非選択）
func set_selected(selected: bool) -> void:
	is_selected_state = selected

	# 選択状態に応じてスタイルを適用
	if selected:
		_apply_selected_style()
	else:
		_apply_normal_style()

# ======================== 内部処理 ========================

## 選択状態のスタイルを作成
func _create_selected_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	# 背景色（白色30%不透明度）
	style.bg_color = Color(1.0, 1.0, 1.0, 0.3)

	# ボーダー設定（白色100%不透明度、3ピクセル幅）
	style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3

	# コーナー半径（8ピクセル）
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	return style

## 非選択状態のスタイルを作成
func _create_normal_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	# 背景色（完全透明）
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)

	# ボーダー設定（透明、レイアウトシフトを防ぐため3px幅を維持）
	style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3

	# コーナー半径（8ピクセル）
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	return style

## 選択状態のスタイルを適用
func _apply_selected_style() -> void:
	# すべてのボタン状態に同じスタイルを適用
	add_theme_stylebox_override("normal", selected_style)
	add_theme_stylebox_override("pressed", selected_style)
	add_theme_stylebox_override("hover", selected_style)
	add_theme_stylebox_override("focus", selected_style)

## 非選択状態のスタイルを適用
func _apply_normal_style() -> void:
	# すべてのボタン状態に同じスタイルを適用
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("pressed", normal_style)
	add_theme_stylebox_override("hover", normal_style)
	add_theme_stylebox_override("focus", normal_style)

## ボタンが押された時の処理
func _on_button_pressed() -> void:
	choice_selected.emit(choice_index)

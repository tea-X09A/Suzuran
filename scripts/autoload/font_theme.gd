extends Node
## FontTheme AutoLoad
## グローバルなフォントテーマ管理システム
## NotoSansJP フォントの適用とサイズ管理を一元化する

# フォントリソースのプリロード
const NOTO_SANS_JP: FontFile = preload("res://assets/fonts/NotoSansJP-Regular.ttf")

# 共通フォントサイズの定数定義
const FONT_SIZE_SMALL: int = 24
const FONT_SIZE_MEDIUM: int = 28
const FONT_SIZE_LARGE: int = 32
const FONT_SIZE_XL: int = 36
const FONT_SIZE_XXL: int = 42


## 太字フォントバリエーションを生成する
## @param base_font ベースとなるフォント（デフォルトは NOTO_SANS_JP）
## @return 太字化された FontVariation
func create_bold_font(base_font: FontFile = NOTO_SANS_JP) -> FontVariation:
	var bold_font: FontVariation = FontVariation.new()
	bold_font.base_font = base_font
	bold_font.variation_embolden = 0.8
	return bold_font


## Label にフォントとサイズを適用する
## @param label 対象の Label ノード
## @param font_size フォントサイズ
## @param use_bold 太字を使用するか（デフォルトは false）
func apply_to_label(label: Label, font_size: int, use_bold: bool = false) -> void:
	if not label:
		push_warning("FontTheme: Label が null です")
		return

	if use_bold:
		label.add_theme_font_override("font", create_bold_font())
	else:
		label.add_theme_font_override("font", NOTO_SANS_JP)

	label.add_theme_font_size_override("font_size", font_size)


## Button にフォントとサイズを適用する
## @param button 対象の Button ノード
## @param font_size フォントサイズ
## @param use_bold 太字を使用するか（デフォルトは false）
func apply_to_button(button: Button, font_size: int, use_bold: bool = false) -> void:
	if not button:
		push_warning("FontTheme: Button が null です")
		return

	if use_bold:
		button.add_theme_font_override("font", create_bold_font())
	else:
		button.add_theme_font_override("font", NOTO_SANS_JP)

	button.add_theme_font_size_override("font_size", font_size)


## RichTextLabel にフォントとサイズを適用する
## @param rich_label 対象の RichTextLabel ノード
## @param font_size フォントサイズ
## @param use_bold 太字を使用するか（デフォルトは false）
func apply_to_rich_text_label(rich_label: RichTextLabel, font_size: int, use_bold: bool = false) -> void:
	if not rich_label:
		push_warning("FontTheme: RichTextLabel が null です")
		return

	if use_bold:
		rich_label.add_theme_font_override("normal_font", create_bold_font())
		rich_label.add_theme_font_override("bold_font", create_bold_font())
	else:
		rich_label.add_theme_font_override("normal_font", NOTO_SANS_JP)
		rich_label.add_theme_font_override("bold_font", create_bold_font())

	rich_label.add_theme_font_size_override("normal_font_size", font_size)
	rich_label.add_theme_font_size_override("bold_font_size", font_size)


## 任意の Control ノードにフォントとサイズを適用する汎用関数
## @param control 対象の Control ノード
## @param font_size フォントサイズ
## @param use_bold 太字を使用するか（デフォルトは false）
func apply_to_control(control: Control, font_size: int, use_bold: bool = false) -> void:
	if not control:
		push_warning("FontTheme: Control が null です")
		return

	if control is Label:
		apply_to_label(control as Label, font_size, use_bold)
	elif control is Button:
		apply_to_button(control as Button, font_size, use_bold)
	elif control is RichTextLabel:
		apply_to_rich_text_label(control as RichTextLabel, font_size, use_bold)
	else:
		# 汎用的な適用
		if use_bold:
			control.add_theme_font_override("font", create_bold_font())
		else:
			control.add_theme_font_override("font", NOTO_SANS_JP)

		control.add_theme_font_size_override("font_size", font_size)

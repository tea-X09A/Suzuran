extends PanelContainer

## 会話システムのメッセージウィンドウ
##
## 話者名、メッセージテキスト、顔画像を表示します。
## テキストアニメーション（1文字ずつ表示）とShiftキーによる高速スキップに対応します。
## sow.mdの要件に基づいて実装されています。

# ======================== シグナル定義 ========================

## テキスト表示が完了した時に発信
signal message_completed()

# ======================== フォントサイズ設定 ========================

## 話者名のフォントサイズ
@export var speaker_name_font_size: int = 32

## 会話テキストのフォントサイズ
@export var dialogue_text_font_size: int = 32

# ======================== ノード参照キャッシュ ========================

@onready var speaker_name_label: Label = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/SpeakerName
@onready var dialogue_text: RichTextLabel = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/DialogueText
@onready var face_image: TextureRect = $MarginContainer/VBoxContainer/SpeakerRow/FaceImage

# ======================== 状態管理変数 ========================

## 現在表示中のテキスト
var current_text: String = ""

## テキストアニメーションのタイマー
var text_timer: float = 0.0

## 1文字あたりの表示時間
var char_display_time: float = 0.05

## 現在表示されている文字数
var visible_characters: int = 0

## テキスト表示が完了したかどうか
var is_text_complete: bool = false

## テキストアニメーション中かどうか
var is_animating: bool = false

## 高速スキップ中かどうか
var is_fast_skipping: bool = false

# ======================== 初期化処理 ========================

func _ready() -> void:
	# フォントサイズを動的に設定
	speaker_name_label.add_theme_font_size_override("font_size", speaker_name_font_size)
	dialogue_text.add_theme_font_size_override("normal_font_size", dialogue_text_font_size)

	# 初期状態では非表示
	visible = false

	# RichTextLabelの初期設定
	dialogue_text.visible_characters = 0

# ======================== フレーム更新処理 ========================

func _process(delta: float) -> void:
	# テキストアニメーション中の処理
	if is_animating:
		_update_text_animation(delta)

	# Shiftキーで高速スキップ
	if Input.is_key_pressed(KEY_SHIFT):
		if not is_fast_skipping:
			is_fast_skipping = true
			char_display_time = 0.01  # 高速表示（通常の5倍速）
	else:
		if is_fast_skipping:
			is_fast_skipping = false

# ======================== 公開API ========================

## メッセージを表示する
##
## @param speaker_name String 話者名
## @param message_text String メッセージテキスト
## @param face_path String 顔画像のパス（空文字列の場合は非表示）
## @param text_speed float テキスト表示速度（1文字あたりの秒数）
func show_message(speaker_name: String, message_text: String, face_path: String, text_speed: float) -> void:
	# 表示速度を設定
	char_display_time = text_speed

	# 話者名を設定
	if speaker_name.is_empty():
		speaker_name_label.text = ""
		speaker_name_label.visible = false
	else:
		speaker_name_label.text = speaker_name
		speaker_name_label.visible = true

	# メッセージテキストを設定
	current_text = message_text
	dialogue_text.text = current_text
	dialogue_text.visible_characters = 0

	# 顔画像を設定
	_set_face_image(face_path)

	# アニメーション開始
	visible_characters = 0
	is_text_complete = false
	is_animating = true
	text_timer = 0.0

	# ウィンドウを表示
	visible = true

## 1文字ずつ表示をスキップして全文を即座に表示
func skip_typewriter() -> void:
	if is_animating:
		# 全文を即座に表示
		dialogue_text.visible_characters = -1
		visible_characters = current_text.length()
		is_animating = false
		is_text_complete = true
		message_completed.emit()

## テキスト表示が完了したかどうかを確認
##
## @return bool 完了していればtrue
func get_is_text_complete() -> bool:
	return is_text_complete

## ウィンドウを非表示にする
func hide_box() -> void:
	visible = false
	is_animating = false
	is_text_complete = false

# ======================== 内部処理 ========================

## テキストアニメーションを更新
func _update_text_animation(delta: float) -> void:
	text_timer += delta

	# 1文字表示するタイミングになったか確認
	if text_timer >= char_display_time:
		text_timer = 0.0

		# 次の文字を表示
		visible_characters += 1
		dialogue_text.visible_characters = visible_characters

		# 全文表示が完了したか確認
		if visible_characters >= current_text.length():
			is_animating = false
			is_text_complete = true
			message_completed.emit()

## 顔画像を設定
func _set_face_image(face_path: String) -> void:
	if face_path.is_empty():
		# 顔画像を非表示
		face_image.visible = false
		face_image.texture = null
	else:
		# 顔画像を読み込んで表示
		var texture: Texture2D = load(face_path)
		if texture:
			face_image.texture = texture
			face_image.visible = true
		else:
			push_warning("DialogueBox: Failed to load face image: " + face_path)
			face_image.visible = false
			face_image.texture = null

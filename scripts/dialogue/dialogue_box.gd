extends PanelContainer

## 会話システムのメッセージウィンドウ
##
## 話者名、メッセージテキストを表示します。
## テキストアニメーション（1文字ずつ表示）、決定ボタン長押しによる高速表示、
## Shiftキー/R1ボタンによる自動スキップに対応します。
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

## 話者名の影用Label
@onready var speaker_shadow_label: Label = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/SpeakerNameContainer/SpeakerShadowLabel

## 話者名のメインテキスト用Label
@onready var speaker_text_label: Label = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/SpeakerNameContainer/SpeakerTextLabel

## 会話テキストの影用RichTextLabel
@onready var dialogue_shadow_text: RichTextLabel = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/DialogueTextContainer/DialogueShadowText

## 会話テキストのメインテキスト用RichTextLabel
@onready var dialogue_main_text: RichTextLabel = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/DialogueTextContainer/DialogueMainText

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

## 決定ボタン長押しによる高速表示中かどうか
var is_fast_displaying: bool = false

## fast_skipアクション（Shiftキー/R1ボタン）による自動スキップモード中かどうか
var is_auto_skip_mode: bool = false

## 通常のテキスト表示速度（初期値を保持）
var normal_display_time: float = 0.05

# ======================== 初期化処理 ========================

func _ready() -> void:
	# 話者名の影用Labelにフォントを適用（太字、暗めの色）
	FontTheme.apply_to_label(speaker_shadow_label, speaker_name_font_size, true, Color(0.0, 0.0, 0.0, 0.5))

	# 話者名のメインテキスト用Labelにフォントを適用（太字、黄色）
	FontTheme.apply_to_label(speaker_text_label, speaker_name_font_size, true, Color(1.0, 0.843137, 0.0, 1.0))

	# 会話テキストの影用RichTextLabelにフォントを適用（太字、暗めの色）
	FontTheme.apply_to_rich_text_label(dialogue_shadow_text, dialogue_text_font_size, true, Color(0.0, 0.0, 0.0, 0.5))

	# 会話テキストのメインテキスト用RichTextLabelにフォントを適用（太字、白色）
	FontTheme.apply_to_rich_text_label(dialogue_main_text, dialogue_text_font_size, true, Color(1.0, 1.0, 1.0, 1.0))

	# 初期状態では非表示
	visible = false

	# RichTextLabelの初期設定
	dialogue_shadow_text.visible_characters = 0
	dialogue_main_text.visible_characters = 0

# ======================== フレーム更新処理 ========================

func _process(delta: float) -> void:
	# テキストアニメーション中の処理
	if is_animating:
		_update_text_animation(delta)

	# 入力状態の更新（優先順位: fast_skip > 決定ボタン長押し > 通常速度）
	_update_input_state()

# ======================== 公開API ========================

## メッセージを表示する
##
## @param speaker_name String 話者名
## @param message_text String メッセージテキスト
## @param text_speed float テキスト表示速度（1文字あたりの秒数）
func show_message(speaker_name: String, message_text: String, text_speed: float) -> void:
	# 表示速度を設定
	normal_display_time = text_speed

	# 現在の入力状態に応じて速度を設定
	if is_auto_skip_mode:
		# 自動スキップモード中は30倍速を維持
		char_display_time = normal_display_time / 30.0
	elif is_fast_displaying:
		# 決定ボタン長押し中は高速表示を維持
		char_display_time = 0.01
	else:
		# それ以外は通常速度
		char_display_time = text_speed

	# 話者名を設定（影用とメインテキスト用の両方）
	if speaker_name.is_empty():
		# 話者名を透明化（スペースは確保したまま非表示）
		speaker_shadow_label.text = ""
		speaker_shadow_label.modulate = Color(1, 1, 1, 0)
		speaker_text_label.text = ""
		speaker_text_label.modulate = Color(1, 1, 1, 0)
	else:
		speaker_shadow_label.text = speaker_name
		speaker_shadow_label.modulate = Color(1, 1, 1, 1)
		speaker_text_label.text = speaker_name
		speaker_text_label.modulate = Color(1, 1, 1, 1)

	# メッセージテキストを設定（影用とメインテキスト用の両方）
	current_text = message_text
	dialogue_shadow_text.text = current_text
	dialogue_shadow_text.visible_characters = 0
	dialogue_main_text.text = current_text
	dialogue_main_text.visible_characters = 0

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
		# 全文を即座に表示（影用とメインテキスト用の両方）
		dialogue_shadow_text.visible_characters = -1
		dialogue_main_text.visible_characters = -1
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

## 入力状態を更新して表示速度を調整
func _update_input_state() -> void:
	var is_fast_skip_pressed: bool = Input.is_action_pressed("fast_skip")
	var is_accept_hold: bool = GameSettings.is_action_menu_accept_hold()

	# Shiftキー/R1ボタンで自動スキップモード（最優先、30倍速）
	if is_fast_skip_pressed:
		if not is_auto_skip_mode:
			is_auto_skip_mode = true
			is_fast_displaying = false
			char_display_time = normal_display_time / 30.0
		return

	# fast_skipが離されたら自動スキップモード解除
	if is_auto_skip_mode:
		is_auto_skip_mode = false
		# 決定ボタンが押されていなければ通常速度に戻す
		if not is_accept_hold:
			char_display_time = normal_display_time

	# 決定ボタン長押しで高速表示（fast_skipより低優先度）
	if is_accept_hold:
		if not is_fast_displaying:
			is_fast_displaying = true
			char_display_time = 0.01
	elif is_fast_displaying:
		is_fast_displaying = false
		char_display_time = normal_display_time

## テキストアニメーションを更新
func _update_text_animation(delta: float) -> void:
	text_timer += delta

	# 1文字表示するタイミングになったか確認
	if text_timer >= char_display_time:
		text_timer = 0.0

		# 次の文字を表示（影用とメインテキスト用の両方）
		visible_characters += 1
		dialogue_shadow_text.visible_characters = visible_characters
		dialogue_main_text.visible_characters = visible_characters

		# 全文表示が完了したか確認
		if visible_characters >= current_text.length():
			is_animating = false
			is_text_complete = true
			message_completed.emit()

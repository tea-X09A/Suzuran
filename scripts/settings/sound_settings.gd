## 音量設定メニュー
## BGM、SE、VOICEの音量設定を提供
class_name SoundSettingsMenu
extends BaseSettingsMenu

# ======================== 変数定義 ========================

## BGM音量管理
var bgm_left_arrow: Label = null
var bgm_right_arrow: Label = null
var bgm_button: Button = null

## SE音量管理
var se_left_arrow: Label = null
var se_right_arrow: Label = null
var se_button: Button = null

## VOICE音量管理
var voice_left_arrow: Label = null
var voice_right_arrow: Label = null
var voice_button: Button = null

## セクションラベルの参照
var bgm_section_label: Label = null
var se_section_label: Label = null
var voice_section_label: Label = null

# ======================== 初期化処理 ========================

func _init(manager_ref: WeakRef) -> void:
	super._init(manager_ref)
	use_2d_navigation = true

# ======================== メニュー構築処理 ========================

## 音量設定メニューを構築
func build_menu(parent_container: Control) -> void:
	# navigation_rowsを初期化（再構築時の重複を防ぐ）
	navigation_rows.clear()

	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# BGMセクション
	bgm_section_label = _create_section_label("BGM")

	# BGMセレクターを作成
	var bgm_selector: ArrowSelector = _create_arrow_selector(
		str(GameSettings.bgm_volume),
		func(): pass
	)
	bgm_button = bgm_selector.button
	bgm_left_arrow = bgm_selector.left_arrow
	bgm_right_arrow = bgm_selector.right_arrow
	var bgm_row_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(bgm_row_indices)

	# BGM矢印の表示を更新
	_update_volume_arrows(bgm_left_arrow, bgm_right_arrow, GameSettings.bgm_volume)

	# スペーサー（項目間）
	_create_spacer(10.0)

	# SEセクション
	se_section_label = _create_section_label("SE")

	# SEセレクターを作成
	var se_selector: ArrowSelector = _create_arrow_selector(
		str(GameSettings.se_volume),
		func(): pass
	)
	se_button = se_selector.button
	se_left_arrow = se_selector.left_arrow
	se_right_arrow = se_selector.right_arrow
	var se_row_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(se_row_indices)

	# SE矢印の表示を更新
	_update_volume_arrows(se_left_arrow, se_right_arrow, GameSettings.se_volume)

	# スペーサー（項目間）
	_create_spacer(10.0)

	# VOICEセクション
	voice_section_label = _create_section_label("VOICE")

	# VOICEセレクターを作成
	var voice_selector: ArrowSelector = _create_arrow_selector(
		str(GameSettings.voice_volume),
		func(): pass
	)
	voice_button = voice_selector.button
	voice_left_arrow = voice_selector.left_arrow
	voice_right_arrow = voice_selector.right_arrow
	var voice_row_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(voice_row_indices)

	# VOICE矢印の表示を更新
	_update_volume_arrows(voice_left_arrow, voice_right_arrow, GameSettings.voice_volume)

	# スペーサー（戻るボタン前）
	_create_spacer()

	# 戻るボタン
	_create_back_button()
	var back_button_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(back_button_indices)

	# 言語変更シグナルに接続
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	GameSettings.language_changed.connect(_on_language_changed)

# ======================== メニュー表示・非表示処理 ========================

## メニューを表示し、現在の設定に応じて選択状態を設定
func show_menu(initial_selection: int = 0, initial_row: int = 0, initial_column: int = 0) -> void:
	if menu_container:
		menu_container.visible = true

	# 音量ボタンのテキストと矢印を更新
	if bgm_button:
		bgm_button.text = str(GameSettings.bgm_volume)
		_update_volume_arrows(bgm_left_arrow, bgm_right_arrow, GameSettings.bgm_volume)

	if se_button:
		se_button.text = str(GameSettings.se_volume)
		_update_volume_arrows(se_left_arrow, se_right_arrow, GameSettings.se_volume)

	if voice_button:
		voice_button.text = str(GameSettings.voice_volume)
		_update_volume_arrows(voice_left_arrow, voice_right_arrow, GameSettings.voice_volume)

	# 選択位置を設定（MenuManagerから渡された値を使用）
	current_row = initial_row
	current_column = initial_column
	current_selection = initial_selection

	_update_2d_selection()

# ======================== UI要素作成メソッド ========================

## セクションラベルを作成
func _create_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(label, FontTheme.FONT_SIZE_LARGE, true)
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(label)
	return label

# ======================== 音量矢印の更新メソッド ========================

## 音量の矢印表示を更新
func _update_volume_arrows(left_arrow: Label, right_arrow: Label, volume: int) -> void:
	if not left_arrow or not right_arrow:
		return

	var can_go_left: bool = volume > 0
	var can_go_right: bool = volume < 10

	_update_arrow_visibility(left_arrow, right_arrow, can_go_left, can_go_right)

# ======================== 左右入力処理 ========================

## 左キー入力処理（基底クラスからオーバーライド）
func _handle_left_input() -> void:
	match current_row:
		0:  # BGM行
			_change_bgm_volume(-1)
		1:  # SE行
			_change_se_volume(-1)
		2:  # VOICE行
			_change_voice_volume(-1)

## 右キー入力処理（基底クラスからオーバーライド）
func _handle_right_input() -> void:
	match current_row:
		0:  # BGM行
			_change_bgm_volume(1)
		1:  # SE行
			_change_se_volume(1)
		2:  # VOICE行
			_change_voice_volume(1)

# ======================== 音量変更メソッド ========================

## BGM音量を変更
func _change_bgm_volume(direction: int) -> void:
	var new_volume: int = GameSettings.bgm_volume + direction

	# 範囲チェック（0~10）
	if new_volume < 0 or new_volume > 10:
		return

	# 音量を設定
	GameSettings.set_bgm_volume(new_volume)

	# ボタンのテキストを更新
	if bgm_button:
		bgm_button.text = str(new_volume)

	# 矢印の表示を更新
	_update_volume_arrows(bgm_left_arrow, bgm_right_arrow, new_volume)

## SE音量を変更
func _change_se_volume(direction: int) -> void:
	var new_volume: int = GameSettings.se_volume + direction

	# 範囲チェック（0~10）
	if new_volume < 0 or new_volume > 10:
		return

	# 音量を設定
	GameSettings.set_se_volume(new_volume)

	# ボタンのテキストを更新
	if se_button:
		se_button.text = str(new_volume)

	# 矢印の表示を更新
	_update_volume_arrows(se_left_arrow, se_right_arrow, new_volume)

## VOICE音量を変更
func _change_voice_volume(direction: int) -> void:
	var new_volume: int = GameSettings.voice_volume + direction

	# 範囲チェック（0~10）
	if new_volume < 0 or new_volume > 10:
		return

	# 音量を設定
	GameSettings.set_voice_volume(new_volume)

	# ボタンのテキストを更新
	if voice_button:
		voice_button.text = str(new_volume)

	# 矢印の表示を更新
	_update_volume_arrows(voice_left_arrow, voice_right_arrow, new_volume)

# ======================== コールバックメソッド ========================

## 言語が変更されたときに呼ばれるコールバック
func _on_language_changed(_new_language: String) -> void:
	_update_back_button_text()

# ======================== クリーンアップ処理 ========================

## クリーンアップ処理
func cleanup() -> void:
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)

	# ArrowSelectorコンポーネントの参照をクリア
	bgm_left_arrow = null
	bgm_right_arrow = null
	bgm_button = null
	se_left_arrow = null
	se_right_arrow = null
	se_button = null
	voice_left_arrow = null
	voice_right_arrow = null
	voice_button = null
	bgm_section_label = null
	se_section_label = null
	voice_section_label = null

	super.cleanup()

## 言語設定メニュー
## 日本語/英語の切り替え機能を提供
class_name LanguageSettingsMenu
extends BaseSettingsMenu

# ======================== 定数定義 ========================

## 言語リスト（日本語/英語）
const LANGUAGES: Array[Dictionary] = [
	{"id": GameSettings.Language.JAPANESE, "name": "日本語"},
	{"id": GameSettings.Language.ENGLISH, "name": "English"}
]

# ======================== 変数定義 ========================

## 言語管理
var current_language_index: int = 0
var language_button: Button = null

# ======================== 初期化処理 ========================

func _init(manager_ref: WeakRef) -> void:
	super._init(manager_ref)
	use_2d_navigation = true

# ======================== メニュー構築処理 ========================

## 言語設定メニューを構築
func build_menu(parent_container: Control) -> void:
	# navigation_rowsを初期化（再構築時の重複を防ぐ）
	navigation_rows.clear()

	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false  # 最初は非表示
	parent_container.add_child(menu_container)

	# 現在の言語からインデックスを初期化
	for i in range(LANGUAGES.size()):
		if LANGUAGES[i]["id"] == GameSettings.current_language:
			current_language_index = i
			break

	# 言語セレクターを作成
	var language_text: String = LANGUAGES[current_language_index]["name"]
	var language_selector: ArrowSelector = _create_arrow_selector(language_text, func(): pass)
	language_button = language_selector.button
	var language_row_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(language_row_indices)

	# スペーサー
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

## メニューを表示し、現在の言語に応じて選択状態を設定
func show_menu(initial_selection: int = 0, initial_row: int = 0, initial_column: int = 0) -> void:
	if menu_container:
		menu_container.visible = true

	# 現在の言語インデックスを更新
	for i in range(LANGUAGES.size()):
		if LANGUAGES[i]["id"] == GameSettings.current_language:
			current_language_index = i
			break

	# 言語ボタンのテキストを更新
	if language_button:
		language_button.text = LANGUAGES[current_language_index]["name"]

	# 選択位置を設定（MenuManagerから渡された値を使用）
	current_row = initial_row
	current_column = initial_column
	current_selection = initial_selection

	_update_2d_selection()

# ======================== 言語変更処理 ========================

## 言語を変更
func _change_language(direction: int) -> void:
	# 新しいインデックスを計算（循環）
	var new_index: int = current_language_index + direction

	# 循環処理
	if new_index < 0:
		new_index = LANGUAGES.size() - 1
	elif new_index >= LANGUAGES.size():
		new_index = 0

	# インデックスを更新
	current_language_index = new_index

	# 言語を適用
	GameSettings.set_language(LANGUAGES[current_language_index]["id"])

	# ボタンのテキストを更新
	if language_button:
		language_button.text = LANGUAGES[current_language_index]["name"]

# ======================== 左右入力処理（派生クラスでオーバーライド） ========================

## 左キー入力処理（基底クラスからオーバーライド）
func _handle_left_input() -> void:
	# 言語行にいる場合は言語を変更
	if current_row == 0:
		_change_language(-1)

## 右キー入力処理（基底クラスからオーバーライド）
func _handle_right_input() -> void:
	# 言語行にいる場合は言語を変更
	if current_row == 0:
		_change_language(1)

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
	language_button = null

	super.cleanup()

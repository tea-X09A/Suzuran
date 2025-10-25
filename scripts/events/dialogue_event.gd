class_name DialogueEvent
extends BaseEvent

## 会話イベント実装クラス
##
## DialogueDataを受け取って会話を実行します。
## プレイヤー状態に基づくメッセージフィルタリング、選択肢分岐、入力待ちなどをサポートします。
## sow.mdの要件に基づいて実装されています。

# ======================== 状態管理変数 ========================

## 会話データ
var dialogue_data: DialogueData

## DialogueSystemノードへの参照
var dialogue_system: Node

## DialogueBoxへの参照
var dialogue_box: Node

## DialogueChoicesContainerへの参照
var choices_container: Control

## 現在のメッセージインデックス
var current_message_index: String = "0"

## フィルタリング済みメッセージ配列
var filtered_messages: Array[DialogueMessage] = []

## プレイヤーの現在の状態（"normal" または "expansion"）
var player_state: String = "normal"

## 次へ進む入力待ち中かどうか
var waiting_for_input: bool = false

## 選択肢表示中かどうか
var showing_choices: bool = false

## 選択肢ボタンの配列
var choice_buttons: Array[Node] = []

## 現在選択中の選択肢インデックス
var selected_choice_index: int = 0

## プレイヤーへの参照（弱参照）
var player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## コンストラクタ
##
## @param data DialogueData 会話データ
func _init(data: DialogueData) -> void:
	dialogue_data = data
	is_skippable = false  # 会話イベントはスキップ不可

# ======================== BaseEvent実装 ========================

## イベントを実行する
func execute() -> void:
	status = ExecutionStatus.RUNNING

	# プレイヤーを取得
	_find_player()

	# プレイヤーの現在の状態を取得
	var player: Node = player_ref.get_ref() if player_ref else null
	if player and player.has_method("get_current_state"):
		player_state = player.get_current_state()
	else:
		player_state = "normal"

	# メッセージをプレイヤー状態でフィルタリング
	filtered_messages = dialogue_data.get_filtered_messages(player_state)

	if filtered_messages.is_empty():
		push_warning("DialogueEvent: No messages found for player state: " + player_state)
		_complete_event()
		return

	# DialogueSystemシーンをインスタンス化
	_setup_dialogue_system()

	# 最初のメッセージを表示
	current_message_index = "0"
	_show_next_message()

## スキップ可否判定（常にfalse）
func can_skip() -> bool:
	return false

# ======================== 内部処理 ========================

## プレイヤーを検索して弱参照を保持
func _find_player() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		var player_nodes: Array[Node] = tree.get_nodes_in_group("player")
		if not player_nodes.is_empty():
			player_ref = weakref(player_nodes[0])

## DialogueSystemを設定
func _setup_dialogue_system() -> void:
	# DialogueSystemシーンを読み込み
	var dialogue_system_scene: PackedScene = preload("res://scenes/dialogue/dialogue_system.tscn")
	dialogue_system = dialogue_system_scene.instantiate()

	# シーンツリーに追加
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(dialogue_system)

	# DialogueBoxとChoicesContainerへの参照を取得
	dialogue_box = dialogue_system.get_node("DialogueBoxContainer/DialogueBox")
	choices_container = dialogue_system.get_node("DialogueChoicesContainer/VBoxContainer")

	# DialogueBoxのシグナルに接続
	if dialogue_box and dialogue_box.has_signal("message_completed"):
		dialogue_box.message_completed.connect(_on_message_completed)

## 次のメッセージを表示
func _show_next_message() -> void:
	# 現在のインデックスに対応するメッセージを取得
	var message: DialogueMessage = dialogue_data.get_message(current_message_index)

	if not message:
		# メッセージが見つからない場合はイベント完了
		_complete_event()
		return

	# 話者情報を取得
	var speaker_name: String = ""

	# 現在の言語設定を取得（最初に1回のみ）
	var language: String = _get_current_language()

	if not message.speaker_id.is_empty():
		var character: DialogueCharacterInfo = dialogue_data.get_character_info(message.speaker_id)
		if character:
			# 話者名を取得
			speaker_name = character.speaker_name.get(language, "")

	# メッセージテキストを取得
	var message_text: String = message.text.get(language, "")

	# DialogueBoxにメッセージを表示
	if dialogue_box and dialogue_box.has_method("show_message"):
		dialogue_box.show_message(speaker_name, message_text, dialogue_data.text_speed)

	# 選択肢があるか確認
	if message.choices.size() > 0:
		showing_choices = true
		waiting_for_input = false
	else:
		showing_choices = false
		waiting_for_input = true

## テキスト表示完了時の処理
func _on_message_completed() -> void:
	if showing_choices:
		# 選択肢を表示
		var message: DialogueMessage = dialogue_data.get_message(current_message_index)
		if message:
			_show_choices(message.choices)
	else:
		# 入力待ち状態に移行
		waiting_for_input = true
		_start_next_input_monitoring()

## 選択肢を表示
func _show_choices(choices: Array[DialogueChoiceData]) -> void:
	# 既存の選択肢をクリア
	_clear_choices()

	# 選択肢ボタンを作成（最大2つ）
	var choice_scene: PackedScene = preload("res://scenes/dialogue/dialogue_choice.tscn")
	var language: String = _get_current_language()

	for i in range(min(choices.size(), 2)):
		var choice: DialogueChoiceData = choices[i]
		var choice_button: Node = choice_scene.instantiate()

		# 選択肢テキストを設定
		var choice_text: String = choice.text.get(language, "")
		if choice_button.has_method("setup"):
			choice_button.setup(choice_text, i)

		# シグナルに接続
		if choice_button.has_signal("choice_selected"):
			choice_button.choice_selected.connect(_on_choice_selected.bind(choice.next_index))

		# コンテナに追加
		choices_container.add_child(choice_button)
		choice_buttons.append(choice_button)

	# 最初の選択肢を選択状態にする
	selected_choice_index = 0
	_update_choice_selection()

	# 入力監視を開始
	_start_choice_input_monitoring()

## 選択肢をクリア
func _clear_choices() -> void:
	for button in choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	choice_buttons.clear()

## 選択肢の選択状態を更新
func _update_choice_selection() -> void:
	for i in range(choice_buttons.size()):
		var button: Node = choice_buttons[i]
		if button.has_method("set_selected"):
			button.set_selected(i == selected_choice_index)

## 選択肢入力監視を開始
func _start_choice_input_monitoring() -> void:
	# SceneTreeのprocess_frameシグナルを使って入力を監視
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		if not tree.process_frame.is_connected(_process_choice_input):
			tree.process_frame.connect(_process_choice_input)

## 選択肢入力を停止
func _stop_choice_input_monitoring() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		if tree.process_frame.is_connected(_process_choice_input):
			tree.process_frame.disconnect(_process_choice_input)

## 選択肢の入力処理
func _process_choice_input() -> void:
	if not showing_choices or choice_buttons.is_empty():
		return

	# ↑↓ / WSキーで選択移動
	if Input.is_action_just_pressed("ui_menu_up"):
		selected_choice_index = max(0, selected_choice_index - 1)
		_update_choice_selection()
	elif Input.is_action_just_pressed("ui_menu_down"):
		selected_choice_index = min(choice_buttons.size() - 1, selected_choice_index + 1)
		_update_choice_selection()

	# 決定ボタンで選択（キーボード: Z/Enter、ゲームパッド: 言語により⚪︎/×が切替）
	if GameSettings.is_action_menu_accept_pressed():
		if selected_choice_index < choice_buttons.size():
			var button: Node = choice_buttons[selected_choice_index]
			if button.has_method("_on_button_pressed"):
				button._on_button_pressed()

## 次へ進む入力監視を開始
func _start_next_input_monitoring() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		if not tree.process_frame.is_connected(_process_next_input):
			tree.process_frame.connect(_process_next_input)

## 次へ進む入力を停止
func _stop_next_input_monitoring() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		if tree.process_frame.is_connected(_process_next_input):
			tree.process_frame.disconnect(_process_next_input)

## 次へ進む入力処理
func _process_next_input() -> void:
	if not waiting_for_input:
		return

	# Shiftキー/R1ボタン（自動スキップモード）で次へ
	# 選択肢がある場合は自動スキップしない
	if Input.is_action_pressed("fast_skip"):
		if not showing_choices:
			# テキスト表示が完了しているか確認
			if dialogue_box and dialogue_box.has_method("get_is_text_complete") and dialogue_box.get_is_text_complete():
				_advance_to_next_message()
		return  # fast_skip処理後は他の入力チェックをスキップ

	# 決定ボタンで次へ（キーボード: Z/Enter、ゲームパッド: 言語により⚪︎/×が切替）
	if GameSettings.is_action_menu_accept_pressed():
		# テキスト表示が完了しているか確認
		if dialogue_box and dialogue_box.has_method("get_is_text_complete") and dialogue_box.get_is_text_complete():
			_advance_to_next_message()
		elif dialogue_box and dialogue_box.has_method("skip_typewriter"):
			# テキストアニメーション中の場合はスキップ
			dialogue_box.skip_typewriter()

## 次のメッセージに進む
func _advance_to_next_message() -> void:
	waiting_for_input = false
	_stop_next_input_monitoring()

	# インデックスをインクリメント
	var next_index: int = int(current_message_index) + 1
	current_message_index = str(next_index)

	# 次のメッセージを表示
	_show_next_message()

## 選択肢が選択された時の処理
func _on_choice_selected(_choice_index: int, next_index: String) -> void:
	showing_choices = false
	_stop_choice_input_monitoring()

	# 選択肢をクリア
	_clear_choices()

	# 次のメッセージインデックスを設定
	current_message_index = next_index

	# 次のメッセージを表示
	_show_next_message()

## イベントを完了
func _complete_event() -> void:
	# 入力監視を停止
	_stop_choice_input_monitoring()
	_stop_next_input_monitoring()

	# DialogueSystemを削除
	if is_instance_valid(dialogue_system):
		dialogue_system.queue_free()
		dialogue_system = null

	# 選択肢をクリア
	_clear_choices()

	# ステータスを完了に設定
	status = ExecutionStatus.COMPLETED
	event_completed.emit()

## 現在の言語設定を取得
func _get_current_language() -> String:
	# GameSettingsから言語を取得
	if GameSettings:
		var language_name: String = GameSettings.get_language_name()
		# "Japanese" -> "ja", "English" -> "en"
		if language_name == "Japanese":
			return "ja"
		elif language_name == "English":
			return "en"

	# デフォルトは日本語
	return "ja"

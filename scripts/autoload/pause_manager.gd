## ゲームの一時停止を管理するマネージャー（AutoLoad）
## メニュー表示はMenuManagerが担当
extends Node

# ======================== シグナル ========================
## ポーズ状態を管理するシグナル
signal pause_state_changed(is_paused: bool)

# ======================== 変数 ========================
## ポーズ状態
var is_paused: bool = false

## アプリケーションがフォーカスを失った際に自動一時停止するか
var auto_pause_on_focus_loss: bool = true

## フォーカス喪失により自動的に一時停止したかどうか
var auto_paused_by_focus_loss: bool = false

# ======================== 初期化処理 ========================
func _ready() -> void:
	# プロセスモードを常に実行に設定（ポーズ中でも動作）
	process_mode = Node.PROCESS_MODE_ALWAYS

	# WindowFocusManagerのシグナルに接続
	if WindowFocusManager:
		WindowFocusManager.focus_changed.connect(_on_focus_changed)

# ======================== 内部ヘルパーメソッド ========================

## デバッグメニューが開いているかチェック
func _is_debug_menu_open() -> bool:
	return DebugManager and DebugManager.is_open

## ポーズメニューが開いているかチェック
func _is_pause_menu_open() -> bool:
	return MenuManager and MenuManager.pause_menu and MenuManager.pause_menu.visible

# ======================== フォーカス変更処理 ========================

## ウィンドウのフォーカス状態が変化した時に呼ばれる
func _on_focus_changed(has_focus: bool) -> void:
	# デバッグメニューが開いている場合は自動一時停止/再開を行わない
	if _is_debug_menu_open():
		return

	if has_focus:
		# ポーズメニューが開いている場合は自動再開しない
		if _is_pause_menu_open():
			return
		# フォーカス喪失により自動一時停止した場合のみ、自動的に再開
		if auto_pause_on_focus_loss and is_paused and auto_paused_by_focus_loss:
			resume_game()
			auto_paused_by_focus_loss = false
	else:
		# アプリケーションがフォーカスを失った場合、自動的に一時停止
		if auto_pause_on_focus_loss and not is_paused:
			pause_game()
			auto_paused_by_focus_loss = true

# ======================== 公開API ========================
## ポーズ状態を切り替え
func toggle_pause() -> void:
	is_paused = not is_paused

	if is_paused:
		# ゲームを一時停止
		get_tree().paused = true
	else:
		# ゲームを再開
		get_tree().paused = false
		# 手動で再開した場合、自動一時停止フラグをクリア
		auto_paused_by_focus_loss = false

	# シグナルを発信してMenuManagerに通知
	pause_state_changed.emit(is_paused)

## ゲームを再開
func resume_game() -> void:
	if is_paused:
		toggle_pause()

## ゲームを一時停止
func pause_game() -> void:
	if not is_paused:
		toggle_pause()

## フォーカス喪失時の自動一時停止を有効/無効にする
func set_auto_pause_on_focus_loss(enabled: bool) -> void:
	auto_pause_on_focus_loss = enabled

# ======================== クリーンアップ ========================
func _exit_tree() -> void:
	## シグナル接続を明示的に切断してメモリリークを防止
	if WindowFocusManager and WindowFocusManager.focus_changed.is_connected(_on_focus_changed):
		WindowFocusManager.focus_changed.disconnect(_on_focus_changed)

extends Node

## ゲームの一時停止を管理するマネージャー
## メニュー表示はMenuManagerが担当

# ポーズ状態を管理するシグナル
signal pause_state_changed(is_paused: bool)

# ポーズ状態
var is_paused: bool = false

func _ready() -> void:
	# プロセスモードを常に実行に設定（ポーズ中でも動作）
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle_pause() -> void:
	"""ポーズ状態を切り替え"""
	is_paused = not is_paused

	if is_paused:
		# ゲームを一時停止
		get_tree().paused = true
	else:
		# ゲームを再開
		get_tree().paused = false

	# シグナルを発信してMenuManagerに通知
	pause_state_changed.emit(is_paused)

func resume_game() -> void:
	"""ゲームを再開"""
	if is_paused:
		toggle_pause()

func pause_game() -> void:
	"""ゲームを一時停止"""
	if not is_paused:
		toggle_pause()

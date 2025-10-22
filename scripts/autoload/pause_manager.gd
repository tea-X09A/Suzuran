extends Node

## ゲームの一時停止を管理するマネージャー
## メニュー表示はMenuManagerが担当

# ======================== シグナル ========================
## ポーズ状態を管理するシグナル
signal pause_state_changed(is_paused: bool)

# ======================== 変数 ========================
## ポーズ状態
var is_paused: bool = false

# ======================== 初期化処理 ========================
func _ready() -> void:
	# プロセスモードを常に実行に設定（ポーズ中でも動作）
	process_mode = Node.PROCESS_MODE_ALWAYS

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

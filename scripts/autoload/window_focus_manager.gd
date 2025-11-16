## ウィンドウのフォーカス状態を管理するマネージャー（AutoLoad）
## アプリケーションがアクティブかどうかを一元管理
extends Node

# ======================== シグナル ========================
## フォーカス状態が変化した時に発信
signal focus_changed(has_focus: bool)

# ======================== 変数 ========================
## アプリケーションがフォーカスを持っているか
var has_focus: bool = true

# ======================== 初期化処理 ========================
func _ready() -> void:
	# プロセスモードを常に実行に設定
	process_mode = Node.PROCESS_MODE_ALWAYS

# ======================== 通知処理 ========================
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			has_focus = false
			focus_changed.emit(false)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			has_focus = true
			focus_changed.emit(true)

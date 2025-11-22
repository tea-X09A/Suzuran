## PlayerEventController
## プレイヤーのイベント制御ロジックを担当するコンポーネント
class_name PlayerEventController
extends RefCounted

# ======================== 変数定義 ========================

## イベント中の入力無効化フラグ
var disable_input: bool = false

## プレイヤーへの弱参照（メモリリーク防止）
var _player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## EventControllerの初期化
## @param player プレイヤーインスタンス
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)
	_connect_event_signals()

## EventManagerのシグナルに接続
func _connect_event_signals() -> void:
	if EventManager:
		EventManager.event_started.connect(_on_event_started)
		EventManager.event_ended.connect(_on_event_ended)

# ======================== イベント制御 ========================

## イベント用の準備処理（EventManagerとevent_areaから呼び出される）
##
## プレイヤーを適切にidle状態に遷移させ、event_preparation_completeシグナルを発信します。
## - 入力を無効化
## - 水平・垂直速度を完全にゼロ化
## - 空中にいる場合: fall状態に遷移 → 着地を待つ → idle状態に遷移
## - 地上にいる場合: 即座にidle状態に遷移
func prepare_for_event() -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# 入力を無効化
	disable_input = true

	# 速度を完全にゼロ化（水平・垂直両方）
	player.velocity = Vector2.ZERO

	# 現在の状態に応じて処理を分岐
	if player.is_grounded:
		# 地上にいる場合は即座にIDLE状態に遷移
		player.change_state("IDLE")
	else:
		# 空中にいる場合はFALL状態に遷移（重力適用と着地判定のため）
		player.change_state("FALL")
		# 着地を待つ（is_on_floor()がtrueになるまで）
		while not player.is_on_floor():
			await player.get_tree().physics_frame
		# 着地したらIDLE状態に遷移
		player.change_state("IDLE")

	# 状態遷移完了を待ってから完了シグナルを発信
	await player.get_tree().process_frame
	player.event_preparation_complete.emit()

## イベント終了時の処理（EventManagerから呼び出される）
##
## 入力を再有効化します。
func end_event() -> void:
	disable_input = false

# ======================== イベントシグナルハンドラ ========================

## イベント開始時のコールバック（dialogue開始時）
func _on_event_started() -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# UIComponentにStatusGaugeの表示更新を依頼
	if player.ui_component:
		player.ui_component.update_status_gauge_visibility()

## イベント終了時のコールバック（dialogue終了時）
func _on_event_ended() -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# UIComponentにStatusGaugeの表示更新を依頼
	if player.ui_component:
		player.ui_component.update_status_gauge_visibility()

# ======================== クリーンアップ ========================

## クリーンアップ処理
func cleanup() -> void:
	# EventManagerのシグナル切断（メモリリーク防止）
	if EventManager:
		if EventManager.event_started.is_connected(_on_event_started):
			EventManager.event_started.disconnect(_on_event_started)
		if EventManager.event_ended.is_connected(_on_event_ended):
			EventManager.event_ended.disconnect(_on_event_ended)

	# 状態をリセット
	disable_input = false
	_player_ref = null

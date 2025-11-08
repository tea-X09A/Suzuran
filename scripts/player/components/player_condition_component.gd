## プレイヤーのCondition（変身状態）管理コンポーネント
## デバッグメニューとゲーム内イベントの両方からConditionを切り替え可能にする汎用コンポーネント
class_name PlayerConditionComponent
extends RefCounted

# ======================== 変数 ========================

## プレイヤーへの弱参照（循環参照を防ぐため）
var player_ref: WeakRef = null

# ======================== 初期化・クリーンアップ ========================

## コンポーネントの初期化
## @param target_player 管理対象のPlayerインスタンス
func initialize(target_player: Player) -> void:
	player_ref = weakref(target_player)

	# DebugManagerのシグナルに接続
	if DebugManager:
		DebugManager.debug_value_changed.connect(_on_debug_value_changed)

## コンポーネントのクリーンアップ
func cleanup() -> void:
	# DebugManagerのシグナルを切断
	if DebugManager and DebugManager.debug_value_changed.is_connected(_on_debug_value_changed):
		DebugManager.debug_value_changed.disconnect(_on_debug_value_changed)

	# 参照をクリア
	player_ref = null

# ======================== Condition管理メソッド ========================

## プレイヤーインスタンスを取得（弱参照から実体を取得）
func _get_player() -> Player:
	if player_ref:
		return player_ref.get_ref() as Player
	return null

## Conditionを変更する（汎用メソッド）
## デバッグメニュー、ゲーム内イベント、その他あらゆる場所から呼び出し可能
## @param new_condition 新しいCondition
func change_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	var player: Player = _get_player()
	if not player:
		push_warning("PlayerConditionComponent: プレイヤーへの参照が無効です")
		return

	# 現在のConditionと同じ場合は何もしない
	if player.condition == new_condition:
		return

	var old_condition: Player.PLAYER_CONDITION = player.condition

	# Conditionを変更
	player.condition = new_condition

	# ログ出力（デバッグ用）
	print("[PlayerConditionComponent] Condition changed: %s -> %s" % [
		_condition_to_string(old_condition),
		_condition_to_string(new_condition)
	])

## NORMALに切り替える（便利メソッド）
func set_normal() -> void:
	change_condition(Player.PLAYER_CONDITION.NORMAL)

## EXPANSIONに切り替える（便利メソッド）
func set_expansion() -> void:
	change_condition(Player.PLAYER_CONDITION.EXPANSION)

## Conditionをトグルする（NORMAL ⇔ EXPANSION）
func toggle_condition() -> void:
	var player: Player = _get_player()
	if not player:
		push_warning("PlayerConditionComponent: プレイヤーへの参照が無効です")
		return

	match player.condition:
		Player.PLAYER_CONDITION.NORMAL:
			change_condition(Player.PLAYER_CONDITION.EXPANSION)
		Player.PLAYER_CONDITION.EXPANSION:
			change_condition(Player.PLAYER_CONDITION.NORMAL)

## 現在のConditionを取得
func get_current_condition() -> Player.PLAYER_CONDITION:
	var player: Player = _get_player()
	if player:
		return player.condition
	return Player.PLAYER_CONDITION.NORMAL

# ======================== デバッグ機能連携 ========================

## デバッグマネージャーからの値変更通知を処理
func _on_debug_value_changed(key: String, value: Variant) -> void:
	if key == "condition":
		# デバッグメニューからのCondition変更
		var new_condition: Player.PLAYER_CONDITION = value as Player.PLAYER_CONDITION
		change_condition(new_condition)

# ======================== ユーティリティ ========================

## Conditionを文字列に変換（デバッグ表示用）
func _condition_to_string(cond: Player.PLAYER_CONDITION) -> String:
	match cond:
		Player.PLAYER_CONDITION.NORMAL:
			return "NORMAL"
		Player.PLAYER_CONDITION.EXPANSION:
			return "EXPANSION"
		_:
			return "UNKNOWN"

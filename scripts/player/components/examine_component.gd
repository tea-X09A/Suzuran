## Examine機能コンポーネント
## Examineインジケーターの管理とExamineエリアの状態管理を担当
class_name ExamineComponent
extends RefCounted

# ======================== シグナル ========================

## Examine可能エリアに入ったときに発火
signal examine_available()
## Examineアクションが実行されたときに発火
signal examine_activated()

# ======================== 変数 ========================

## Examineインジケーター（ActionIndicator）
var examine_indicator: ActionIndicator = null
## Examineエリア内にいるかどうかのフラグ
var in_examine_area: bool = false

## Playerへの弱参照（循環参照防止）
var _player_ref: WeakRef = null

# ======================== 初期化・クリーンアップ ========================

## コンポーネントの初期化
## @param player CharacterBody2D プレイヤーインスタンス
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)
	_initialize_examine_indicator(player)

## ActionIndicatorの初期化
## @param player CharacterBody2D プレイヤーインスタンス（直接渡す）
func _initialize_examine_indicator(player: CharacterBody2D) -> void:
	if not player:
		return

	# ActionIndicatorインスタンスを作成
	examine_indicator = ActionIndicator.new()
	# Playerの子として追加
	player.add_child(examine_indicator)
	# 初期位置を設定
	var sprite_2d: Sprite2D = player.get_sprite_2d()
	if sprite_2d:
		examine_indicator.update_position(sprite_2d)

## クリーンアップ処理（メモリリーク防止）
func cleanup() -> void:
	# Examineインジケーターの解放
	if examine_indicator:
		examine_indicator.queue_free()
		examine_indicator = null

	# 状態をリセット
	in_examine_area = false
	_player_ref = null

# ======================== Examineインジケーター制御 ========================

## Examineインジケーターを表示
func show_examine_indicator() -> void:
	if examine_indicator:
		examine_indicator.show_indicator()
		examine_available.emit()

## Examineインジケーターを非表示
func hide_examine_indicator() -> void:
	if examine_indicator:
		examine_indicator.hide_indicator()

# ======================== Examineエリア管理 ========================

## Examineエリアに入ったときの処理
func enter_examine_area() -> void:
	in_examine_area = true
	show_examine_indicator()

## Examineエリアから出たときの処理
func exit_examine_area() -> void:
	in_examine_area = false
	hide_examine_indicator()

## Examineエリア内かどうかを確認
## @return bool Examineエリア内にいる場合はtrue
func is_in_examine_area() -> bool:
	return in_examine_area

# ======================== Examineアクション ========================

## Examine実行処理
func execute_examine() -> void:
	if in_examine_area:
		examine_activated.emit()

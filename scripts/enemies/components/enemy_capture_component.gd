## キャプチャ管理コンポーネント
## プレイヤーのキャプチャロジック、アニメーション選択、キャプチャ状態管理を提供
class_name EnemyCaptureComponent
extends RefCounted

# ======================== シグナル定義 ========================

## キャプチャを試行した時に発信
signal capture_attempted(player: Node2D)
## キャプチャ状態に入った時に発信
signal capture_state_entered()
## キャプチャ状態から出た時に発信
signal capture_state_exited()

# ======================== パラメータ ========================

## 敵のID（アニメーション名に使用）
var enemy_id: String = ""

# ======================== 内部状態 ========================

## CAPTURE状態中かどうかのフラグ
var is_in_capture_mode: bool = false
## キャプチャ時の状態（アニメーション名に使用、初期値をnormalとする）
var capture_condition: String = "normal"

# ======================== ノード参照（WeakRefで保持） ========================

## 敵への弱参照（メモリリーク防止）
var enemy_ref: WeakRef = null

# ======================== 初期化 ========================

## コンストラクタ
func _init(enemy: Enemy) -> void:
	# 敵への弱参照を保存（循環参照を回避）
	enemy_ref = weakref(enemy)

## キャプチャシステムの初期化（Enemyの_ready()から呼び出す）
## @param initial_enemy_id: 敵のID
func initialize(initial_enemy_id: String) -> void:
	enemy_id = initial_enemy_id

# ======================== 公開メソッド ========================

## キャプチャモード中かどうかを取得
func is_capturing() -> bool:
	return is_in_capture_mode

## キャプチャ処理を試行
## @param player_node: プレイヤーノード
## @param detection_component: 検知コンポーネント
## @return: キャプチャ処理を実行した場合はtrue
func try_capture_player(player_node: Node2D, detection_component: EnemyDetectionComponent) -> bool:
	# プレイヤーを追跡していない場合は、追跡を開始してCHASE状態に遷移
	if not detection_component.is_player_tracked():
		detection_component.start_chasing_player(player_node)

	# クールダウン中は処理しない
	if detection_component.is_capture_on_cooldown():
		return false

	# 実際にキャプチャを適用した場合のみタイマーを更新
	if apply_capture_to_player(player_node):
		detection_component.record_capture()
		capture_attempted.emit(player_node)
		return true

	return false

## プレイヤーにキャプチャを適用
## @param body: プレイヤーノード
## @return: キャプチャ処理を実行した場合はtrue
func apply_capture_to_player(body: Node2D) -> bool:
	# プレイヤーが無敵状態の場合はキャプチャしない
	if body.has_method("is_invincible") and body.is_invincible():
		return false

	# 敵への参照を取得
	var enemy: Enemy = enemy_ref.get_ref() as Enemy
	if not enemy:
		return false

	# 敵からプレイヤーへの方向を計算
	var direction_to_player: Vector2 = (body.global_position - enemy.global_position).normalized()

	# プレイヤーの敵ヒット処理を呼び出す（hpによるknockback判定）
	var should_knockback: bool = false
	if body.has_method("handle_enemy_hit"):
		should_knockback = body.handle_enemy_hit(direction_to_player)

	# knockback処理が実行された場合はここで終了
	if should_knockback:
		return true

	# knockbackが発生しない場合（プレイヤーのhpが0の場合）、CAPTURE状態へ遷移
	_transition_to_capture(body)
	return true

## CAPTURE状態開始時の処理
func enter_capture_state() -> void:
	# CAPTURE状態フラグを立てる
	is_in_capture_mode = true
	capture_state_entered.emit()

## CAPTURE状態終了時の処理
func exit_capture_state() -> void:
	# CAPTURE状態フラグを解除
	is_in_capture_mode = false
	capture_state_exited.emit()

## キャプチャアニメーション（通常時）を取得
func get_capture_animation_normal() -> String:
	return "enemy_" + enemy_id + "_" + capture_condition + "_idle"

## キャプチャアニメーション（DOWN/KNOCKBACK時）を取得
func get_capture_animation_down() -> String:
	return "enemy_" + enemy_id + "_" + capture_condition + "_down"

# ======================== 内部メソッド ========================

## プレイヤーをCAPTURE状態に遷移させる
func _transition_to_capture(body: Node2D) -> void:
	# プレイヤーの速度を完全に停止
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	# 使用するキャプチャアニメーションを選択
	var capture_animation: String = _select_capture_animation(body)

	# プレイヤーに使用するアニメーションを設定
	body.capture_animation_name = capture_animation

	# プレイヤーをCAPTURE状態に遷移
	if body.has_method("change_state"):
		body.change_state("CAPTURE")

	print("敵がプレイヤーをキャプチャ: アニメーション=", capture_animation)

## キャプチャアニメーションを選択
func _select_capture_animation(body: Node2D) -> String:
	# プレイヤーのconditionを取得してcapture_conditionに設定
	if body.has_method("get_condition"):
		var player_condition: int = body.get_condition()
		# enumを文字列に変換（0: NORMAL, 1: EXPANSION）
		capture_condition = "normal" if player_condition == 0 else "expansion"

	# プレイヤーの現在の状態を確認
	var player_state_name: String = _get_player_state_name(body)

	# プレイヤーがDOWNまたはKNOCKBACK状態の場合、接触時の位置で判定
	if player_state_name in ["DOWN", "KNOCKBACK"]:
		# 着地している場合はdownアニメーション、空中の場合はidleアニメーション
		return get_capture_animation_down() if body.is_on_floor() else get_capture_animation_normal()
	else:
		return get_capture_animation_normal()

## プレイヤーの現在の状態名を取得
func _get_player_state_name(body: Node2D) -> String:
	if not body.has_method("get_animation_tree"):
		return ""

	var anim_tree: AnimationTree = body.get_animation_tree()
	if not anim_tree:
		return ""

	var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
	if state_machine:
		return str(state_machine.get_current_node())
	return ""

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# 参照をクリア
	enemy_ref = null

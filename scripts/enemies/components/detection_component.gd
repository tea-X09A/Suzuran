## プレイヤー検知管理コンポーネント
## プレイヤー検知、追跡、キャプチャクールダウン管理を提供
class_name DetectionComponent
extends RefCounted

# ======================== シグナル定義 ========================

## プレイヤーの追跡を開始する時に発信
signal player_chase_started(player: Node2D)
## プレイヤーを見失った時に発信
signal player_lost(player: Node2D)

# ======================== パラメータ ========================

## プレイヤーを見失うまでの遅延時間（秒）
var lose_sight_delay: float = 2.0
## キャプチャのクールダウン時間（秒）
var capture_cooldown: float = 0.5

# ======================== 内部状態 ========================

## プレイヤーノードへの弱参照（メモリリーク防止）
var player_ref: WeakRef = null
## プレイヤーが検知範囲外にいるかどうか
var player_out_of_range: bool = false
## プレイヤーが範囲外にいる時間
var time_out_of_range: float = 0.0
## 最後にキャプチャした時間
var last_capture_time: float = 0.0
## hitboxと重なっているプレイヤー（キャッシュ用）
var overlapping_player: Node2D = null

# ======================== ノード参照 ========================

## 敵への弱参照（メモリリーク防止）
var enemy_ref: WeakRef = null
## Hitbox（プレイヤーにダメージを与える範囲）
var hitbox: Area2D = null

# ======================== 初期化 ========================

## コンストラクタ
func _init(enemy: Enemy, hitbox_node: Area2D) -> void:
	# 敵への弱参照を保存（循環参照を回避）
	enemy_ref = weakref(enemy)

	# ノード参照を保存
	hitbox = hitbox_node

# ======================== 公開メソッド ========================

## プレイヤー参照を取得（弱参照から実体を取得）
func get_player() -> Node2D:
	if player_ref:
		var player_instance = player_ref.get_ref()
		if player_instance:
			return player_instance as Node2D
	return null

## プレイヤーを追跡しているかどうか
func is_player_tracked() -> bool:
	return get_player() != null

## hitboxと重なっているプレイヤーをチェック（Enemyの_physics_process()から呼び出す）
func check_overlapping_player() -> Node2D:
	overlapping_player = _get_overlapping_player()
	return overlapping_player

## 見失いタイマーを処理（Enemyの_physics_process()から呼び出す）
## @param delta: デルタタイム
## @return: プレイヤーを見失った場合はtrue
func handle_lose_sight_timer(delta: float) -> bool:
	var player: Node2D = get_player()
	if player_out_of_range and player:
		time_out_of_range += delta
		# 遅延時間を超えたらプレイヤーを見失う
		if time_out_of_range >= lose_sight_delay:
			var lost_player: Node2D = player
			_clear_player_reference()
			player_lost.emit(lost_player)
			return true
	return false

## プレイヤーの追跡を開始（DetectionAreaのbody_enteredシグナルから呼び出す）
func start_chasing_player(player_node: Node2D) -> void:
	player_ref = weakref(player_node)
	_reset_out_of_range_flags()
	player_chase_started.emit(player_node)

## プレイヤーが範囲外に出たことを通知（DetectionAreaのbody_exitedシグナルから呼び出す）
func mark_player_out_of_range() -> void:
	player_out_of_range = true
	time_out_of_range = 0.0

## プレイヤー参照をクリア（画面外に出た時などに使用）
func clear_player() -> void:
	_clear_player_reference()

## キャプチャクールダウン中かどうかを確認
func is_capture_on_cooldown() -> bool:
	var current_time: float = Time.get_unix_time_from_system()
	return current_time - last_capture_time < capture_cooldown

## キャプチャが成功したことを記録
func record_capture() -> void:
	last_capture_time = Time.get_unix_time_from_system()

# ======================== 内部メソッド ========================

## hitboxと重なっているプレイヤーを取得
func _get_overlapping_player() -> Node2D:
	if not hitbox or not hitbox.monitoring:
		return null

	# プレイヤーのHurtboxとの重なりをチェック
	for area in hitbox.get_overlapping_areas():
		# Hurtboxの親ノードを取得
		var parent_node: Node = area.get_parent()
		# 親ノードがプレイヤーグループに所属しているか確認
		if parent_node and parent_node.is_in_group("player"):
			return parent_node

	return null

## 範囲外フラグをリセット
func _reset_out_of_range_flags() -> void:
	player_out_of_range = false
	time_out_of_range = 0.0

## プレイヤー参照をクリア
func _clear_player_reference() -> void:
	player_ref = null
	_reset_out_of_range_flags()

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# 参照をクリア
	player_ref = null
	overlapping_player = null
	enemy_ref = null
	hitbox = null

## PlayerAfterimageComponent
## プレイヤーの残像エフェクト管理を担当するコンポーネント
class_name PlayerAfterimageComponent
extends RefCounted

# ======================== 定数定義 ========================

## 残像生成間隔（秒）
const AFTERIMAGE_SPAWN_INTERVAL: float = 0.15

# ======================== 変数定義 ========================

## 残像生成タイマー
var afterimage_timer: float = 0.0

## プレイヤーへの弱参照（メモリリーク防止）
var _player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## AfterimageComponentの初期化
## @param player プレイヤーインスタンス
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)

# ======================== 更新処理 ========================

## 残像エフェクトを更新（_physics_processから呼び出される）
## @param delta デルタタイム
func update(delta: float) -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# 回避バフが無い場合は残像を表示しない
	if not player.buff_component or not player.buff_component.has_buff("speed_boost"):
		afterimage_timer = 0.0
		return

	afterimage_timer += delta
	if afterimage_timer >= AFTERIMAGE_SPAWN_INTERVAL:
		afterimage_timer = 0.0
		_spawn_afterimage()

# ======================== 残像生成 ========================

## 残像エフェクトを生成
func _spawn_afterimage() -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# スプライトが存在しない場合は生成しない
	var sprite_2d: Sprite2D = player.get_sprite_2d()
	if not sprite_2d:
		return

	# 残像インスタンスを作成
	var afterimage: Afterimage = Afterimage.new()

	# 残像を初期化（現在のスプライトの状態をコピー）
	afterimage.initialize(sprite_2d, player.global_position)

	# 残像をプレイヤーの親ノード（レベル）に追加
	var parent: Node = player.get_parent()
	if parent:
		parent.add_child(afterimage)

# ======================== クリーンアップ ========================

## クリーンアップ処理
func cleanup() -> void:
	# タイマーをリセット
	afterimage_timer = 0.0
	_player_ref = null

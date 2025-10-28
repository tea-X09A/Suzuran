## プレイヤーのCollisionBox管理コンポーネント
## 13個のHurtbox/Hitboxの位置管理と有効/無効の切り替えを担当
class_name PlayerCollisionComponent
extends RefCounted

# ======================== 定数定義 ========================

## CollisionBoxのノードパス（player.gdの@onready参照を削除するため）
const COLLISION_BOX_PATHS: Array[String] = [
	"IdleHurtbox/IdleHurtboxCollision",
	"SquatHurtbox/SquatHurtboxCollision",
	"JumpHurtbox/JumpHurtboxCollision",
	"RunHurtbox/RunHurtboxCollision",
	"FightingHurtbox/FightingHurtboxCollision",
	"ShootingHurtbox/ShootingHurtboxCollision",
	"KnockBackHurtbox/KnockBackHurtboxCollision",
	"DownHurtbox/DownHurtboxCollision",
	"FallHurtbox/FallHurtboxCollision",
	"WalkHurtbox/WalkHurtboxCollision",
	"FightingHitbox/FightingHitboxCollision",
	"ClosingHurtbox/ClosingHurtboxCollision",
	"DodgingHurtbox/DodgingHurtboxCollision"
]

# ======================== 内部クラス ========================

## CollisionBox情報を保持する内部クラス
class CollisionBoxInfo:
	var collision_shape: CollisionShape2D
	var original_x_position: float

	func _init(shape: CollisionShape2D) -> void:
		collision_shape = shape
		original_x_position = shape.position.x

# ======================== プロパティ ========================

## 全CollisionBox情報を保持する配列
var _collision_boxes: Array[CollisionBoxInfo] = []

## WeakRef for player（循環参照防止）
var _player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## コンポーネントを初期化
## @param player CharacterBody2D プレイヤーノードへの参照
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)

	# 各CollisionBoxを自動的に取得して登録
	for path in COLLISION_BOX_PATHS:
		var collision_shape: CollisionShape2D = player.get_node_or_null(path)
		if collision_shape:
			register_collision_box(collision_shape)
		else:
			push_warning("[PlayerCollisionComponent] CollisionBox not found: " + path)

# ======================== CollisionBox登録 ========================

## CollisionBoxを登録し、初期位置を保存
## @param collision_shape CollisionShape2D 登録するCollisionShape
func register_collision_box(collision_shape: CollisionShape2D) -> void:
	if not collision_shape:
		push_warning("Attempted to register null collision shape")
		return

	var box_info: CollisionBoxInfo = CollisionBoxInfo.new(collision_shape)
	_collision_boxes.append(box_info)

# ======================== Collision状態管理 ========================

## 全CollisionBoxの有効/無効を一括切り替え
## @param enabled bool true=有効, false=無効
func set_all_collision_boxes_enabled(enabled: bool) -> void:
	for box_info: CollisionBoxInfo in _collision_boxes:
		if box_info.collision_shape:
			box_info.collision_shape.disabled = not enabled

## 全CollisionBoxを有効化
func enable_all_collision_boxes() -> void:
	set_all_collision_boxes_enabled(true)

## 全CollisionBoxを無効化
func disable_all_collision_boxes() -> void:
	set_all_collision_boxes_enabled(false)

# ======================== CollisionBox位置管理 ========================

## スプライトの向きに応じてCollisionBox位置を更新
## @param is_facing_right bool true=右向き, false=左向き
func update_box_positions(is_facing_right: bool) -> void:
	for box_info: CollisionBoxInfo in _collision_boxes:
		if not box_info.collision_shape:
			continue

		if is_facing_right:
			# 右向き：元の位置をマイナス反転（sprite_2d.flip_hがtrueなので）
			box_info.collision_shape.position.x = -box_info.original_x_position
		else:
			# 左向き：元の位置（sprite_2d.flip_hがfalseなので）
			box_info.collision_shape.position.x = box_info.original_x_position

# ======================== ユーティリティ ========================

## 登録されているCollisionBox数を取得
## @return int CollisionBoxの数
func get_collision_box_count() -> int:
	return _collision_boxes.size()

# ======================== クリーンアップ ========================

## コンポーネントのクリーンアップ処理
func cleanup() -> void:
	_collision_boxes.clear()
	_player_ref = null

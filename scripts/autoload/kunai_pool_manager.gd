## クナイオブジェクトプールマネージャー（AutoLoad）
## クナイのインスタンスを再利用してパフォーマンスを最適化
extends Node

# ======================== 定数定義 ========================

## クナイシーンのプリロード
const KUNAI_SCENE: PackedScene = preload("res://scenes/bullets/kunai.tscn")
## プールの初期サイズ（プレイヤー10 + 敵10程度）
const INITIAL_POOL_SIZE: int = 20

# ======================== プール管理 ========================

## クナイオブジェクトプール
var kunai_pool: Array[Kunai] = []

# ======================== 初期化処理 ========================

func _ready() -> void:
	_initialize_pool()

## プールの初期化
func _initialize_pool() -> void:
	for i in INITIAL_POOL_SIZE:
		var kunai: Kunai = KUNAI_SCENE.instantiate()
		kunai_pool.append(kunai)
		add_child(kunai)
		_deactivate_kunai(kunai)

# ======================== 公開API ========================

## プールからクナイを取得（プレイヤー・敵共通）
func get_kunai() -> Kunai:
	# プールから非アクティブなクナイを検索
	for kunai in kunai_pool:
		if not kunai.visible:
			return kunai

	# プールが空の場合は動的に拡張
	var new_kunai: Kunai = KUNAI_SCENE.instantiate()
	kunai_pool.append(new_kunai)
	add_child(new_kunai)
	_deactivate_kunai(new_kunai)

	return new_kunai

## プールにクナイを返却
func return_kunai(kunai: Kunai) -> void:
	if not kunai or not is_instance_valid(kunai):
		return

	_deactivate_kunai(kunai)

# ======================== 内部処理 ========================

## クナイを非アクティブ化
func _deactivate_kunai(kunai: Kunai) -> void:
	kunai.visible = false
	kunai.set_physics_process(false)
	kunai.velocity = Vector2.ZERO
	kunai.owner_character = null
	kunai.lifetime_timer = kunai.lifetime

# ======================== デバッグ用 ========================

## 現在のプール状態を取得（デバッグ用）
func get_pool_stats() -> Dictionary:
	var active_count: int = 0
	var inactive_count: int = 0

	for kunai in kunai_pool:
		if kunai.visible:
			active_count += 1
		else:
			inactive_count += 1

	return {
		"total": kunai_pool.size(),
		"active": active_count,
		"inactive": inactive_count
	}

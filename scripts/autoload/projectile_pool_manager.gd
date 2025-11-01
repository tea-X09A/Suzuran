## プロジェクタイルオブジェクトプールマネージャー（AutoLoad）
## プロジェクタイルのインスタンスを再利用してパフォーマンスを最適化
extends Node

# ======================== 定数定義 ========================

## プロジェクタイルシーンのプリロード
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/bullets/projectile.tscn")
## プールの初期サイズ（プレイヤー10 + 敵10程度）
const INITIAL_POOL_SIZE: int = 20

# ======================== プール管理 ========================

## プロジェクタイルオブジェクトプール
var projectile_pool: Array[Projectile] = []

# ======================== 初期化処理 ========================

func _ready() -> void:
	_initialize_pool()

## プールの初期化
func _initialize_pool() -> void:
	for i in INITIAL_POOL_SIZE:
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile_pool.append(projectile)
		add_child(projectile)
		projectile.deactivate()  # 初期状態は非アクティブ（プロジェクタイル自身のdeactivate()を使用）

# ======================== 公開API ========================

## プールからプロジェクタイルを取得（プレイヤー・敵共通）
func get_projectile() -> Projectile:
	# プールから非アクティブなプロジェクタイルを検索
	for projectile in projectile_pool:
		if not projectile.visible:
			return projectile

	# プールが空の場合は動的に拡張
	var new_projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile_pool.append(new_projectile)
	add_child(new_projectile)
	new_projectile.deactivate()  # プロジェクタイル自身のdeactivate()を使用

	return new_projectile

## プールにプロジェクタイルを返却
func return_projectile(projectile: Projectile) -> void:
	if not projectile or not is_instance_valid(projectile):
		return

	# プロジェクタイル自身のdeactivate()を呼び出す（シグナル切断含む）
	projectile.deactivate()

# ======================== デバッグ用 ========================

## 現在のプール状態を取得（デバッグ用）
func get_pool_stats() -> Dictionary:
	var active_count: int = 0
	var inactive_count: int = 0

	for projectile in projectile_pool:
		if projectile.visible:
			active_count += 1
		else:
			inactive_count += 1

	return {
		"total": projectile_pool.size(),
		"active": active_count,
		"inactive": inactive_count
	}

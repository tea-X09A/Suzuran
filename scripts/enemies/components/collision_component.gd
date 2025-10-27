## コリジョン管理コンポーネント
## HitboxとHurtboxの有効化/無効化、画面内外による自動制御を提供
class_name CollisionComponent
extends RefCounted

# ======================== シグナル定義 ========================

## コリジョンが有効化された時に発信
signal collision_enabled()
## コリジョンが無効化された時に発信
signal collision_disabled()

# ======================== ノード参照 ========================

## 敵への弱参照（メモリリーク防止）
var enemy_ref: WeakRef = null
## Hitbox（プレイヤーにダメージを与える範囲）
var hitbox: Area2D = null
## Hurtbox（プレイヤーの攻撃を受ける範囲）
var hurtbox: Area2D = null

# ======================== 初期化 ========================

## コンストラクタ
func _init(enemy: Enemy, hitbox_node: Area2D, hurtbox_node: Area2D) -> void:
	# 敵への弱参照を保存（循環参照を回避）
	enemy_ref = weakref(enemy)

	# ノード参照を保存
	hitbox = hitbox_node
	hurtbox = hurtbox_node

## コリジョンシステムの初期化（Enemyの_ready()から呼び出す）
func initialize() -> void:
	# 初期状態ではhitboxとhurtboxを無効化
	disable_collision_areas()

# ======================== 公開メソッド ========================

## コリジョンエリアを有効化
func enable_collision_areas() -> void:
	_set_collision_areas(true)
	collision_enabled.emit()

## コリジョンエリアを無効化
func disable_collision_areas() -> void:
	_set_collision_areas(false)
	collision_disabled.emit()

# ======================== 内部メソッド ========================

## コリジョンエリアの有効/無効を一括設定（hitboxとhurtboxのみ）
func _set_collision_areas(enabled: bool) -> void:
	# Hitbox: プレイヤーのHurtboxを検知するため、monitoringとmonitorableの両方を設定
	# 物理演算中の変更に対応するため、set_deferredを使用（CLAUDE.mdガイドライン準拠）
	if hitbox:
		hitbox.set_deferred("monitoring", enabled)
		hitbox.set_deferred("monitorable", enabled)

	# Hurtbox: プレイヤーの攻撃から検知されるだけなので、monitorableのみ設定
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", enabled)

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# 参照をクリア
	enemy_ref = null
	hitbox = null
	hurtbox = null

extends Area2D
class_name Projectile

# ======================== エクスポート変数 ========================
## 生存時間（秒）
@export var lifetime: float = 2.0
## ダメージ量
@export var damage: int = 1

# ======================== 変数定義 ========================
## プロジェクタイルの速度ベクトル
var velocity: Vector2 = Vector2.ZERO
## 発射したキャラクター
var owner_character: Node2D = null
## 生存時間タイマー
var lifetime_timer: float = 0.0

# ======================== ノード参照キャッシュ ========================
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# ======================== 初期化 ========================
## プール初期化時の処理（シグナル接続はactivate()で行う）
func _ready() -> void:
	pass

# ======================== フレーム処理 ========================
## 物理演算処理（移動と生存時間カウントダウン）
func _physics_process(delta: float) -> void:
	# 移動処理
	global_position += velocity * delta

	# 生存時間カウントダウン
	lifetime_timer -= delta
	if lifetime_timer <= 0.0:
		destroy_projectile()

# ======================== 公開メソッド ========================
## プロジェクタイルの初期化（プレイヤーから呼び出される）
func initialize(direction: float, speed: float, shooter: Node2D, damage_value: int = 1) -> void:
	# 速度設定
	velocity = Vector2(direction * speed, 0.0)

	# 発射者を記録
	owner_character = shooter

	# ダメージ値を設定
	damage = damage_value

	# 生存時間タイマーをリセット
	lifetime_timer = lifetime

	# スプライトの向きを設定
	if direction < 0.0:
		sprite_2d.flip_h = true
	else:
		sprite_2d.flip_h = false

	# プロジェクタイルをアクティブ化
	activate()

## プロジェクタイルをアクティブ化（プールから取得時）
func activate() -> void:
	# シグナル接続（重複接続を防止）
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	# 表示と物理処理を有効化
	visible = true
	set_physics_process(true)

## プロジェクタイルを非アクティブ化（プール返却時）
func deactivate() -> void:
	# シグナル接続を安全に解除（CLAUDE.mdガイドライン準拠）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if area_entered.is_connected(_on_area_entered):
		area_entered.disconnect(_on_area_entered)

	# 表示と物理処理を無効化
	visible = false
	set_physics_process(false)

	# 状態をリセット
	velocity = Vector2.ZERO
	owner_character = null
	lifetime_timer = lifetime

# ======================== プライベートメソッド ========================
## 物理ボディとの衝突処理
func _on_body_entered(body: Node2D) -> void:
	# 発射したキャラクターとの衝突を無視
	if body == owner_character:
		return

	# ダメージ処理（対象がダメージを受けられる場合）
	if body.has_method("take_damage"):
		# プロジェクタイルの進行方向をノックバック方向として使用
		var knockback_direction: Vector2 = velocity.normalized()
		body.take_damage(damage, knockback_direction, self)

	# プロジェクタイルを破壊
	destroy_projectile()

## エリア（Area2D）との衝突処理
func _on_area_entered(area: Area2D) -> void:
	# 発射したキャラクターのhurtboxとの衝突を無視
	if area.get_parent() == owner_character:
		return

	# 発射したキャラクター以外との衝突をチェック
	if area != owner_character:
		# 他のプロジェクタイルとの衝突処理
		if area is Projectile:
			var other_projectile: Projectile = area as Projectile
			# 同じキャラクターが発射したプロジェクタイル同士は衝突しない
			if other_projectile.owner_character == owner_character:
				return
			# 異なるキャラクターが発射したプロジェクタイル同士は両方破壊
			other_projectile.destroy_projectile()
			destroy_projectile()
		else:
			# ダメージ処理（対象がダメージを受けられる場合）
			# Areaの親ノード（敵本体）に対してダメージを与える
			var target: Node = area.get_parent()
			if target and target.has_method("take_damage"):
				# プロジェクタイルの進行方向をノックバック方向として使用
				var knockback_direction: Vector2 = velocity.normalized()
				target.take_damage(damage, knockback_direction, self)

			# プロジェクタイルを破壊
			destroy_projectile()

## プロジェクタイル破壊処理（プール返却）
func destroy_projectile() -> void:
	# オブジェクトプールに返却（deactivate()はPoolManager側で呼ばれる）
	ProjectilePoolManager.return_projectile(self)

# ======================== クリーンアップ ========================
## シーンツリーから削除される際の処理
func _exit_tree() -> void:
	# deactivate()でシグナル切断と状態リセットを一括処理（重複削除）
	deactivate()

extends Area2D
class_name Projectile

# ======================== 定数定義 ========================
## プライマリ投射物のテクスチャ（NORMAL condition用：ダメージあり・スタンなし）
const PRIMARY_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/images/bullets/primary_projectile.png")
## セカンダリ投射物のテクスチャ（EXPANSION condition用：ダメージなし・スタンあり）
const SECONDARY_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/images/bullets/projectile.png")
## プロジェクタイルの統一表示サイズ（ピクセル）
const TARGET_SIZE: float = 50.0
## プライマリ投射物の最大飛距離（ピクセル）
const PRIMARY_PROJECTILE_MAX_DISTANCE: float = 400.0
## セカンダリ投射物の重力加速度（ピクセル/秒^2）
const SECONDARY_PROJECTILE_GRAVITY: float = 980.0
## セカンダリ投射物の減衰開始距離（ピクセル）
const SECONDARY_PROJECTILE_DECELERATION_START: float = 100.0
## セカンダリ投射物の減衰率（0.0-1.0、小さいほど減衰が強い）
const SECONDARY_PROJECTILE_DECELERATION_RATE: float = 0.99

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
## スタンエフェクトを適用するかどうか（trueの場合はダメージなし・スタンあり、falseの場合はダメージあり・スタンなし）
var applies_stun_effect: bool = false
## 移動距離（セカンダリ投射物の減衰計算用）
var distance_traveled: float = 0.0

# ======================== ノード参照キャッシュ ========================
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# ======================== フレーム処理 ========================
## 物理演算処理（移動と生存時間カウントダウン）
func _physics_process(delta: float) -> void:
	# 移動距離を追跡
	var movement: Vector2 = velocity * delta
	distance_traveled += movement.length()

	# セカンダリ投射物の場合のみ物理挙動を適用
	if applies_stun_effect:
		# 一定距離進んだ後に重力と減速を適用
		if distance_traveled >= SECONDARY_PROJECTILE_DECELERATION_START:
			# 重力を適用
			velocity.y += SECONDARY_PROJECTILE_GRAVITY * delta
			# 水平速度を減衰
			velocity.x *= SECONDARY_PROJECTILE_DECELERATION_RATE
	else:
		# プライマリ投射物の場合、最大飛距離に達したら消える
		if distance_traveled >= PRIMARY_PROJECTILE_MAX_DISTANCE:
			destroy_projectile()
			return

	# 移動処理
	global_position += velocity * delta

	# セカンダリ投射物の生存時間カウントダウン（プライマリ投射物は距離で管理するため不要）
	if applies_stun_effect:
		lifetime_timer -= delta
		if lifetime_timer <= 0.0:
			destroy_projectile()

# ======================== 公開メソッド ========================
## プロジェクタイルの初期化（プレイヤーから呼び出される）
func initialize(direction: float, speed: float, shooter: Node2D, damage_value: int = 1, stun_effect: bool = false) -> void:
	# 速度設定
	velocity = Vector2(direction * speed, 0.0)

	# 発射者を記録
	owner_character = shooter

	# ダメージ値を設定
	damage = damage_value

	# スタンエフェクトフラグを設定
	applies_stun_effect = stun_effect

	# スタンエフェクトに応じてスプライトとスケールを設定
	if applies_stun_effect:
		# スタンエフェクトあり = セカンダリ投射物
		sprite_2d.texture = SECONDARY_PROJECTILE_TEXTURE
	else:
		# スタンエフェクトなし = プライマリ投射物
		sprite_2d.texture = PRIMARY_PROJECTILE_TEXTURE

	# テクスチャのサイズを取得し、TARGET_SIZE（50px）になるようにscaleを計算
	var texture_size: Vector2 = sprite_2d.texture.get_size()
	var max_dimension: float = max(texture_size.x, texture_size.y)
	var scale_factor: float = TARGET_SIZE / max_dimension
	sprite_2d.scale = Vector2(scale_factor, scale_factor)

	# 生存時間タイマーをリセット
	lifetime_timer = lifetime

	# スプライトの向きを設定（画像は左向きに描かれているため、右向きの時に反転）
	if direction > 0.0:
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
	applies_stun_effect = false
	distance_traveled = 0.0

# ======================== プライベートメソッド ========================
## 物理ボディとの衝突処理（床、壁、敵の本体など）
## NORMAL、EXPANSION両conditionで共通：障害物との衝突時に必ず消える
func _on_body_entered(body: Node2D) -> void:
	# 発射したキャラクターとの衝突を無視
	if body == owner_character:
		return

	# ダメージ処理（対象がダメージを受けられる場合のみ）
	if body.has_method("take_damage"):
		# プロジェクタイルの進行方向をノックバック方向として使用
		var knockback_direction: Vector2 = velocity.normalized()
		body.take_damage(damage, knockback_direction, self)

	# プロジェクタイルを破壊（床、壁、敵など全ての物理ボディとの衝突時に実行）
	destroy_projectile()

## エリア（Area2D）との衝突処理（敵のhurtbox、他のプロジェクタイルなど）
## NORMAL、EXPANSION両conditionで共通：障害物との衝突時に必ず消える
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
			# ダメージ処理（対象がダメージを受けられる場合のみ）
			# Areaの親ノード（敵本体）に対してダメージを与える
			var target: Node = area.get_parent()
			if target and target.has_method("take_damage"):
				# プロジェクタイルの進行方向をノックバック方向として使用
				var knockback_direction: Vector2 = velocity.normalized()
				target.take_damage(damage, knockback_direction, self)

			# プロジェクタイルを破壊（敵のhurtboxなど全てのエリアとの衝突時に実行）
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

extends Area2D
class_name Kunai

# ======================== エクスポート変数 ========================
## 生存時間（秒）
@export var lifetime: float = 2.0
## ダメージ量
@export var damage: int = 1

# ======================== 変数定義 ========================
## クナイの速度ベクトル
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
		destroy_kunai()

# ======================== 公開メソッド ========================
## クナイの初期化（プレイヤーから呼び出される）
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

	# クナイをアクティブ化
	activate()

## クナイをアクティブ化（プールから取得時）
func activate() -> void:
	# シグナル接続（重複接続を防止）
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	# 表示と物理処理を有効化
	visible = true
	set_physics_process(true)

## クナイを非アクティブ化（プール返却時）
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
		# クナイの進行方向をノックバック方向として使用
		var knockback_direction: Vector2 = velocity.normalized()
		body.take_damage(damage, knockback_direction, self)

	# クナイを破壊
	destroy_kunai()

## エリア（Area2D）との衝突処理
func _on_area_entered(area: Area2D) -> void:
	# 発射したキャラクターのhurtboxとの衝突を無視
	if area.get_parent() == owner_character:
		return

	# 発射したキャラクター以外との衝突をチェック
	if area != owner_character:
		# 他のクナイとの衝突処理
		if area is Kunai:
			var other_kunai: Kunai = area as Kunai
			# 同じキャラクターが発射したクナイ同士は衝突しない
			if other_kunai.owner_character == owner_character:
				return
			# 異なるキャラクターが発射したクナイ同士は両方破壊
			other_kunai.destroy_kunai()
			destroy_kunai()
		else:
			# ダメージ処理（対象がダメージを受けられる場合）
			# Areaの親ノード（敵本体）に対してダメージを与える
			var target: Node = area.get_parent()
			if target and target.has_method("take_damage"):
				# クナイの進行方向をノックバック方向として使用
				var knockback_direction: Vector2 = velocity.normalized()
				target.take_damage(damage, knockback_direction, self)

			# クナイを破壊
			destroy_kunai()

## クナイ破壊処理（プール返却）
func destroy_kunai() -> void:
	# オブジェクトプールに返却
	deactivate()
	KunaiPoolManager.return_kunai(self)

# ======================== クリーンアップ ========================
## シーンツリーから削除される際の処理
func _exit_tree() -> void:
	# 参照をクリア（メモリリーク防止）
	owner_character = null

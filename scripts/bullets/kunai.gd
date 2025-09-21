extends Area2D
class_name Kunai

# ========== クナイ設定 ==========
@export var lifetime: float = 2.0  # 生存時間（秒）
@export var damage: int = 25  # ダメージ量

# ========== 内部状態変数 ==========
var velocity: Vector2 = Vector2.ZERO
var owner_character: Node2D = null  # 発射したキャラクター
var lifetime_timer: float = 0.0

# ノード参照をキャッシュ（CLAUDE.mdガイドライン準拠）
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# シグナル接続（CLAUDE.mdガイドライン準拠）
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# 生存時間タイマーを初期化
	lifetime_timer = lifetime

func _physics_process(delta: float) -> void:
	# 移動処理
	global_position += velocity * delta

	# 生存時間カウントダウン
	lifetime_timer -= delta
	if lifetime_timer <= 0.0:
		destroy_kunai()

# クナイの初期化（プレイヤーから呼び出される）
func initialize(direction: float, speed: float, shooter: Node2D) -> void:
	# 速度設定
	velocity = Vector2(direction * speed, 0.0)

	# 発射者を記録
	owner_character = shooter

	# スプライトの向きを設定
	if direction < 0.0:
		sprite_2d.flip_h = true
	else:
		sprite_2d.flip_h = false

# 物理ボディとの衝突処理
func _on_body_entered(body: Node2D) -> void:
	# 発射したキャラクター以外との衝突をチェック
	if body != owner_character:
		# ダメージ処理（対象がダメージを受けられる場合）
		if body.has_method("take_damage"):
			body.take_damage(damage)

		# クナイを破壊
		destroy_kunai()

# エリア（Area2D）との衝突処理
func _on_area_entered(area: Area2D) -> void:
	# 発射したキャラクター以外との衝突をチェック
	if area != owner_character:
		# ダメージ処理（対象がダメージを受けられる場合）
		if area.has_method("take_damage"):
			area.take_damage(damage)

		# クナイを破壊
		destroy_kunai()

# クナイ破壊処理
func destroy_kunai() -> void:
	# シグナル接続を安全に解除（CLAUDE.mdガイドライン準拠）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if area_entered.is_connected(_on_area_entered):
		area_entered.disconnect(_on_area_entered)

	# 安全な削除（CLAUDE.mdガイドライン準拠）
	queue_free()

# シーンツリーから削除される際の処理
func _exit_tree() -> void:
	# 弱参照でない場合の参照をクリア（メモリリーク防止）
	owner_character = null

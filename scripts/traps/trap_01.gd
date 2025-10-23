class_name Trap01
extends StaticBody2D

# ======================== ノード参照 ========================

## ヒットボックスへの参照
@onready var hitbox: Area2D = $Hitbox
## 視覚化制御への参照
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# ======================== エクスポートプロパティ ========================

## トラップのダメージ量
@export var damage: int = 10
## ノックバックの力
@export var knockback_force: float = 300.0
## ダメージのクールダウン時間
@export var damage_cooldown: float = 0.5
## トラップの効果タイプ
@export_enum("down", "knockback") var effect_type: String = "down"

# ======================== 変数定義 ========================

## 処理が有効かどうかのフラグ
var processing_enabled: bool = false
## 最後にダメージを与えた時間
var last_damage_time: float = 0.0

# ======================== 初期化・クリーンアップ ========================

func _ready() -> void:
	# trapsグループに追加
	add_to_group("traps")

	# VisibleOnScreenEnabler2Dのシグナルに接続してカメラ範囲内外の状態を監視
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)

## クリーンアップ処理
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	if visibility_enabler:
		if visibility_enabler.screen_entered.is_connected(_on_screen_entered):
			visibility_enabler.screen_entered.disconnect(_on_screen_entered)
		if visibility_enabler.screen_exited.is_connected(_on_screen_exited):
			visibility_enabler.screen_exited.disconnect(_on_screen_exited)

# ======================== 物理演算処理 ========================

func _physics_process(_delta: float) -> void:
	if not processing_enabled:
		return

	check_player_collision()

# ======================== ヘルパーメソッド ========================

## プレイヤーとの衝突をチェック
func check_player_collision() -> void:
	if not hitbox:
		return

	# クールダウン中は処理しない
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_damage_time < damage_cooldown:
		return

	# プレイヤーとの重なりをチェック
	var overlapping_bodies: Array[Node2D] = hitbox.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body.is_in_group("player"):
			# 実際にダメージを与えた場合のみタイマーを更新
			if apply_damage_to_player(body):
				last_damage_time = current_time
			break

## プレイヤーにダメージを適用
func apply_damage_to_player(player: Node2D) -> bool:
	# プレイヤーが無敵状態の場合はダメージを与えない
	if player.has_method("is_invincible") and player.is_invincible():
		return false

	# プレイヤーにダメージを適用
	if player.has_method("handle_trap_damage"):
		# トラップの向きからノックバック方向を計算（プレイヤーがトラップより右にいれば右へ押す）
		var direction: Vector2 = Vector2(sign(player.global_position.x - global_position.x), 0.0)
		if direction.x == 0.0:
			direction.x = 1.0  # デフォルトは右向き
		player.handle_trap_damage(effect_type, direction, knockback_force)

	print("トラップダメージ適用: タイプ=", effect_type, " ダメージ=", damage, " 力=", knockback_force)
	return true

# ======================== シグナルハンドラ ========================

## 画面内に入った時の処理
func _on_screen_entered() -> void:
	processing_enabled = true
	hitbox.monitoring = true
	print("トラップ有効化: ヒットボックス監視開始")

## 画面外に出た時の処理
func _on_screen_exited() -> void:
	processing_enabled = false
	hitbox.monitoring = false
	print("トラップ無効化: ヒットボックス監視停止")

# ======================== ゲッターメソッド ========================

## ダメージ量を取得
func get_damage() -> int:
	return damage

## ノックバック力を取得
func get_knockback_force() -> float:
	return knockback_force

## 効果タイプを取得
func get_effect_type() -> String:
	return effect_type

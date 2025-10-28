## トラップクラス（ノックバック・ダウン）
## プレイヤーに接触効果（knockback/down）を与える
class_name Trap
extends StaticBody2D

# ======================== 定数定義 ========================

## 効果タイプ定数
const EFFECT_TYPE_KNOCKBACK: String = "knockback"
const EFFECT_TYPE_DOWN: String = "down"

# ======================== ノード参照 ========================

## ヒットボックスへの参照
@onready var hitbox: Area2D = $Hitbox
## 視覚化制御への参照
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# ======================== エクスポートプロパティ ========================

## ノックバックの力（knockback/downタイプで使用）
@export var knockback_force: float = 300.0
## 接触判定のクールダウン時間
@export var effect_cooldown: float = 0.5
## トラップの効果タイプ
@export_enum("knockback", "down") var effect_type: String = EFFECT_TYPE_KNOCKBACK

# ======================== 変数定義 ========================

## 処理が有効かどうかのフラグ
var processing_enabled: bool = false
## 最後に効果を適用した時間
var last_effect_time: float = 0.0

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
	if current_time - last_effect_time < effect_cooldown:
		return

	# プレイヤーとの重なりをチェック
	var overlapping_bodies: Array[Node2D] = hitbox.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body.is_in_group("player"):
			# 実際に効果を適用した場合のみタイマーを更新
			if apply_effect_to_player(body):
				last_effect_time = current_time
			break

## プレイヤーにトラップ効果を適用
func apply_effect_to_player(player: Node2D) -> bool:
	# プレイヤーが無敵状態の場合は効果を与えない
	if player.has_method("is_invincible") and player.is_invincible():
		return false

	# プレイヤーにトラップ効果を適用
	if player.has_method("handle_trap_damage"):
		# トラップの向きからノックバック方向を計算（プレイヤーがトラップより右にいれば右へ押す）
		var direction: Vector2 = Vector2(sign(player.global_position.x - global_position.x), 0.0)
		if direction.x == 0.0:
			direction.x = 1.0  # デフォルトは右向き
		player.handle_trap_damage(effect_type, direction, knockback_force)
		return true

	return false

# ======================== シグナルハンドラ ========================

## 画面内に入った時の処理
func _on_screen_entered() -> void:
	processing_enabled = true
	hitbox.monitoring = true

## 画面外に出た時の処理
func _on_screen_exited() -> void:
	processing_enabled = false
	hitbox.monitoring = false

# ======================== ゲッターメソッド ========================

## ノックバック力を取得
func get_knockback_force() -> float:
	return knockback_force

## 効果タイプを取得
func get_effect_type() -> String:
	return effect_type

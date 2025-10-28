## HP管理コンポーネント
## HP、ダメージ処理、ノックバック、HPゲージ、死亡処理を管理
class_name EnemyHealthComponent
extends RefCounted

# ======================== シグナル定義 ========================

## HP変更時に発信
signal health_changed(current_hp: int, max_hp: int)
## 死亡時に発信
signal died()
## ノックバック適用時に発信
signal knockback_applied(velocity: Vector2, direction_to_face: float)

# ======================== パラメータ ========================

## 最大HP
var max_hp: int = 5
## ノックバックの力
var knockback_force: float = 300.0

# ======================== 内部状態 ========================

## 現在のHP
var current_hp: int = 0
## ノックバック速度
var knockback_velocity: Vector2 = Vector2.ZERO
## ノックバック後に向くべき方向（0.0なら変更なし）
var direction_to_face_after_knockback: float = 0.0
## HPゲージへの参照（scripts/ui/enemy_hp_gauge.gd）
var hp_gauge: Control = null

# ======================== ノード参照（WeakRefで保持） ========================

## 敵への弱参照（メモリリーク防止）
var enemy_ref: WeakRef = null

# ======================== 初期化 ========================

## コンストラクタ
func _init(enemy: Enemy) -> void:
	# 敵への弱参照を保存（循環参照を回避）
	enemy_ref = weakref(enemy)

## HPシステムの初期化（Enemyの_ready()から呼び出す）
## @param initial_max_hp: 最大HP
## @param initial_knockback_force: ノックバックの力
func initialize(initial_max_hp: int, initial_knockback_force: float) -> void:
	max_hp = initial_max_hp
	knockback_force = initial_knockback_force
	current_hp = max_hp
	_create_hp_gauge()

# ======================== 公開メソッド ========================

## 現在のHPを取得
func get_current_hp() -> int:
	return current_hp

## ダメージを受ける処理
## @param damage: ダメージ量
## @param direction: ダメージを受けた方向
## @param attacker: 攻撃者ノード
## @param state_instances: 敵のステートインスタンス辞書
## @param current_state: 敵の現在のステート
func take_damage(damage: int, direction: Vector2, attacker: Node, state_instances: Dictionary, current_state) -> void:
	# すでに死んでいる場合は処理しない
	if current_hp <= 0:
		return

	# 敵への参照を取得
	var enemy: Enemy = enemy_ref.get_ref() as Enemy
	if not enemy:
		return

	# パトロール状態または待機状態の場合の特別処理
	if current_state == state_instances["PATROL"] or current_state == state_instances["IDLE"]:
		# FightingHitboxからの攻撃の場合は即死
		if attacker and attacker.name == "FightingHitbox":
			current_hp = 0
			_die()
			return
		# Kunai（shooting）からの攻撃の場合はプレイヤーの方向へ向く
		elif attacker and attacker is Kunai:
			# プレイヤーへの参照を取得
			var kunai_owner: Node2D = attacker.owner_character
			if kunai_owner:
				# プレイヤーの方向を計算
				var direction_to_player: float = sign(kunai_owner.global_position.x - enemy.global_position.x)
				if direction_to_player != 0:
					direction_to_face_after_knockback = direction_to_player

	# ダメージを適用
	current_hp -= damage
	print("[%s] ダメージ: %d, 残りHP: %d/%d" % [enemy.name, damage, current_hp, max_hp])

	# HPゲージを更新
	_update_hp_gauge()

	# HPが0以下になったら死亡処理
	if current_hp <= 0:
		_die()
	else:
		# ノックバックを適用
		_apply_knockback(direction, attacker)

	# シグナルを発信
	health_changed.emit(current_hp, max_hp)

## ノックバック速度を取得
func get_knockback_velocity() -> Vector2:
	return knockback_velocity

## ノックバック後に向くべき方向を取得
func get_direction_to_face_after_knockback() -> float:
	return direction_to_face_after_knockback

## ノックバック後の向き情報をリセット
func reset_direction_to_face() -> void:
	direction_to_face_after_knockback = 0.0

# ======================== 内部メソッド ========================

## ノックバックを適用
func _apply_knockback(direction: Vector2, attacker: Node) -> void:
	# ノックバック速度を設定
	var current_knockback_force: float = knockback_force
	var vertical_force: float = -100.0

	# FightingHitboxからの攻撃の場合、2倍の力
	if attacker and attacker.name == "FightingHitbox":
		current_knockback_force *= 2.0
		vertical_force = -150.0

	knockback_velocity = Vector2(direction.x * current_knockback_force, vertical_force)

	# シグナルを発信
	knockback_applied.emit(knockback_velocity, direction_to_face_after_knockback)

## 死亡処理
func _die() -> void:
	# 敵への参照を取得
	var enemy: Enemy = enemy_ref.get_ref() as Enemy
	if not enemy:
		return

	print("[%s] 死亡" % enemy.name)

	# HPゲージを非表示
	if hp_gauge:
		hp_gauge.hide_gauge()

	# シグナルを発信
	died.emit()

## HPゲージを作成
func _create_hp_gauge() -> void:
	# 敵への参照を取得
	var enemy: Enemy = enemy_ref.get_ref() as Enemy
	if not enemy:
		return

	# enemy_hp_gauge.gdのインスタンスを作成
	var EnemyHPGauge: Script = preload("res://scripts/ui/enemy_hp_gauge.gd")
	hp_gauge = EnemyHPGauge.new()
	hp_gauge.name = "HPGauge"
	hp_gauge.position = Vector2(0, -80)
	hp_gauge.max_hp = max_hp
	hp_gauge.current_hp = current_hp
	enemy.add_child(hp_gauge)

## HPゲージを更新
func _update_hp_gauge() -> void:
	if not hp_gauge:
		return
	hp_gauge.update_hp(current_hp, max_hp)

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# HPゲージを削除
	if hp_gauge and is_instance_valid(hp_gauge):
		hp_gauge.queue_free()
	hp_gauge = null

	# 参照をクリア
	enemy_ref = null

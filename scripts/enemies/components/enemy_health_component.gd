## HP管理コンポーネント
## HP、ダメージ処理、ノックバック、HPゲージ、死亡処理を管理
class_name EnemyHealthComponent
extends RefCounted

# ======================== シグナル定義 ========================

## HP変更時に発信
signal health_changed(current_hp: int, max_hp: int)
## 死亡時に発信（ノックバック速度と即死フラグを含む）
signal died(death_knockback_velocity: Vector2, is_instant_kill: bool)
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
## HPゲージへの参照（scripts/ui/health_gauge.gd）
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
	# ただし、FIGHTING後のIDLE状態は除外（交戦済みなので即死対象外）
	if (current_state == state_instances["PATROL"] or
		(current_state == state_instances["IDLE"] and not enemy.is_after_fighting)):
		# FightingHitboxからの攻撃の場合は即死（クリティカル）
		if attacker and attacker.name == "FightingHitbox":
			current_hp = 0
			_die(direction, attacker, true)  # 即死フラグをtrueに
			return
		# Projectile（throwing）からの攻撃の場合はプレイヤーの方向へ向く
		elif attacker and attacker is Projectile:
			# プレイヤーへの参照を取得
			var projectile_owner: Node2D = attacker.owner_character
			if projectile_owner:
				# プレイヤーの方向を計算
				var direction_to_player: float = sign(projectile_owner.global_position.x - enemy.global_position.x)
				if direction_to_player != 0:
					direction_to_face_after_knockback = direction_to_player

	# ダメージとスタンの適用判定
	var actual_damage: int = damage
	var should_apply_stun: bool = false

	if attacker and attacker is Projectile:
		var projectile: Projectile = attacker as Projectile
		if projectile.applies_stun_effect:
			# スタンエフェクトが有効な場合はダメージなし、スタンあり
			actual_damage = 0
			should_apply_stun = true
		else:
			# スタンエフェクトが無効な場合は通常ダメージ、スタンなし
			should_apply_stun = false
	elif attacker and attacker.name == "FightingHitbox":
		# FightingHitbox攻撃：ダメージあり、スタンなし
		should_apply_stun = false
	else:
		# その他の攻撃：ダメージあり、スタンあり（デフォルト動作）
		should_apply_stun = true

	# 共通処理：ダメージを適用（スタンエフェクト以外）
	current_hp -= actual_damage

	# 敵のスタンフラグを設定
	enemy.should_stun_after_knockback = should_apply_stun

	# HPゲージを更新（ダメージがある場合のみ）
	if actual_damage > 0:
		_update_hp_gauge()

	# HPが0以下になったら死亡処理
	if current_hp <= 0:
		_die(direction, attacker, false)  # 通常の死亡
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

## ノックバック速度を計算（共通処理）
func _calculate_knockback_velocity(direction: Vector2, attacker: Node) -> Vector2:
	var vertical_force: float = -100.0
	var force_multiplier: float = 1.0

	# FightingHitboxからの攻撃の場合、2倍の力と強い垂直力
	if attacker and attacker.name == "FightingHitbox":
		force_multiplier = 2.0
		vertical_force = -150.0

	# KnockbackComponentを使用してノックバック速度を計算
	return KnockbackComponent.calculate_knockback_velocity(
		direction,
		knockback_force,
		vertical_force,
		force_multiplier
	)

## ノックバックを適用
func _apply_knockback(direction: Vector2, attacker: Node) -> void:
	# ノックバック速度を計算
	knockback_velocity = _calculate_knockback_velocity(direction, attacker)

	# シグナルを発信
	knockback_applied.emit(knockback_velocity, direction_to_face_after_knockback)

## 死亡処理
func _die(direction: Vector2, attacker: Node, is_instant_kill: bool) -> void:
	# 敵への参照を取得
	var enemy: Enemy = enemy_ref.get_ref() as Enemy
	if not enemy:
		return

	# HPゲージを非表示
	if hp_gauge:
		hp_gauge.hide_gauge()

	# ノックバック速度を計算（死亡演出で使用）
	var death_knockback_velocity: Vector2 = _calculate_knockback_velocity(direction, attacker)

	# シグナルを発信（ノックバック速度と即死フラグを含む）
	died.emit(death_knockback_velocity, is_instant_kill)

## HPゲージを作成
func _create_hp_gauge() -> void:
	# 敵への参照を取得
	var enemy: Enemy = enemy_ref.get_ref() as Enemy
	if not enemy:
		return

	# health_gauge.gdのインスタンスを作成（プレイヤーと同じゲージを使用）
	var HealthGaugeScript: Script = preload("res://scripts/ui/health_gauge.gd")
	hp_gauge = HealthGaugeScript.new()
	hp_gauge.name = "HPGauge"

	# 敵用のプリセット設定を適用
	hp_gauge.setup_for_enemy()

	# HPの初期値を設定
	hp_gauge.hp_progress = float(current_hp) / float(max_hp)

	enemy.add_child(hp_gauge)

## HPゲージを更新
func _update_hp_gauge() -> void:
	if not hp_gauge:
		return
	# HP進行度を更新
	hp_gauge.hp_progress = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	# ゲージを表示してフェードタイマーをリセット
	hp_gauge.show_gauge()

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# HPゲージを削除
	if hp_gauge and is_instance_valid(hp_gauge):
		hp_gauge.queue_free()
	hp_gauge = null

	# 参照をクリア
	enemy_ref = null

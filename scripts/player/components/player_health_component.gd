class_name PlayerHealthComponent
extends RefCounted

# ======================== 定数定義 ========================

## デフォルト最大HP（全体で統一）
const DEFAULT_MAX_HP: int = 50

# ======================== シグナル定義 ========================

## HP変更時のシグナル（現在HP、最大HP）
signal health_changed(current_hp: int, max_hp: int)

# ======================== 変数定義 ========================

## 現在のHP
var current_hp: int = DEFAULT_MAX_HP
## 最大HP
var max_hp: int = DEFAULT_MAX_HP

## プレイヤーへの弱参照（メモリリーク防止）
var _player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## HealthComponentの初期化
## @param player プレイヤーインスタンス
## @param initial_hp 初期HP
## @param initial_max_hp 最大HP
func initialize(player: CharacterBody2D, initial_hp: int, initial_max_hp: int) -> void:
	_player_ref = weakref(player)
	current_hp = initial_hp
	max_hp = initial_max_hp
	health_changed.emit(current_hp, max_hp)

# ======================== 無敵状態チェック ========================

## 無敵状態の確認（InvincibilityEffect と PlayerDownState を統合）
## @return bool 無敵状態かどうか
func is_invincible() -> bool:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return false

	# InvincibilityEffectの無敵チェック
	if player.invincibility_effect and player.invincibility_effect.is_invincible:
		return true

	# DownStateの無敵チェック
	if player.down_state and player.down_state.is_in_invincible_state():
		return true

	return false

# ======================== ダメージ処理 ========================

## ダメージを適用（HP減少とシグナル発信を一元管理）
## @param damage ダメージ量
func apply_damage(damage: int) -> void:
	if damage <= 0:
		return

	current_hp -= damage
	health_changed.emit(current_hp, max_hp)

## トラップ効果処理（1ダメージ + effect_typeに応じてknockback/down）
## @param effect_type トラップの効果タイプ（"knockback" or "down"）
## @param direction ノックバック方向ベクトル
## @param knockback_force ノックバック力
func handle_trap_damage(effect_type: String, direction: Vector2, knockback_force: float) -> void:
	if is_invincible():
		return

	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# ダメージ量を計算（HP1を保証）
	var damage_amount: int = 1 if current_hp > 1 else 0

	# DownStateへの委譲（ダメージ処理と効果をunified）
	if player.down_state:
		player.down_state.handle_damage(damage_amount, effect_type, direction, knockback_force)

## 敵接触ダメージ処理
## @param enemy_direction 敵からの方向ベクトル
## @param damage ダメージ量（デフォルト: 1）
## @return bool ダメージを受けたかどうか
func handle_enemy_hit(enemy_direction: Vector2, damage: int = 1) -> bool:
	if is_invincible():
		return false

	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return false

	# DownState中のノックバックは無視
	if player.down_state:
		if player.down_state.is_in_knockback_state() or player.down_state.is_in_knockback_landing_state():
			return false

	# DownStateへの委譲（ダメージ処理と効果をunified）
	if player.down_state:
		player.down_state.handle_damage(damage, "knockback", enemy_direction, 500.0)

	return true

# ======================== 回復処理 ========================

## HP回復処理
## @param amount 回復量
func heal_hp(amount: int) -> void:
	var old_hp: int = current_hp
	current_hp = mini(current_hp + amount, max_hp)

	if current_hp != old_hp:
		health_changed.emit(current_hp, max_hp)

# ======================== Setter/Getter ========================

## HPを設定（状態復元時に使用）
## @param value 設定するHP値
func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp)
	health_changed.emit(current_hp, max_hp)

# ======================== クリーンアップ ========================

## クリーンアップ処理
func cleanup() -> void:
	_player_ref = null

class_name InvincibilityEffect
extends RefCounted

# ======================== プレイヤー参照 ========================

var player: CharacterBody2D

# ======================== 無敵エフェクト管理変数 ========================

var is_invincible: bool = false
var invincibility_timer: float = 0.0
var blink_timer: float = 0.0
var blink_interval: float = 0.1
var is_visible: bool = true

# ======================== 初期化 ========================

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance

# ======================== 無敵エフェクト制御 ========================

## 無敵状態の設定
func set_invincible(duration: float) -> void:
	is_invincible = true
	invincibility_timer = duration
	blink_timer = 0.0

## 無敵状態の解除
func clear_invincible() -> void:
	is_invincible = false
	invincibility_timer = 0.0
	blink_timer = 0.0
	is_visible = true
	_restore_sprite_visibility()

## 無敵エフェクトの更新
func update_invincibility_effect(delta: float) -> void:
	if not is_invincible:
		return

	# 無敵タイマー更新
	invincibility_timer -= delta
	if invincibility_timer <= 0.0:
		clear_invincible()
		return

	# 点滅エフェクト更新
	blink_timer += delta
	if blink_timer >= blink_interval:
		blink_timer = 0.0
		is_visible = not is_visible
		_update_sprite_visibility()

# ======================== プライベートメソッド ========================

## スプライトの可視性を更新（点滅エフェクト用）
func _update_sprite_visibility() -> void:
	if player.sprite_2d:
		# 半透明にすることで点滅効果を実現
		player.sprite_2d.modulate.a = 0.3 if not is_visible else 1.0

## スプライトの可視性を完全に復元
func _restore_sprite_visibility() -> void:
	if player.sprite_2d:
		player.sprite_2d.modulate.a = 1.0
class_name InvincibilityEffect
extends RefCounted

# プレイヤーの無敵状態時の点滅エフェクト専用クラス
# player_damaged.is_in_invincible_state()に基づく自動点滅制御

var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var condition: Player.PLAYER_CONDITION

# 点滅パラメータ
var blink_frequency: float = 10.0
var blink_min_alpha: float = 0.3
var blink_max_alpha: float = 1.0

# 状態管理
var blink_timer: float = 0.0
var is_blinking: bool = false
var original_modulate: Color = Color.WHITE

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	original_modulate = animated_sprite.modulate

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

func update_invincibility_effect(delta: float) -> void:
	blink_timer += delta

	if player.player_damaged.is_in_invincible_state():
		if not is_blinking:
			is_blinking = true
			blink_timer = 0.0

		# sinカーブによる点滅
		var blink_alpha: float = (sin(blink_timer * PI * blink_frequency) + 1.0) / 2.0
		var final_alpha: float = blink_min_alpha + (blink_alpha * (blink_max_alpha - blink_min_alpha))
		animated_sprite.modulate.a = final_alpha
	else:
		if is_blinking:
			is_blinking = false
			animated_sprite.modulate.a = original_modulate.a

func reset_invincibility_state() -> void:
	is_blinking = false
	animated_sprite.modulate.a = original_modulate.a
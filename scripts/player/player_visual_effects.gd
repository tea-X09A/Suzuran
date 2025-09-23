class_name PlayerVisualEffects
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# 視覚効果関連パラメータの定義 (基本仕様として固定)
var blink_frequency: float = 10.0              # 点滅の周波数（Hz）
var blink_min_alpha: float = 0.3               # 点滅時の最小透明度
var blink_max_alpha: float = 1.0               # 点滅時の最大透明度
var damage_flash_duration: float = 0.1         # ダメージフラッシュ持続時間（秒）
var damage_flash_color: Color = Color.RED      # ダメージフラッシュの色

# エフェクトタイマー
var blink_timer: float = 0.0
var damage_flash_timer: float = 0.0
var screen_shake_timer: float = 0.0

# エフェクト状態
var is_blinking: bool = false
var is_damage_flashing: bool = false
var original_modulate: Color = Color.WHITE

# カスタムエフェクト
var custom_effects: Dictionary = {}

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	original_modulate = animated_sprite.modulate

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# ======================== メイン視覚効果更新 ========================

func update_visual_effects(delta: float) -> void:
	_update_blink_effect(delta)
	_update_damage_flash(delta)
	_update_custom_effects(delta)

func _update_blink_effect(delta: float) -> void:
	blink_timer += delta

	if player.player_damaged.is_in_invincible_state():
		if not is_blinking:
			_start_blink_effect()

		# 無敵状態時の点滅効果（sinカーブ）
		var frequency: float = blink_frequency
		var min_alpha: float = blink_min_alpha
		var max_alpha: float = blink_max_alpha

		var blink_alpha: float = (sin(blink_timer * PI * frequency) + 1.0) / 2.0
		var final_alpha: float = min_alpha + (blink_alpha * (max_alpha - min_alpha))
		animated_sprite.modulate.a = final_alpha
	else:
		if is_blinking:
			_stop_blink_effect()

func _start_blink_effect() -> void:
	is_blinking = true
	blink_timer = 0.0

func _stop_blink_effect() -> void:
	is_blinking = false
	animated_sprite.modulate.a = original_modulate.a

# ======================== ダメージフラッシュ効果 ========================

func _update_damage_flash(delta: float) -> void:
	if is_damage_flashing:
		damage_flash_timer -= delta

		if damage_flash_timer <= 0.0:
			_stop_damage_flash()
		else:
			# フラッシュ効果の強度を時間に応じて減衰
			var flash_intensity: float = damage_flash_timer / damage_flash_duration
			var flash_color: Color = damage_flash_color
			var current_color: Color = original_modulate.lerp(flash_color, flash_intensity)
			animated_sprite.modulate = current_color

func start_damage_flash() -> void:
	is_damage_flashing = true
	damage_flash_timer = damage_flash_duration

func _stop_damage_flash() -> void:
	is_damage_flashing = false
	if not is_blinking:
		animated_sprite.modulate = original_modulate

func is_damage_flash_active() -> bool:
	return is_damage_flashing

# ======================== スケール効果 ========================

func apply_scale_effect(scale_factor: Vector2, duration: float) -> void:
	var tween: Tween = player.create_tween()
	var original_scale: Vector2 = animated_sprite.scale

	tween.tween_property(animated_sprite, "scale", scale_factor, duration * 0.3)
	tween.tween_property(animated_sprite, "scale", original_scale, duration * 0.7)

func apply_bounce_effect(bounce_strength: float = 1.2, duration: float = 0.2) -> void:
	apply_scale_effect(Vector2(bounce_strength, bounce_strength), duration)

func apply_squash_effect(squash_factor: Vector2 = Vector2(1.3, 0.7), duration: float = 0.15) -> void:
	apply_scale_effect(squash_factor, duration)

# ======================== 色調効果 ========================

func apply_color_tint(color: Color, duration: float) -> void:
	var tween: Tween = player.create_tween()
	var current_color: Color = animated_sprite.modulate

	tween.tween_property(animated_sprite, "modulate", color, duration * 0.3)
	tween.tween_property(animated_sprite, "modulate", current_color, duration * 0.7)

func fade_to_alpha(target_alpha: float, duration: float) -> void:
	var tween: Tween = player.create_tween()
	tween.tween_property(animated_sprite, "modulate:a", target_alpha, duration)

func reset_visual_state() -> void:
	# 全ての視覚効果をリセット
	is_blinking = false
	is_damage_flashing = false
	animated_sprite.modulate = original_modulate
	animated_sprite.scale = Vector2.ONE

# ======================== カスタム視覚効果 ========================

func _update_custom_effects(delta: float) -> void:
	for effect_name in custom_effects.keys():
		var effect_data: Dictionary = custom_effects[effect_name]
		effect_data.timer -= delta

		if effect_data.timer <= 0.0:
			_remove_custom_effect(effect_name)
		else:
			_update_custom_effect(effect_name, effect_data)

func add_custom_effect(name: String, duration: float, effect_data: Dictionary) -> void:
	custom_effects[name] = {
		"timer": duration,
		"duration": duration,
		"data": effect_data
	}

func _update_custom_effect(name: String, effect_data: Dictionary) -> void:
	# カスタムエフェクトの更新ロジックをここに実装
	var progress: float = 1.0 - (effect_data.timer / effect_data.duration)

	match name:
		"glow":
			_update_glow_effect(progress, effect_data.data)
		"shake":
			_update_shake_effect(progress, effect_data.data)
		"pulse":
			_update_pulse_effect(progress, effect_data.data)

func _update_glow_effect(progress: float, data: Dictionary) -> void:
	var glow_intensity: float = sin(progress * PI * 4.0) * data.get("intensity", 0.5)
	animated_sprite.modulate = original_modulate + Color(glow_intensity, glow_intensity, glow_intensity, 0.0)

func _update_shake_effect(progress: float, data: Dictionary) -> void:
	var shake_strength: float = data.get("strength", 2.0) * (1.0 - progress)
	var offset: Vector2 = Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)
	animated_sprite.position = offset

func _update_pulse_effect(progress: float, data: Dictionary) -> void:
	var pulse_scale: float = 1.0 + sin(progress * PI * 6.0) * data.get("scale", 0.1)
	animated_sprite.scale = Vector2(pulse_scale, pulse_scale)

func _remove_custom_effect(name: String) -> void:
	custom_effects.erase(name)

	# エフェクト終了時のクリーンアップ
	match name:
		"glow":
			animated_sprite.modulate = original_modulate
		"shake":
			animated_sprite.position = Vector2.ZERO
		"pulse":
			animated_sprite.scale = Vector2.ONE

# ======================== 視覚効果情報取得 ========================

func get_visual_effects_info() -> Dictionary:
	return {
		"is_blinking": is_blinking,
		"is_damage_flashing": is_damage_flashing,
		"blink_timer": blink_timer,
		"damage_flash_timer": damage_flash_timer,
		"current_modulate": animated_sprite.modulate,
		"current_scale": animated_sprite.scale,
		"custom_effects_count": custom_effects.size(),
		"active_custom_effects": custom_effects.keys()
	}
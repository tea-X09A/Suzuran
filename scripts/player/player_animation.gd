class_name PlayerAnimation
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# アニメーション関連パラメータの定義
# アニメーション名プレフィックス（conditionに依存）
var animation_prefix_map: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: "normal",
	Player.PLAYER_CONDITION.EXPANSION: "expansion"
}

# 基本仕様として固定のパラメータ
var animation_speed_scale: float = 1.0     # アニメーション速度倍率

# 現在のアニメーション名（重複再生を避けるため）
var current_animation: String = ""

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition
	# 条件変更時にアニメーションを再評価
	update_animation()

# =====================================================
# アニメーション更新
# =====================================================

func update_animation() -> void:
	var animation_name: String = _get_animation_name()
	if animation_name != "" and animation_name != current_animation:
		_play_animation(animation_name)

func _play_animation(animation_name: String) -> void:
	current_animation = animation_name
	animated_sprite.play(animation_name)

	# アニメーション速度を調整
	animated_sprite.speed_scale = animation_speed_scale

func _get_animation_name() -> String:
	var condition_prefix: String = _get_condition_prefix()

	match player.state:
		Player.PLAYER_STATE.IDLE:
			return condition_prefix + "_idle"
		Player.PLAYER_STATE.WALK:
			return condition_prefix + "_walk"
		Player.PLAYER_STATE.RUN:
			return condition_prefix + "_run"
		Player.PLAYER_STATE.JUMP:
			return condition_prefix + "_jump"
		Player.PLAYER_STATE.FALL:
			return condition_prefix + "_fall"
		Player.PLAYER_STATE.SQUAT:
			return condition_prefix + "_squat"
		Player.PLAYER_STATE.DAMAGED:
			return condition_prefix + "_damaged"
		Player.PLAYER_STATE.FIGHTING, Player.PLAYER_STATE.SHOOTING:
			return ""  # これらは専用モジュールで管理
		_:
			return ""

func _get_condition_prefix() -> String:
	return animation_prefix_map[condition]

# =====================================================
# アニメーション制御
# =====================================================

func force_animation(animation_name: String) -> void:
	# 強制的にアニメーションを再生（現在のアニメーションと同じでも再生）
	current_animation = animation_name
	animated_sprite.play(animation_name)

func stop_animation() -> void:
	animated_sprite.stop()
	current_animation = ""

func pause_animation() -> void:
	animated_sprite.pause()

func resume_animation() -> void:
	animated_sprite.play()

func set_animation_speed(speed: float) -> void:
	animated_sprite.speed_scale = speed

func reset_animation_speed() -> void:
	animated_sprite.speed_scale = animation_speed_scale

# =====================================================
# スプライト制御
# =====================================================

func flip_sprite_horizontal(flip: bool) -> void:
	animated_sprite.flip_h = flip

func flip_sprite_vertical(flip: bool) -> void:
	animated_sprite.flip_v = flip

func set_sprite_modulate(color: Color) -> void:
	animated_sprite.modulate = color

func get_sprite_modulate() -> Color:
	return animated_sprite.modulate

func set_sprite_alpha(alpha: float) -> void:
	animated_sprite.modulate.a = alpha

func get_sprite_alpha() -> float:
	return animated_sprite.modulate.a

# =====================================================
# アニメーション情報取得
# =====================================================

func get_current_animation() -> String:
	return current_animation

func is_playing() -> bool:
	return animated_sprite.is_playing()

func get_animation_progress() -> float:
	if not is_playing():
		return 0.0
	return animated_sprite.frame / float(animated_sprite.sprite_frames.get_frame_count(current_animation))

func get_current_frame() -> int:
	return animated_sprite.frame

func get_frame_count() -> int:
	if current_animation == "":
		return 0
	return animated_sprite.sprite_frames.get_frame_count(current_animation)

# =====================================================
# アニメーション状態チェック
# =====================================================

func has_animation(animation_name: String) -> bool:
	return animated_sprite.sprite_frames.has_animation(animation_name)

func is_animation_finished() -> bool:
	return not is_playing()

func get_animation_info() -> Dictionary:
	return {
		"current_animation": current_animation,
		"is_playing": is_playing(),
		"current_frame": get_current_frame(),
		"frame_count": get_frame_count(),
		"progress": get_animation_progress(),
		"speed_scale": animated_sprite.speed_scale,
		"condition_prefix": _get_condition_prefix()
	}
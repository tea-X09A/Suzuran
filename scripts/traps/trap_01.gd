class_name Trap01
extends StaticBody2D

# プレイヤーに与えるダメージ量（整数値）
@export var damage: int = 10
# 再生するダメージアニメーションの種類（アニメーション名）
@export var animation_type: String = "damaged"
# プレイヤーをノックバックさせる力の強さ（ピクセル/秒）
@export var knockback_force: float = 300.0

# ノード参照をキャッシュ
@onready var hitbox: Area2D = $Hitbox
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# 処理が有効かどうかのフラグ
var processing_enabled: bool = false
# ダメージ実行のクールダウン時間
var damage_cooldown: float = 0.5
var last_damage_time: float = 0.0

# デバッグ用フラグ
@export var debug_enabled: bool = false
# デバッグ出力間隔（秒）
@export var debug_output_interval: float = 1.0
var last_debug_time: float = 0.0

func _ready() -> void:
	# trapsグループに追加
	add_to_group("traps")

	# VisibleOnScreenEnabler2Dのシグナルに接続してカメラ範囲内外の状態を監視
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	if not processing_enabled:
		return

	# デバッグ出力（カメラ範囲内にいる場合のフレームごと監視）
	if debug_enabled:
		_output_frame_debug()

	_check_player_collision()

func _check_player_collision() -> void:
	if not hitbox:
		if debug_enabled:
			_log_debug("hitboxが見つかりません")
		return

	# クールダウン中は処理しない
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_damage_time < damage_cooldown:
		return

	# プレイヤーとの重なりをチェック
	var overlapping_bodies: Array[Node2D] = hitbox.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body.is_in_group("player"):
			if debug_enabled:
				_log_debug("プレイヤー検知！ダメージを適用中...")
			_apply_damage_to_player(body)
			last_damage_time = current_time
			break

	if debug_enabled and overlapping_bodies.size() > 0:
		_log_debug("重なりボディ数: " + str(overlapping_bodies.size()))

func _apply_damage_to_player(player: Node2D) -> void:
	# プレイヤーにダメージを適用
	if player.has_method("take_damage"):
		# ノックバック方向を計算（トラップからプレイヤーへの方向）
		var knockback_direction: Vector2 = (player.global_position - global_position).normalized()

		if debug_enabled:
			_log_debug("プレイヤーにダメージ適用: " + str(damage) + " (ノックバック: " + str(knockback_force) + ")")
			# プレイヤーの無敵状態をチェック
			if player.has_method("get_current_damaged"):
				var damaged_module = player.get_current_damaged()
				if damaged_module.has_method("is_in_invincible_state"):
					var is_invincible: bool = damaged_module.is_in_invincible_state()
					_log_debug("プレイヤー無敵状態: " + str(is_invincible))

		player.take_damage(damage, animation_type, knockback_direction, knockback_force)
	else:
		if debug_enabled:
			_log_debug("ERROR: プレイヤーにtake_damageメソッドがありません")

# VisibleOnScreenEnabler2Dのシグナルハンドラ
func _on_screen_entered() -> void:
	processing_enabled = true
	if debug_enabled:
		_log_debug("カメラ範囲に入りました - 処理開始")

func _on_screen_exited() -> void:
	processing_enabled = false
	if debug_enabled:
		_log_debug("カメラ範囲から出ました - 処理停止")

func get_damage() -> int:
	return damage

func get_knockback_force() -> float:
	return knockback_force

func get_effect_type() -> String:
	return "damage"

# =====================================================
# デバッグ機能
# =====================================================

func _output_frame_debug() -> void:
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_debug_time < debug_output_interval:
		return

	last_debug_time = current_time

	if not hitbox:
		_log_debug("ERROR: hitboxが見つかりません")
		return

	# 現在重なっているボディをチェック
	var overlapping_bodies: Array[Node2D] = hitbox.get_overlapping_bodies()
	var player_detected: bool = false

	for body in overlapping_bodies:
		if body.is_in_group("player"):
			player_detected = true
			break

	# 現在重なっているエリアもチェック（プレイヤーのhurtboxなど）
	var overlapping_areas: Array[Area2D] = hitbox.get_overlapping_areas()
	var hurtbox_detected: bool = false

	for area in overlapping_areas:
		if "hurtbox" in area.name.to_lower() or area.is_in_group("player_hurtbox"):
			hurtbox_detected = true
			break

	# サマリー出力
	_log_debug("監視状況: プレイヤー=" + str(player_detected) + " hurtbox=" + str(hurtbox_detected) + " bodies=" + str(overlapping_bodies.size()) + " areas=" + str(overlapping_areas.size()))

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[Trap01] " + message)

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled

func is_debug_enabled() -> bool:
	return debug_enabled

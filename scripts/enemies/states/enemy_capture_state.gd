## エネミーがプレイヤーをキャプチャしている状態
## プレイヤーと接触したエネミーのみがこの状態になり、重力を適用して着地する
class_name EnemyCaptureState
extends EnemyBaseState

# ======================== 変数定義 ========================

## 着地したかどうかのフラグ
var has_landed: bool = false

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	if not enemy:
		return

	# 着地フラグをリセット
	has_landed = false

	# 移動を停止
	enemy.velocity.x = 0.0

	# hitboxを無効化・非表示
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		hitbox.visible = false

	# detection_areaを無効化・非表示
	if detection_area:
		detection_area.set_deferred("monitoring", false)
		detection_area.visible = false

## ステート終了時の処理
func cleanup_state() -> void:
	if not enemy:
		return

	# 着地フラグをリセット
	has_landed = false

	# detection_areaのvisibleを復元
	if detection_area:
		detection_area.visible = true

	# 画面内の場合のみmonitoringを再有効化
	if enemy.on_screen:
		if detection_area:
			detection_area.set_deferred("monitoring", true)

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	if not enemy:
		return

	# プレイヤーの状態をチェック
	var player: Node2D = get_player()
	if player:
		# プレイヤーがCAPTURE状態でなくなった場合、エネミーもIDLE状態に戻る
		if player.has_method("get_current_state_name"):
			var player_state: String = player.get_current_state_name()
			if player_state != "CAPTURE":
				# キャプチャ状態終了を通知
				if enemy.capture_component:
					enemy.capture_component.exit_capture_state()
				# プレイヤー検知をクリア（キャプチャ終了後に即座に追跡しないようにする）
				if enemy.detection_component:
					enemy.detection_component.clear_player()
				# IDLE状態に遷移
				enemy.change_state("IDLE")
				return

	# 着地後は動かない
	if has_landed:
		enemy.velocity.x = 0.0
		enemy.velocity.y = 0.0
		return

	# 移動を停止
	enemy.velocity.x = 0.0

	# 重力を適用
	apply_gravity(delta)

	# 着地したかチェック
	if enemy.is_on_floor():
		has_landed = true
		enemy.velocity.y = 0.0

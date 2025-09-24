class_name DamagedState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.DAMAGED
	player.is_damaged = true

func process_physics(delta: float) -> void:
	# ダメージが終了したかチェック（Player.gdのis_damagedフラグで判定）
	if not player.is_damaged:
		# ダメージ終了後は適切な状態に遷移
		if player.is_on_floor():
			var direction_x: float = Input.get_axis("left", "right")
			if direction_x == 0:
				player.change_state("idle")
			else:
				var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
				if shift_pressed:
					player.change_state("run")
				else:
					player.change_state("walk")
		else:
			# 空中にいる場合は落下状態に遷移
			if player.velocity.y >= 0:
				player.change_state("fall")
			else:
				player.change_state("jump")
		return

	# ノックバック着地状態の場合は限定的な移動を許可
	if player.get_current_damaged().is_in_knockback_landing_state():
		var direction_x: float = Input.get_axis("left", "right")
		player.direction_x = direction_x
		# ダメージ中の制限された移動処理
		player.get_current_movement().handle_movement(direction_x, false, false)

func exit() -> void:
	player.is_damaged = false
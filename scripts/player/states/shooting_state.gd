class_name ShootingState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.SHOOTING
	# 射撃処理を開始（Player.gdのhandle_shooting()を使用）
	player.handle_shooting()

func process_physics(delta: float) -> void:
	# 射撃が終了したかチェック（Player.gdのis_shootingフラグで判定）
	if not player.is_shooting:
		# 射撃終了後は適切な状態に遷移
		if player.is_on_floor():
			var direction_x: float = Input.get_axis("left", "right")
			if direction_x == 0:
				player.change_state("idle")
			else:
				var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
				if shift_pressed and player.is_running:
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

	# 射撃中のバックジャンプ射撃対応
	if Input.is_action_just_pressed("back_jump_shooting"):
		player.handle_back_jump_shooting()
		return

	# 射撃中でも戦闘アクションへの遷移は可能
	if Input.is_action_just_pressed("fighting"):
		player.change_state("fighting")
		return

func exit() -> void:
	pass
class_name FightingState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.FIGHTING
	# 戦闘処理を開始（Player.gdのhandle_fighting()を使用）
	player.handle_fighting()

func process_physics(delta: float) -> void:
	# 戦闘が終了したかチェック（Player.gdのis_fightingフラグで判定）
	if not player.is_fighting:
		# 戦闘終了後は適切な状態に遷移
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

	# 戦闘中でも他のアクションへの遷移は可能
	if Input.is_action_just_pressed("shooting"):
		player.change_state("shooting")
		return

func exit() -> void:
	pass
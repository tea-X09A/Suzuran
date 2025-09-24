class_name BaseState
extends RefCounted

var player: CharacterBody2D

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance

func enter() -> void:
	pass

func exit() -> void:
	pass

func process_physics(delta: float) -> void:
	pass

func process_frame(delta: float) -> void:
	pass

func handle_input(event: InputEvent) -> void:
	pass
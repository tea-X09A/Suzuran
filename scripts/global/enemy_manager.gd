class_name EnemyManager
## エネミー全体を制御するユーティリティクラス
##
## このクラスは静的メソッドのみを提供し、全エネミーの一括制御を行います。
## CAPTURE状態やその他のゲームイベント時に、エネミーの動作を一時的に
## 停止/再開する際に使用します。

# ======================== 公開メソッド（全エネミー制御） ========================

## 全てのエネミーを無効化（非表示・動作停止）します
static func disable_all_enemies(scene_tree: SceneTree) -> void:
	var enemies: Array[Node] = scene_tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("disable"):
			enemy.disable()


## 全てのエネミーを有効化（表示・動作再開）します
static func enable_all_enemies(scene_tree: SceneTree) -> void:
	var enemies: Array[Node] = scene_tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("enable"):
			enemy.enable()

# ======================== 公開メソッド（個別エネミー制御） ========================

## 特定のエネミーを無効化します
##
## @param enemy: 無効化するエネミーノード
static func disable_enemy(enemy: Node) -> void:
	if enemy.has_method("disable"):
		enemy.disable()


## 特定のエネミーを有効化します
##
## @param enemy: 有効化するエネミーノード
static func enable_enemy(enemy: Node) -> void:
	if enemy.has_method("enable"):
		enemy.enable()

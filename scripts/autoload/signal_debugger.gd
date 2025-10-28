## シグナル接続のデバッグとトラッキングを行うAutoLoad
## ゲーム内の全てのシグナル接続を監視し、メモリリークの検出を支援する
extends Node

# ======================== データ構造 ========================
## シグナル接続情報を保存する辞書
## 構造: { object_id: { "object": weakref, "object_name": String, "signals": { signal_name: Array[ConnectionInfo] } } }
var signal_connections: Dictionary = {}

## 接続情報の型定義
class ConnectionInfo:
	var callable_string: String
	var target_name: String
	var timestamp: int

	func _init(callable_str: String, target: String, time: int) -> void:
		callable_string = callable_str
		target_name = target
		timestamp = time

# ======================== 初期化処理 ========================
func _ready() -> void:
	## ポーズ中でも動作するように設定
	process_mode = Node.PROCESS_MODE_ALWAYS

# ======================== レポート生成 ========================
## シグナル接続のレポートを生成する
## @return リークしているオブジェクトの情報を含む辞書
func get_signal_report() -> Dictionary:
	var report: Dictionary = {
		"leaked_objects": 0,
		"objects": []
	}

	## 全オブジェクトを走査
	for object_id in signal_connections.keys():
		var obj_data: Dictionary = signal_connections[object_id]
		var obj_weak: WeakRef = obj_data["object"]
		var obj_ref: Object = obj_weak.get_ref()

		var is_leaked: bool = (obj_ref == null)

		## オブジェクト情報を追加
		report["objects"].append({
			"object_id": object_id,
			"object_name": obj_data["object_name"],
			"is_leaked": is_leaked,
			"signals": obj_data["signals"]
		})

		if is_leaked:
			report["leaked_objects"] += 1

	return report

## 全てのトラッキング情報をクリアする
func clear_all() -> void:
	signal_connections.clear()

## 解放されたオブジェクトのエントリをクリーンアップする
## @return クリーンアップされたオブジェクト数
func cleanup_freed_objects() -> int:
	var cleaned_count: int = 0
	var object_ids_to_remove: Array[int] = []

	## 解放済みのオブジェクトIDを収集
	for object_id in signal_connections.keys():
		var obj_data: Dictionary = signal_connections[object_id]
		var obj_weak: WeakRef = obj_data["object"]
		var obj_ref: Object = obj_weak.get_ref()

		## オブジェクトが解放されている場合は削除対象
		if obj_ref == null:
			object_ids_to_remove.append(object_id)
			cleaned_count += 1

	## 削除対象のエントリを削除
	for object_id in object_ids_to_remove:
		signal_connections.erase(object_id)

	return cleaned_count

## 現在のシーンツリーから全てのシグナル接続を自動収集する
func scan_scene_tree() -> void:
	signal_connections.clear()
	var root: Node = get_tree().root
	_scan_node_recursive(root)

## ノードを再帰的にスキャンしてシグナル接続を収集
func _scan_node_recursive(node: Node) -> void:
	if not node:
		return

	## ノードが持つ全てのシグナルを取得
	var signal_list: Array = node.get_signal_list()

	for signal_info in signal_list:
		var signal_name: String = signal_info["name"]
		var connections: Array = node.get_signal_connection_list(signal_name)

		## 接続がある場合のみ記録
		if connections.size() > 0:
			var object_id: int = node.get_instance_id()

			## オブジェクトIDが未登録の場合、新規作成
			if not signal_connections.has(object_id):
				signal_connections[object_id] = {
					"object": weakref(node),
					"object_name": _get_object_name(node),
					"signals": {}
				}

			var obj_data: Dictionary = signal_connections[object_id]

			## シグナル名が未登録の場合、配列を作成
			if not obj_data["signals"].has(signal_name):
				obj_data["signals"][signal_name] = []

			## 各接続を記録
			for conn in connections:
				var callable: Callable = conn["callable"]
				var connection_info: ConnectionInfo = ConnectionInfo.new(
					str(callable),
					_get_callable_target_name(callable),
					Time.get_ticks_msec()
				)
				obj_data["signals"][signal_name].append(connection_info)

	## 子ノードを再帰的にスキャン
	for child in node.get_children():
		_scan_node_recursive(child)

# ======================== ヘルパー関数 ========================
## オブジェクトの名前を取得する
## @param object 対象のオブジェクト
## @return オブジェクト名（ノードの場合はパス、それ以外はクラス名）
func _get_object_name(object: Object) -> String:
	if object is Node:
		var node: Node = object as Node
		if node.is_inside_tree():
			return node.get_path()
		else:
			return node.name
	else:
		return object.get_class()

## Callableのターゲット名を取得する
## @param callable 対象の Callable
## @return Callableのターゲット名
func _get_callable_target_name(callable: Callable) -> String:
	var object: Object = callable.get_object()
	if object:
		return _get_object_name(object)
	else:
		return "Unknown"

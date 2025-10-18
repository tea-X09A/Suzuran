class_name EventConfigData
extends Resource

## 全イベント設定の一括管理リソース
##
## 全てのEventConfigを配列で保持し、event_idによる検索と
## 実行回数に応じたDialogueDataパスの取得機能を提供します。

# ======================== エクスポートプロパティ ========================

## イベント設定の配列
@export var events: Array[EventConfig] = []

# ======================== 公開メソッド ========================

## event_idでEventConfigを取得
##
## @param event_id String イベント識別子
## @return EventConfig 該当するイベント設定（存在しない場合はnull）
func get_event_config(event_id: String) -> EventConfig:
	for event_config: EventConfig in events:
		if event_config.event_id == event_id:
			return event_config

	push_warning("EventConfigData: Event config not found for event_id: " + event_id)
	return null

## 実行回数に応じたDialogueDataパスを取得
##
## @param event_id String イベント識別子
## @param count int 実行回数（0が初回）
## @return String DialogueDataリソースパス（見つからない場合は空文字列）
func get_dialogue_resource(event_id: String, count: int) -> String:
	var event_config: EventConfig = get_event_config(event_id)

	if event_config == null:
		return ""

	# dialogue_resourcesが空の場合
	if event_config.dialogue_resources.is_empty():
		push_warning("EventConfigData: No dialogue resources defined for event_id: " + event_id)
		return ""

	# countが配列範囲内の場合はその要素を返す
	if count < event_config.dialogue_resources.size():
		return event_config.dialogue_resources[count]

	# 範囲外の場合は最後の要素を返す（リピート用）
	return event_config.dialogue_resources[event_config.dialogue_resources.size() - 1]

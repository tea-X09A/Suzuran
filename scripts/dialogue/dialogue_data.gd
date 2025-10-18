class_name DialogueData
extends Resource

## 会話データ定義リソース
##
## 会話イベントで使用する全ての情報を保持します。
## 多言語対応（日本語/英語）をサポートし、選択肢分岐やプレイヤー状態による条件分岐が可能です。
## sow.mdの要件に基づいて実装されています。

# ======================== リソースプロパティ ========================

## 登場キャラクター定義配列
@export var characters: Array[DialogueCharacterInfo] = []

## 会話メッセージ配列
@export var messages: Array[DialogueMessage] = []

## テキスト表示速度（秒単位、1文字あたりの表示時間）
@export var text_speed: float = 0.05

# ======================== 公開メソッド ========================

## キャラクター情報を取得
##
## @param character_id String キャラクター識別子
## @return DialogueCharacterInfo キャラクター情報（見つからない場合はnull）
func get_character_info(character_id: String) -> DialogueCharacterInfo:
	for character in characters:
		if character.character_id == character_id:
			return character
	return null

## メッセージを取得
##
## @param index String メッセージインデックス
## @return DialogueMessage メッセージ情報（見つからない場合はnull）
func get_message(index: String) -> DialogueMessage:
	for message in messages:
		if message.index == index:
			return message
	return null

## プレイヤー状態でフィルタリングされたメッセージ配列を取得
##
## @param player_state String プレイヤー状態（"normal" または "expansion"）
## @return Array[DialogueMessage] 条件にマッチするメッセージの配列
func get_filtered_messages(player_state: String) -> Array[DialogueMessage]:
	var filtered: Array[DialogueMessage] = []

	for message in messages:
		# condition が空文字列（条件なし）または player_state と一致する場合のみ追加
		if message.condition == "" or message.condition == player_state:
			filtered.append(message)

	return filtered

class_name DialogueMessage
extends Resource
## 会話メッセージデータ
##
## 会話の1つのメッセージ（セリフ）を定義するリソースクラスです。

# ======================== エクスポートプロパティ ========================

## メッセージインデックス（例: "m001", "m002"）
@export var index: String = ""

## 話者のキャラクターID（DialogueCharacterInfoのcharacter_idと対応）
@export var speaker_id: String = ""

## メッセージテキスト（多言語対応）
@export var text: Dictionary = {"ja": "", "en": ""}

## 選択肢リスト（分岐がある場合）
@export var choices: Array[DialogueChoiceData] = []

## 実行条件（空文字列の場合は常に実行、プレイヤー状態などを指定可能）
@export var condition: String = ""

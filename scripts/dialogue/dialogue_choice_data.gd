class_name DialogueChoiceData
extends Resource
## 会話の選択肢データ
##
## プレイヤーが選択できる選択肢の情報を定義するリソースクラスです。
## UIのdialogue_choice.gdとは別のクラスです。

# ======================== エクスポートプロパティ ========================

## 選択肢のテキスト（多言語対応）
@export var text: Dictionary = {"ja": "", "en": ""}

## この選択肢を選んだ後の次のメッセージインデックス（例: "m002"）
@export var next_index: String = ""

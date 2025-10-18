class_name EventConfig
extends Resource

## 個別イベントの設定データ
##
## 各イベントの識別子、実行回数ごとのDialogueDataリソース、
## および実行回数の上限を管理します。

# ======================== エクスポートプロパティ ========================

## イベント識別子（例: "001", "002"）
@export var event_id: String = ""

## 実行回数順のDialogueDataパス配列
## インデックス0が初回、1が2回目...
## 配列の範囲外は最後の要素を返す（リピート用）
@export var dialogue_resources: Array[String] = []

## 最大実行回数
## -1: 無制限（デフォルト）- 何度でも実行可能
## 0: 無効 - イベントを発火しない（デバッグ用）
## >0: 指定回数まで実行可能 - 上限到達後は発火しない
@export var max_execution_count: int = -1

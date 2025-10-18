class_name BaseEvent
extends RefCounted

## イベントシステムの基底クラス
##
## 全てのイベント（会話、カットシーンなど）はこのクラスを継承します。
## sow.mdの要件に基づいて実装されています。

# ======================== シグナル定義 ========================

## イベントが完了した時に発信
signal event_completed()

# ======================== 状態管理変数 ========================

## イベントの実行ステータス
enum ExecutionStatus {
	PENDING,    # 未実行
	RUNNING,    # 実行中
	COMPLETED,  # 完了
	SKIPPED     # スキップされた
}

## 現在の実行ステータス
var status: ExecutionStatus = ExecutionStatus.PENDING

## スキップ可能かどうか
var is_skippable: bool = false

# ======================== 公開API ========================

## イベントを実行する（抽象メソッド、具象クラスで実装）
##
## 具象クラスは以下を実装する必要があります：
## 1. event_started シグナルを発信
## 2. イベント固有の処理を実行
## 3. event_completed シグナルを完了時に発信
## 4. ステータスを適切に更新
func execute() -> void:
	push_error("BaseEvent.execute() must be implemented by subclass")

## イベントをスキップできるかどうかを判定する（抽象メソッド）
##
## @return bool スキップ可能な場合はtrue
func can_skip() -> bool:
	return is_skippable

## イベントをスキップする
##
## スキップ可能な場合のみ実行されます。
## 具象クラスでオーバーライド可能です。
func skip() -> void:
	if can_skip():
		status = ExecutionStatus.SKIPPED
		event_completed.emit()

# ======================== ステータス管理 ========================

## 実行中かどうかを確認
func is_running() -> bool:
	return status == ExecutionStatus.RUNNING

## 完了したかどうかを確認
func is_completed() -> bool:
	return status == ExecutionStatus.COMPLETED

## スキップされたかどうかを確認
func is_skipped() -> bool:
	return status == ExecutionStatus.SKIPPED

## ステータスをリセット
func reset() -> void:
	status = ExecutionStatus.PENDING

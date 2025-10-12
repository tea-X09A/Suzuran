# イベントシステム実装計画

## 概要
プレイヤーが特定エリアに入ると会話やアニメーションを実行できるイベントシステムを構築する。

## 実装する機能

### 1. イベント基盤システム
- **BaseEvent (基底クラス)**: 全イベントの共通インターフェース
  - 実行開始/完了シグナル
  - スキップ可否判定
  - 実行ステータス管理

- **EventManager (AutoLoad)**: イベント実行の中央管理
  - イベントキューの管理
  - プレイヤー操作の制御（イベント中は移動不可）
  - 任意のタイミングでイベントを開始する公開API
  - 複数の発火方法に対応：
    - EventAreaからの自動発火（one_shot活用）
    - NPCやトラップからの手動発火（何度でも可能）

- **EventState (プレイヤー制御)**: イベント中のプレイヤー状態管理
  - **採用方式**: C案（新ステートEventStateを追加）※event_questions.md項目2参照
  - BaseStateを継承したステートクラス
  - イベント中の動作：
    - 全ての入力を無視（移動、ジャンプ、攻撃、射撃など）
    - 速度を完全停止（velocity = Vector2.ZERO）
    - アニメーションをIDLEに固定
    - 重力のみ適用（空中でイベント開始した場合の着地対応）
  - API設計：
    - `Player.start_event()`: EVENT状態に遷移
    - `Player.end_event()`: IDLE状態に復帰
  - メリット：
    - プロジェクトのステートパターン方針に準拠
    - イベント中の挙動が1クラスに集約され保守性が高い
    - 将来的なイベント中の自動移動などの拡張が容易

### 2. 会話システム
- **DialogueEvent**: 会話実行イベント
  - テキスト表示
  - キャラクター名表示
  - 複数メッセージの連続表示
  - 次へ進む入力待ち（Zキー/Enterキー）
  - 選択肢表示と分岐処理
  - 立ち絵の表示制御

- **DialogueBox (UI)**: 会話表示ボックス（ノベルゲーム風）
  - 画面下部4分の1のサイズ
  - 黒色背景（opacity 0.5）+ 上部フェードエフェクト
  - テキストアニメーション（1文字ずつ表示）
  - キャラクター名表示
  - Zキー/Enterキーで次のメッセージへ
  - Shiftキー長押しで高速スキップ（テキスト即座表示＋自動送り）

- **DialoguePortrait (UI)**: キャラクター立ち絵表示
  - 左側：プレイヤー立ち絵
  - 右側：NPC立ち絵
  - メッセージウィンドウより上のレイヤー
  - フェードイン/アウトアニメーション
  - 話者の強調表示（明るさ調整）

- **DialogueChoice (UI)**: 選択肢ボタン
  - 画面中央に縦並び表示
  - 選択肢テキスト表示
  - ホバー/選択エフェクト
  - Zキー/Enterキーで決定、↑↓キーで選択移動

- **DialogueData (Resource)**: 会話データ定義
  - 登場キャラクター定義配列
  - 会話メッセージ配列
  - 表示速度設定

  **キャラクター定義構造**:
  ```gdscript
  class CharacterInfo:
      var character_id: String        # キャラクター識別子（"001", "002"など数値文字列）
      var speaker_name: Dictionary    # 表示名（多言語対応）{"ja": "スズラン", "en": "Suzuran"}
      var portrait_base_path: String  # 立ち絵フォルダパス
      var default_emotion: String     # デフォルト表情（"normal"など）
  ```

  **メッセージ配列の構造**:
  ```gdscript
  class DialogueMessage:
      var index: String           # メッセージインデックス（"0", "1", "2", "3-a", "3-b"など）
      var speaker_id: String      # キャラクター識別子（上記で定義した数値ID）
                                   # 空文字列("")の場合はナレーション扱い（話者名非表示、立ち絵なし）
      var text: Dictionary        # メッセージ内容（多言語対応）{"ja": "...", "en": "..."}
      var emotion: String         # 表情差分（空文字列ならdefault使用）
      var speaker_side: String    # "left" or "right"
      var choices: Array          # 選択肢配列（オプション）
  ```

  **立ち絵パスの構築方法**:
  - 実行時に `portrait_base_path + emotion + ".png"` で構築
  - 例：`"res://assets/images/portrait/player/" + "happy" + ".png"`
  - これにより冗長性を削減し、保守性を向上

### 3. アニメーションイベント
- **AnimationEvent**: アニメーション実行イベント
  - AnimationPlayerの再生
  - 完了待機
  - ループ/ワンショット対応

### 4. カットシーンイベント
- **CutsceneEvent**: 複合イベント実行
  - カメラ移動
  - キャラクターアニメーション
  - 会話との組み合わせ
  - タイムライン制御
  - Shiftキー長押しで高速再生

### 5. イベントトリガー

#### EventArea（共通スクリプト）
- **共通スクリプト**: 全てのEventAreaは`event_area.gd`を共有
- **event_id駆動**: `@export var event_id: String`でイベント識別子を指定
- **個別スクリプト参照**: `event_id`に基づいて個別イベントスクリプトをロード
  - 例: `event_id = "001"` → `res://scripts/events/area/event_001.gd`をロード
- **`one_shot`機能**: 一度だけ発火するか、何度でも発火するかを制御

#### BaseEventAreaScript（個別イベントスクリプトの基底クラス）
- 各イベント固有のロジックを定義する基底クラス
- **主な機能**:
  - **条件判定**: `can_trigger() -> bool` - プレイヤー状態に基づくイベント発火条件のチェック
  - **リソース選択**: `get_dialogue_resource() -> String` - 実行回数に基づくリソースパス取得
  - **実行回数管理**: 自動的にGameProgressと連携してイベント実行回数を追跡

- **プロパティ**:
  - `required_player_state: String` - 必要なプレイヤー状態（"normal", "expansion"など、空文字列=""は状態不問）
  - `dialogue_resources: Array[String]` - DialogueDataリソースパスの配列（実行回数順: [01, 02, 03, ...]）
    - 例: `["res://data/dialogues/event_001_01.tres", "res://data/dialogues/event_001_02.tres"]`
    - インデックス0が初回、1が2回目、2が3回目...
    - 配列の範囲外の場合は最後の要素を返す（リピート用）

- **メソッド**:
  ```gdscript
  # 継承先でオーバーライド可能
  func can_trigger(player_state: String) -> bool:
      # デフォルト実装: プレイヤー状態のチェック
      pass

  func get_dialogue_resource() -> String:
      # 実行回数に基づいてリソースパスを返す
      pass
  ```

#### 任意オブジェクトからの発火
- **NPC**: 接触やインタラクトキーで会話開始（何度でも可能）
- **トラップ**: 踏むたびにイベント発火（何度でも可能）
- **その他オブジェクト**: 任意のタイミングでEventManager経由でイベント開始
- 実装方法: `EventManager.start_event(event_data)` を呼び出す

## ファイル構成

```
scripts/
├── events/
│   ├── base_event.gd                  # 基底クラス
│   ├── dialogue_event.gd              # 会話イベント
│   ├── animation_event.gd             # アニメーションイベント
│   ├── cutscene_event.gd              # カットシーンイベント
│   ├── base_event_area_script.gd      # EventArea個別スクリプトの基底クラス（新規）
│   └── area/                          # EventArea個別スクリプト格納フォルダ（新規）
│       ├── event_001.gd               # イベント001の固有ロジック
│       ├── event_002.gd               # イベント002の固有ロジック
│       └── ...                        # 他のイベントスクリプト
│
├── dialogue/
│   ├── dialogue_box.gd                # 会話UIコントローラー
│   ├── dialogue_portrait.gd           # 立ち絵表示制御
│   ├── dialogue_choice.gd             # 選択肢ボタン
│   └── dialogue_data.gd               # 会話データリソース
│
├── player/
│   ├── player.gd                      # 既存を拡張（start_event/end_eventメソッド追加）
│   └── states/
│       └── event_state.gd             # イベント中のプレイヤー状態（新規）
│
├── autoload/
│   ├── event_manager.gd               # イベント管理（新規AutoLoad）
│   ├── game_settings.gd               # ゲーム設定管理（言語設定等、新規AutoLoad）
│   └── game_progress.gd               # ゲーム進行状況管理（イベント実行回数等、新規AutoLoad）
│
└── levels/
    └── event_area.gd                  # 共通スクリプト（event_id駆動に拡張）

scenes/
├── dialogue/
│   ├── dialogue_system.tscn    # 会話システム全体（UIルート）
│   ├── dialogue_box.tscn       # メッセージウィンドウ
│   ├── dialogue_portrait.tscn  # 立ち絵コンテナ
│   └── dialogue_choice.tscn    # 選択肢ボタン
│
└── levels/
    └── event_area.tscn         # 既存シーン（拡張）

assets/
└── images/
    └── portrait/               # 立ち絵画像格納フォルダ（新規）
        ├── player/             # プレイヤー表情バリエーション
        └── npcs/               # NPC立ち絵

data/
└── dialogues/                  # DialogueDataリソース格納フォルダ（新規）
    ├── event_001_01.tres       # イベント001・1回目の会話データ
    ├── event_001_02.tres       # イベント001・2回目以降の会話データ
    ├── event_002_01.tres       # イベント002・1回目の会話データ
    ├── event_002_02.tres       # イベント002・2回目以降の会話データ
    ├── event_003_01.tres       # イベント003・1回目の会話データ
    ├── event_003_02.tres       # イベント003・2回目の会話データ
    ├── event_003_03.tres       # イベント003・3回目の会話データ
    ├── event_003_04.tres       # イベント003・4回目以降の会話データ
    └── ...                     # 他の会話データ
```

## 実装順序

1. **基盤構築**
   - GameSettings AutoLoad（言語設定管理）
   - GameProgress AutoLoad（イベント実行回数管理）
   - BaseEvent基底クラス
   - EventManager AutoLoad
   - **EventState実装とPlayer統合**:
     - `scripts/player/states/event_state.gd` 新規作成
     - `scripts/player/player.gd` 拡張:
       - `state_instances["EVENT"]` の登録
       - `start_event()` メソッド追加
       - `end_event()` メソッド追加
       - `get_current_state()` メソッド追加（プレイヤー状態を返す）

2. **EventArea個別スクリプトシステム**
   - BaseEventAreaScript 基底クラス実装
   - EventArea共通スクリプト拡張（event_id駆動化）
   - サンプル個別スクリプト作成（event_001.gd）

3. **会話システム**
   - DialogueData リソース（多言語対応）
   - DialogueBox UI
   - DialogueEvent 実装

4. **アニメーションシステム**
   - AnimationEvent 実装

5. **統合とテスト**
   - サンプルDialogueDataリソース作成（event_XXX_01.tres、event_XXX_02.tres形式）
   - level1での動作確認
   - プレイヤー状態による条件分岐のテスト

6. **統合テスト**
   - NPCスクリプトでの会話呼び出し実装例
   - トラップでのイベント発火実装例

7. **カットシーン（オプション）**
   - CutsceneEvent 実装
   - 複合イベント例作成

## 設計方針

- **シグナルベースの疎結合**: ノード間の直接参照を避ける
- **ステートパターン準拠**: Player実装と同様の設計思想
- **メモリリーク防止**: weakref、queue_free、disconnect徹底
- **拡張性**: 新イベントタイプを容易に追加可能
- **再利用性**: イベントデータはResourceとして外部定義
- **event_id駆動設計**:
  - EventAreaは共通スクリプトを使用し、コードの重複を防止
  - 各EventAreaは`event_id`でイベントを識別
  - イベント固有のロジックは個別スクリプト（BaseEventAreaScript継承）に分離
  - 条件判定やリソース選択などの複雑なロジックを柔軟に実装可能

## EventState実装詳細

### event_state.gdの実装
```gdscript
class_name EventState
extends BaseState

# イベント中のプレイヤー制御
# - 全ての入力を無視
# - 静止状態を維持（velocityを0に）
# - アニメーションはIDLEを維持

func initialize_state() -> void:
	# 速度を完全停止
	player.velocity = Vector2.ZERO
	# アニメーションをIDLEに設定
	set_animation_state("IDLE")

func cleanup_state() -> void:
	# 特に処理なし（IDLE状態に戻る際に自然に再開される）
	pass

func handle_input(_delta: float) -> void:
	# イベント中は全ての入力を無視
	pass

func physics_update(delta: float) -> void:
	# 重力のみ適用（空中でイベント開始した場合に地面に着地させる）
	apply_gravity(delta)
	# 水平移動は完全に停止
	player.velocity.x = 0.0
```

### Player.gdへの統合
```gdscript
# _initialize_state_system()内に追加
state_instances["EVENT"] = EventState.new(self)

# イベント制御メソッド（メソッド末尾付近に追加）
## イベント開始（EventAreaから呼び出される）
func start_event() -> void:
	update_animation_state("EVENT")

## イベント終了（DialogueManagerから呼び出される）
func end_event() -> void:
	update_animation_state("IDLE")

## プレイヤーの現在の状態を取得（EventAreaから呼び出される）
## @return: プレイヤーの状態文字列（"normal", "expansion"など）
func get_current_state() -> String:
	# プレイヤーの状態を管理する変数を参照
	# 例: player_mode変数が"normal"または"expansion"を保持していると仮定
	# ここでは仮の実装
	return "normal"  # 実際の実装では状態変数を返す
```

### EventAreaの動作フロー
```gdscript
# EventArea.gd（共通スクリプト）
@export var event_id: String = ""  # イベント識別子（例: "001", "002"）
@export var one_shot: bool = true  # 一度だけ発火するか

var event_script: BaseEventAreaScript = null

func _ready() -> void:
	# event_idに基づいて個別スクリプトをロード
	if event_id != "":
		var script_path: String = "res://scripts/events/area/event_%s.gd" % event_id
		if ResourceLoader.exists(script_path):
			var EventScriptClass = load(script_path)
			event_script = EventScriptClass.new()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and event_script != null:
		var player = body as Player

		# プレイヤーの現在の状態を取得
		var player_state: String = player.get_current_state()  # "normal", "expansion"など

		# 発火条件チェック（プレイヤー状態を渡す）
		if not event_script.can_trigger(player_state):
			return

		# リソースパス取得
		var dialogue_resource: String = event_script.get_dialogue_resource()
		if dialogue_resource == "":
			return

		# イベント開始
		player.start_event()
		# ダイアログ表示
		EventManager.start_dialogue(dialogue_resource)

		# one_shotの場合、発火後にエリアを無効化
		if one_shot:
			monitoring = false
```

### 個別イベントスクリプトの実装例
```gdscript
# scripts/events/area/event_001.gd
extends BaseEventAreaScript

# イベント001: 商人との会話
# 条件: プレイヤー状態不問（normalでもexpansionでも可）
# 01回目: 丁寧な挨拶と商品紹介
# 02回目: 簡易的な挨拶
# 03回目以降: 簡易的な挨拶（02と同じ）

func _init():
	required_player_state = ""  # 状態不問（空文字列）
	dialogue_resources = [
		"res://data/dialogues/event_001_01.tres",  # 初回
		"res://data/dialogues/event_001_02.tres"   # 2回目以降（リピート用）
	]

# 必要に応じてオーバーライド
func can_trigger(player_state: String) -> bool:
	# デフォルト実装を使用（状態不問）
	return super.can_trigger(player_state)
```

### プレイヤー状態を条件とするイベントの実装例
```gdscript
# scripts/events/area/event_002.gd
extends BaseEventAreaScript

# イベント002: 特殊な商人との会話
# 条件: プレイヤーが"expansion"状態である必要がある
# 01回目: expansion状態専用の会話
# 02回目以降: リピート用の会話

func _init():
	required_player_state = "expansion"  # expansion状態が必要
	dialogue_resources = [
		"res://data/dialogues/event_002_01.tres",  # 初回
		"res://data/dialogues/event_002_02.tres"   # 2回目以降
	]

# デフォルト実装で十分なのでオーバーライド不要
# （required_player_stateが自動的にチェックされる）
```

### 複数回の異なる会話を持つイベントの実装例
```gdscript
# scripts/events/area/event_003.gd
extends BaseEventAreaScript

# イベント003: ストーリー進行に応じた会話
# 条件: プレイヤー状態不問
# 01回目: 初回会話
# 02回目: 2回目専用の会話
# 03回目: 3回目専用の会話
# 04回目以降: リピート用の会話

func _init():
	required_player_state = ""  # 状態不問
	dialogue_resources = [
		"res://data/dialogues/event_003_01.tres",  # 初回
		"res://data/dialogues/event_003_02.tres",  # 2回目
		"res://data/dialogues/event_003_03.tres",  # 3回目
		"res://data/dialogues/event_003_04.tres"   # 4回目以降（リピート）
	]
```

### BaseEventAreaScript実装詳細

#### 基底クラスの構造
```gdscript
# scripts/events/base_event_area_script.gd
class_name BaseEventAreaScript
extends RefCounted

# イベント固有のプロパティ
var required_player_state: String = ""       # 必要なプレイヤー状態（""は状態不問）
var dialogue_resources: Array[String] = []   # DialogueDataリソースパスの配列（実行回数順）

# イベント発火条件チェック
# 継承先でオーバーライド可能
# @param player_state: プレイヤーの現在の状態（"normal", "expansion"など）
# @return: イベントが発火可能かどうか
func can_trigger(player_state: String) -> bool:
	# required_player_stateが空文字列の場合は状態不問（常に発火可能）
	if required_player_state == "":
		return true

	# プレイヤーの状態がrequired_player_stateと一致するかチェック
	return player_state == required_player_state

# 表示するDialogueDataリソースパスを取得
# 継承先でオーバーライド可能
# @return: DialogueDataリソースのパス
func get_dialogue_resource() -> String:
	# dialogue_resourcesが空の場合はエラー
	if dialogue_resources.is_empty():
		push_error("dialogue_resources is empty for event: %s" % _get_event_id_from_path())
		return ""

	# イベントの実行回数を取得
	var event_id: String = _get_event_id_from_path()
	var count: int = GameProgress.get_event_count(event_id)

	# countに対応するリソースを取得
	# 配列の範囲外の場合は最後の要素を返す（リピート用）
	var index: int = min(count, dialogue_resources.size() - 1)
	return dialogue_resources[index]

# イベントIDをスクリプトパスから抽出（内部用）
func _get_event_id_from_path() -> String:
	var script_path: String = get_script().resource_path
	var file_name: String = script_path.get_file().get_basename()
	# "event_001.gd" -> "001"
	return file_name.replace("event_", "")
```

#### GameProgressの主要メソッド（実装予定）
```gdscript
# scripts/autoload/game_progress.gd
extends Node

# イベント実行回数を記録する辞書
var event_counts: Dictionary = {}  # { "001": 2, "002": 1, ... }

# イベント実行回数管理
func get_event_count(event_id: String) -> int:
	return event_counts.get(event_id, 0)

func increment_event_count(event_id: String) -> void:
	event_counts[event_id] = get_event_count(event_id) + 1

# フラグ管理（将来的な拡張用）
var flags: Dictionary = {}  # { "flag_name": true/false }

func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value
```

### DialogueData実装における注意事項
- **キャラクター管理**: 会話に登場するキャラクターは事前に`characters`配列で定義
  - `character_id`は"001", "002"などの数値文字列形式
- **ナレーション処理**:
  - `speaker_id`が空文字列("")の場合はナレーション扱いとする
  - ナレーション時の動作:
    - 話者名を非表示にする
    - 左右の立ち絵を両方とも暗く表示（非話者扱い）
    - テキストは通常通り表示される
- **メッセージインデックス管理**:
  - 各メッセージに一意の`index`文字列を付与（"0", "1", "2", "3-a", "3-b"など）
  - 選択肢による分岐では末尾にアルファベット（-a, -b, -c...）を付与
  - インデックス検索用のヘルパー関数: `get_message_by_index(index: String) -> DialogueMessage`
- **立ち絵パス構築**: `get_portrait_path(speaker_id, emotion)`メソッドで動的に構築
- **表情のフォールバック**: `emotion`が空文字列の場合は`default_emotion`を使用
- **立ち絵の柔軟性**:
  - 立ち絵画像が存在しない、または表示されていない場合でも、テキスト表示は正常に動作する
  - 立ち絵のロードエラーや非表示状態は、会話の進行を妨げない
- **型安全性**: CharacterInfo、DialogueMessage、DialogueChoiceは全てtyped配列で管理
- **多言語対応**:
  - `speaker_name`と`text`は辞書形式: `{"ja": "日本語", "en": "English"}`
  - 実行時に`current_language`変数に基づいて適切な言語を取得
  - 例: `speaker_name[current_language]` または `text[current_language]`
  - 言語設定はEventManagerまたはGameSettings（AutoLoad）で管理

## イベント発火の仕様

### 1. EventArea経由（自動発火）
- **event_id駆動**: 各EventAreaは`event_id`で個別スクリプトを識別
- プレイヤーがエリアに侵入すると自動的にイベント開始
- **プレイヤー状態による条件判定**:
  - `player.get_current_state()`で現在の状態を取得
  - `event_script.can_trigger(player_state)`で発火可否を判定
  - 例: expansion状態でのみ発火するイベント
- **`one_shot = true`**: 一度だけ発火（デフォルト）
  - 発火後、`monitoring = false`でエリアを無効化
  - GameProgressにイベント実行回数を記録
- **`one_shot = false`**: 何度でも発火
  - 毎回、個別スクリプトの`can_trigger()`で条件判定
  - 実行回数に応じたリソースを自動選択（dialogue_resources配列から）
- 用途: ストーリーイベント、チュートリアル、NPCとの会話

### 2. オブジェクト経由（手動発火）
- NPCやトラップなどが任意のタイミングで`EventManager.start_event()`を呼び出し
- **何度でも発火可能**（one_shot制限なし）
- 用途例:
  - NPC: プレイヤーが近づいてZキーを押すと会話開始
  - トラップ: 接触すると演出イベント

### 3. イベント実行フロー（EventArea）
```
1. プレイヤーがEventAreaに侵入
   ↓
2. event_idから個別スクリプト（event_XXX.gd）をロード
   ↓
3. プレイヤーの現在の状態（normal/expansionなど）を取得
   ↓
4. event_script.can_trigger(player_state) で条件判定
   ├─ false → イベント不発火（プレイヤー状態が条件を満たさない）
   └─ true → 次へ
   ↓
5. event_script.get_dialogue_resource() でリソースパス取得
   ├─ 初回（count=0） → dialogue_resources[0]（例: event_001_01.tres）
   ├─ 2回目（count=1） → dialogue_resources[1]（例: event_001_02.tres）
   ├─ 3回目（count=2） → dialogue_resources[2]（例: event_001_03.tres）
   └─ N回目以降 → dialogue_resources[last]（配列の最後の要素をリピート）
   ↓
6. EventManager.start_dialogue(resource_path) でイベント実行
   ↓
7. GameProgress.increment_event_count(event_id) で実行回数を記録
   ↓
8. one_shot=true の場合、EventAreaを無効化
```

## UI詳細仕様

### メッセージウィンドウ
- **配置**: 画面下部
- **サイズ**: 画面の縦幅の1/4（25%）
- **背景**: 黒色 (Color: #000000, Alpha: 0.5)
- **エフェクト**: 上部にフェード（グラデーション）を適用
- **テキスト**: 白色、1文字ずつ表示アニメーション

### 立ち絵表示
- **配置**: メッセージウィンドウより上のレイヤー
  - 左側: プレイヤー立ち絵
  - 右側: NPC立ち絵
- **サイズ**: 画面高さの60-70%程度
- **エフェクト**:
  - 表示/非表示時のフェードイン/アウト
  - 話者の立ち絵は明るく、非話者は暗く（modulate調整）
  - **ナレーション時**（speaker_idが空文字列""の場合）:
    - 左右の立ち絵ともに暗く表示（非話者扱い）
    - 話者名は非表示
- **立ち絵がない場合の動作**:
  - 立ち絵画像が存在しない、または表示されていない場合でも、テキストは正常に表示される
  - 立ち絵の表示/非表示はテキスト表示の可否に影響しない

### 選択肢表示
- **配置**: 画面中央に縦並び
- **スタイル**: 半透明背景のボタン
- **操作**:
  - ↑↓/WSキーで選択移動
  - Zキー/Enterキーで決定
- **最大数**: 2つまで

### 入力操作
- **Zキー / Enterキー**: テキスト送り、選択肢決定
- **↑↓キー**: 選択肢の移動
- **Shiftキー（長押し）**: 会話・カットシーンの高速スキップ

## 選択肢システムの仕様

### 基本機能
- プレイヤーが複数の選択肢から1つを選択
- 選択結果に応じて会話を分岐
- キーボード操作に対応
- マウス操作には非対応

### 選択肢データ構造
```gdscript
# DialogueData.gd で定義
class DialogueChoice:
    var text: Dictionary          # 選択肢のテキスト（多言語対応）{"ja": "...", "en": "..."}
    var next_index: String        # 選択後に表示するメッセージのインデックス（"3-a", "3-b"など）
    var condition: String         # 表示条件（オプション）
```

**採用方式：A案（インデックス参照）**
- 1つのDialogueDataリソース内で会話全体（分岐含む）を管理
- 選択肢の分岐先をインデックス文字列で指定
- 例：`next_index = "3-a"` → 同じDialogueData内のindex="3-a"のメッセージに遷移
- 分岐がある場合は"3-a", "3-b"のようにアルファベットサフィックスを付与

### DialogueDataの使用例
```gdscript
# DialogueDataリソースの設定例
characters = [
    {
        "character_id": "001",
        "speaker_name": {"ja": "鈴蘭", "en": "Suzuran"},
        "portrait_base_path": "res://assets/images/portrait/player/",
        "default_emotion": "normal"
    },
    {
        "character_id": "002",
        "speaker_name": {"ja": "商人", "en": "Merchant"},
        "portrait_base_path": "res://assets/images/portrait/npcs/merchant/",
        "default_emotion": "smile"
    }
]

messages = [
    {
        "index": "0",
        "speaker_id": "002",
        "text": {"ja": "いらっしゃいませ！", "en": "Welcome!"},
        "emotion": "smile",
        "speaker_side": "right",
        "choices": []
    },
    {
        "index": "1",
        "speaker_id": "001",
        "text": {"ja": "手裏剣を買いたいのですが...", "en": "I'd like to buy some shuriken..."},
        "emotion": "",  # 空文字列 → default_emotion("normal")を使用
        "speaker_side": "left",
        "choices": []
    },
    {
        "index": "2",
        "speaker_id": "002",
        "text": {"ja": "手裏剣ですか。どうしましょう？", "en": "Shuriken, you say. What would you like to do?"},
        "emotion": "thinking",
        "speaker_side": "right",
        "choices": [
            {"text": {"ja": "買う", "en": "Buy"}, "next_index": "3-a"},
            {"text": {"ja": "やめておく", "en": "Never mind"}, "next_index": "3-b"}
        ]
    },
    {
        "index": "3-a",  # 「買う」を選択した場合
        "speaker_id": "002",
        "text": {"ja": "ありがとうございます！", "en": "Thank you very much!"},
        "emotion": "happy",
        "speaker_side": "right",
        "choices": []
    },
    {
        "index": "3-b",  # 「やめておく」を選択した場合
        "speaker_id": "002",
        "text": {"ja": "またのお越しをお待ちしております。", "en": "We look forward to seeing you again."},
        "emotion": "smile",
        "speaker_side": "right",
        "choices": []
    }
]
```

### UI配置
- 画面中央に選択肢ボタンを縦並び表示
- 最大4つまでの選択肢に対応
- 選択後はボタンを非表示にして会話を続行

## event_id駆動設計の利点

### 1. コードの再利用性と保守性
- **共通ロジックの一元管理**: EventArea.gdに共通処理を集約
- **個別ロジックの分離**: イベント固有のロジックは個別スクリプトに分離
- **変更の局所化**: 共通処理の修正は一箇所で済む

### 2. 拡張性と柔軟性
- **新イベントの追加が容易**: 新しい`event_XXX.gd`を作成するだけ
- **条件判定の柔軟性**: 各イベントで独自の条件ロジックを実装可能
- **リソース選択の柔軟性**: 初回/リピート以外の複雑な分岐も実装可能

### 3. データ駆動開発
- **シーンエディタで管理**: EventAreaインスタンスごとに`event_id`を設定
- **視覚的な管理**: どのエリアがどのイベントに対応するか一目瞭然
- **デザイナーフレンドリー**: プログラマでなくても新イベントを追加可能

## event_id駆動設計のベストプラクティス

### 1. イベントID命名規則
- **3桁のゼロパディング**: `001`, `002`, `003`...

### 2. 個別スクリプトの実装パターン

#### パターンA: シンプルな会話イベント（状態不問）
```gdscript
# プレイヤー状態不問、初回とリピートの2パターン
extends BaseEventAreaScript

func _init():
    required_player_state = ""  # 状態不問
    dialogue_resources = [
        "res://data/dialogues/event_XXX_01.tres",  # 初回
        "res://data/dialogues/event_XXX_02.tres"   # 2回目以降
    ]
```

#### パターンB: プレイヤー状態が条件のイベント
```gdscript
# expansion状態でのみ発火する会話イベント
extends BaseEventAreaScript

func _init():
    required_player_state = "expansion"  # expansion状態が必要
    dialogue_resources = [
        "res://data/dialogues/event_XXX_01.tres",  # 初回
        "res://data/dialogues/event_XXX_02.tres"   # 2回目以降
    ]

# デフォルト実装で十分（required_player_stateが自動チェックされる）
```

#### パターンC: 複数回の異なる会話
```gdscript
# 実行回数に応じて異なる会話を複数回用意
extends BaseEventAreaScript

func _init():
    required_player_state = ""  # 状態不問
    dialogue_resources = [
        "res://data/dialogues/event_XXX_01.tres",  # 初回
        "res://data/dialogues/event_XXX_02.tres",  # 2回目
        "res://data/dialogues/event_XXX_03.tres",  # 3回目
        "res://data/dialogues/event_XXX_04.tres"   # 4回目以降（リピート）
    ]
```

#### パターンD: カスタム条件判定
```gdscript
# フラグなど複雑な条件を持つイベント
extends BaseEventAreaScript

func _init():
    required_player_state = ""
    dialogue_resources = [
        "res://data/dialogues/event_XXX_01.tres",
        "res://data/dialogues/event_XXX_02.tres"
    ]

func can_trigger(player_state: String) -> bool:
    # デフォルトの状態チェック
    if not super.can_trigger(player_state):
        return false

    # カスタム条件: フラグチェック
    if not GameProgress.get_flag("door_opened"):
        return false

    return true
```

### 3. リソースファイルの命名規則
- **基本形式**: `event_[ID]_[回数].tres`
  - 例: `event_001_01.tres`, `event_001_02.tres`, `event_001_03.tres`
- **IDは3桁のゼロパディング**: `001`, `002`, `003`...
- **回数は2桁のゼロパディング**: `01`, `02`, `03`...
- **配列順序と一致**: dialogue_resources配列のインデックス順にファイル番号を付与
- **リピート用リソース**: 配列の最後の要素（例: `event_001_02.tres`が2回目以降すべてに使用される）
- **一貫性の維持**: プロジェクト全体で統一されたルールを適用

#### 命名例
```
# シンプルなイベント（2パターン）
event_001_01.tres  # 初回
event_001_02.tres  # 2回目以降（リピート）

# 複数回異なる会話を持つイベント（4パターン）
event_003_01.tres  # 1回目
event_003_02.tres  # 2回目
event_003_03.tres  # 3回目
event_003_04.tres  # 4回目以降（リピート）
```

### 4. GameProgressとの連携
- **イベント実行回数の記録**: EventManagerがイベント完了時に自動的に記録
- **フラグ管理**: イベント中でフラグを設定し、他のイベントの条件に使用
- **セーブ/ロード**: GameProgressの状態をセーブデータに保存

### 5. デバッグとテスト
- **イベントIDの表示**: デバッグモードで画面にevent_idを表示
- **条件の可視化**: can_trigger()の結果をログ出力
- **リソースパスの確認**: 読み込まれたDialogueDataのパスを記録

## まとめ

event_id駆動設計により、以下を実現：

1. **共通スクリプト + 個別ロジック**: コードの重複を防ぎつつ、柔軟性を維持
2. **データ駆動開発**: シーンエディタでイベントを管理し、視覚的に配置
3. **拡張性**: 新イベントの追加が容易で、既存コードへの影響を最小化
4. **保守性**: 共通処理の変更が一箇所で済み、バグ修正も効率的
5. **テスト容易性**: 各イベントスクリプトを独立してテスト可能
6. **プレイヤー状態連動**: normalやexpansionなどのプレイヤー状態に応じたイベント発火
7. **柔軟なリソース管理**: 実行回数に応じた複数パターンの会話を配列で管理
8. **シンプルな命名規則**: `event_XXX_YY.tres`形式で一貫性を保持

# 会話イベントシステム実装計画

## 概要
プレイヤーが特定エリアに入ると会話イベントを実行できるシステムを構築する。

## 実装する機能

### 1. イベント基盤システム
- **BaseEvent (基底クラス)**: 全イベントの共通インターフェース
  - 実行開始/完了シグナル
  - スキップ可否判定
  - 実行ステータス管理

- **EventManager (AutoLoad)**: イベント実行の中央管理
  - イベントキューの管理
  - プレイヤー操作の制御（イベント中は移動不可）
  - **pause_managerとの連携**（イベント実行中のゲーム停止）:
    - イベント開始時に`PauseManager.pause_game()`を呼び出してゲーム全体を停止
    - イベント終了時に`PauseManager.resume_game()`を呼び出してゲームを再開
    - これにより、イベント中は背景のゲームプレイ（タイマーなど）が完全に停止する
  - 任意のタイミングでイベントを開始する公開API
  - 複数の発火方法に対応：
    - EventAreaからの自動発火（one_shot活用）
    - NPCやトラップからの手動発火（何度でも可能）

- **EventState (プレイヤー制御)**: イベント中のプレイヤー状態管理
  - **採用方式**: C案（新ステートEventStateを追加）
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
  - 顔画像の表示制御
  - 複数メッセージの連続表示
  - 次へ進む入力待ち（Zキー/Enterキー）
  - 選択肢表示と分岐処理

- **DialogueBox (UI)**: 会話表示ボックス（ノベルゲーム風）
  - 画面下部4分の1のサイズ
  - 黒色背景（opacity 0.5）+ 上部フェードエフェクト
  - テキストアニメーション（1文字ずつ表示）
  - キャラクター名表示
  - **顔画像表示機能**（新規）：
    - メッセージウィンドウ左上に顔画像を表示
    - サイズ: メッセージウィンドウ高さの約70%（正方形）
    - 話者が変わる際にフェードイン/アウト
    - ナレーション時は非表示
  - Zキー/Enterキーで次のメッセージへ
  - Shiftキー長押しで高速スキップ（テキスト即座表示＋自動送り）

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
      var face_image_path: String     # 顔画像フォルダパス
      var default_emotion: String     # デフォルト表情（"normal"など）
  ```

  **メッセージ配列の構造**:
  ```gdscript
  class DialogueMessage:
      var index: String           # メッセージインデックス（"0", "1", "2", "3-a", "3-b"など）
      var speaker_id: String      # キャラクター識別子（上記で定義した数値ID）
                                   # 空文字列("")の場合はナレーション扱い（話者名非表示、顔画像なし）
      var text: Dictionary        # メッセージ内容（多言語対応）{"ja": "...", "en": "..."}
      var emotion: String         # 表情差分（空文字列ならdefault使用）
      var choices: Array          # 選択肢配列（オプション）
      var condition: String       # 表示条件（プレイヤー状態: "normal", "expansion", ""=条件なし）
  ```

  **顔画像パスの構築方法**:
  - 実行時に `face_image_path + emotion + ".png"` で構築
  - 例：`"res://assets/images/faces/player/" + "happy" + ".png"`
  - これにより冗長性を削減し、保守性を向上

### 3. イベントトリガー

#### EventArea（共通スクリプト）
- **共通スクリプト**: 全てのEventAreaは`event_area.gd`を共有
- **event_id駆動**: `@export var event_id: String`でイベント識別子を指定
- **EventConfigData参照**: `event_id`に基づいてEventConfigDataリソースからイベント設定を取得
  - 例: `event_id = "001"` → event_config.tres内の"001"設定を参照
- **`one_shot`機能**: 一度だけ発火するか、何度でも発火するかを制御

#### EventConfigData（イベント設定リソース）
- 全イベントの設定を一つのtresファイルで一括管理
- **主な機能**:
  - **リソース選択**: `get_dialogue_resource(event_id, count) -> String` - 実行回数に基づくリソースパス取得
  - **設定取得**: `get_event_config(event_id) -> EventConfig` - イベントIDから設定を取得

- **EventConfig構造**（簡略化）:
  - `event_id: String` - イベント識別子（"001", "002"など）
  - `dialogue_resources: Array[String]` - DialogueDataリソースパスの配列（実行回数順: [01, 02, 03, ...]）
    - 例: `["res://data/dialogues/event_001_01.tres", "res://data/dialogues/event_001_02.tres"]`
    - インデックス0が初回、1が2回目、2が3回目...
    - 配列の範囲外の場合は最後の要素を返す（リピート用）
    - **プレイヤー状態による条件分岐は各DialogueDataリソース内で処理**

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
│   ├── event_config.gd                # イベント個別設定リソースクラス（新規）
│   └── event_config_data.gd           # イベント設定データリソースクラス（新規）
│
├── dialogue/
│   ├── dialogue_box.gd                # 会話UIコントローラー（顔画像表示機能含む）
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
│   ├── game_settings.gd               # ゲーム設定管理（言語設定等、既存AutoLoad）
│   └── save_load_manager.gd           # セーブ/ロード管理（イベント実行回数管理含む、既存AutoLoad）
│
└── levels/
    └── event_area.gd                  # 共通スクリプト（event_id駆動に拡張）

scenes/
├── dialogue/
│   ├── dialogue_system.tscn    # 会話システム全体（UIルート）
│   ├── dialogue_box.tscn       # メッセージウィンドウ（顔画像表示含む）
│   └── dialogue_choice.tscn    # 選択肢ボタン
│
└── levels/
    └── event_area.tscn         # 既存シーン（拡張）

assets/
└── images/
    └── faces/                  # 顔画像格納フォルダ（新規）
        ├── player/             # プレイヤー表情バリエーション
        └── npcs/               # NPC顔画像

data/
├── event_config.tres           # 全イベント設定を管理するリソース（新規）
└── dialogues/                  # DialogueDataリソース格納フォルダ（新規）
    ├── event_001_01.tres       # イベント001・1回目（内部でプレイヤー状態による分岐を処理）
    ├── event_001_02.tres       # イベント001・2回目以降
    ├── event_002_01.tres       # イベント002・1回目
    ├── event_002_02.tres       # イベント002・2回目以降
    ├── event_003_01.tres       # イベント003・1回目
    ├── event_003_02.tres       # イベント003・2回目
    ├── event_003_03.tres       # イベント003・3回目
    ├── event_003_04.tres       # イベント003・4回目以降
    └── ...                     # 他の会話データ
```

## 実装順序

1. **基盤構築**
   - GameSettings AutoLoad（言語設定管理、既存）
   - SaveLoadManager AutoLoad（イベント実行回数管理、既存）
   - BaseEvent基底クラス
   - EventManager AutoLoad
   - **EventState実装とPlayer統合**:
     - `scripts/player/states/event_state.gd` 新規作成
     - `scripts/player/player.gd` 拡張:
       - `state_instances["EVENT"]` の登録
       - `start_event()` メソッド追加
       - `end_event()` メソッド追加
       - `get_current_state()` メソッド追加（プレイヤー状態を返す）

2. **イベント設定システム**
   - EventConfig リソースクラス実装（`scripts/events/event_config.gd`）
   - EventConfigData リソースクラス実装（`scripts/events/event_config_data.gd`）
   - event_config.tres リソースファイル作成（Godotエディタで視覚的に作成）
   - EventArea共通スクリプト拡張（EventConfigData使用）

3. **会話システム**
   - DialogueData リソース（多言語対応、conditionフィールド追加）
   - DialogueBox UI（顔画像表示機能含む）
   - DialogueEvent 実装（プレイヤー状態に基づくメッセージフィルタリング機能含む）

4. **統合とテスト**
   - サンプルDialogueDataリソース作成（event_XXX_01.tres、event_XXX_02.tres形式）
   - level1での動作確認
   - プレイヤー状態による条件分岐のテスト（DialogueData内のconditionフィールドを使用）

5. **統合テスト**
   - NPCスクリプトでの会話呼び出し実装例
   - トラップでのイベント発火実装例

## 設計方針

- **シグナルベースの疎結合**: ノード間の直接参照を避ける
- **ステートパターン準拠**: Player実装と同様の設計思想
- **メモリリーク防止**: weakref、queue_free、disconnect徹底
- **拡張性**: 新イベントタイプを容易に追加可能
- **再利用性**: イベントデータはResourceとして外部定義
- **pause_managerとの統合**: イベント実行中はゲーム全体を停止し、プレイヤーに集中した体験を提供
- **event_id駆動設計**:
  - EventAreaは共通スクリプトを使用し、コードの重複を防止
  - 各EventAreaは`event_id`でイベントを識別
  - イベント固有の設定はEventConfigDataリソースに集約
  - 一つのtresファイルで全イベントの設定を一括管理

## イベント中のキャラクター制御実装詳細

### event_state.gdの実装（プレイヤー）
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
## イベント開始（EventManagerから呼び出される）
func start_event() -> void:
	update_animation_state("EVENT")

## イベント終了（EventManagerから呼び出される）
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

var event_config: EventConfigData

func _ready() -> void:
	# イベント設定リソースを読み込み
	event_config = load("res://data/event_config.tres")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and event_config != null:
		var player = body as Player

		# 実行回数を取得してリソースパスを決定
		var count: int = SaveLoadManager.get_event_count(event_id)
		var dialogue_resource: String = event_config.get_dialogue_resource(event_id, count)
		if dialogue_resource == "":
			return

		# ゲーム全体を停止（背景のゲームプレイを停止）
		PauseManager.pause_game()

		# イベント開始
		player.start_event()
		# ダイアログ表示（DialogueEvent内でプレイヤー状態に基づく条件分岐を処理）
		EventManager.start_dialogue(dialogue_resource)

		# イベント終了を待機（シグナル接続で処理）
		# EventManager.event_finished.connect(_on_event_finished)

		# one_shotの場合、発火後にエリアを無効化
		if one_shot:
			monitoring = false

# イベント終了時の処理
func _on_event_finished() -> void:
	# ゲームを再開
	PauseManager.resume_game()
```

### イベント設定リソースの実装

全イベントの設定を一つのtresファイルで一括管理します。これにより、個別のスクリプトファイルを作成せず、データリソースとして視覚的に管理できます。

#### Resource形式での実装

**重要**: Godotのtresファイルで内部クラスを扱うため、各クラスを独立したResourceとして定義する必要があります。

```gdscript
# scripts/events/event_config.gd
# イベント個別設定
class_name EventConfig
extends Resource

@export var event_id: String = ""                    # イベント識別子（"001", "002"など）
@export var dialogue_resources: Array[String] = []   # 実行回数順のDialogueDataパス配列
```

```gdscript
# scripts/events/event_config_data.gd
# 全イベント設定を管理するメインリソース
class_name EventConfigData
extends Resource

@export var events: Array[EventConfig] = []          # 全イベント設定の配列

# イベントIDから設定を取得
func get_event_config(event_id: String) -> EventConfig:
	for event in events:
		if event.event_id == event_id:
			return event
	return null

# 実行回数に基づいてDialogueDataリソースパスを取得
func get_dialogue_resource(event_id: String, count: int) -> String:
	var config: EventConfig = get_event_config(event_id)
	if config == null or config.dialogue_resources.is_empty():
		push_error("No config or dialogue_resources is empty for event: %s" % event_id)
		return ""

	# countに対応するリソースを取得
	# 配列の範囲外の場合は最後の要素を返す（リピート用）
	var index: int = min(count, config.dialogue_resources.size() - 1)
	return config.dialogue_resources[index]
```

**DialogueEvent内での条件分岐処理**:
```gdscript
# scripts/events/dialogue_event.gd（抜粋）
# メッセージを表示する際に、プレイヤーの現在の状態を取得し、
# 条件に合致するメッセージのみをフィルタリングして表示する

func filter_messages_by_condition(messages: Array, player_state: String) -> Array:
	var filtered: Array = []
	for msg in messages:
		# conditionが空文字列("")の場合は常に表示
		# conditionが設定されている場合はプレイヤー状態と一致する場合のみ表示
		if msg.condition == "" or msg.condition == player_state:
			filtered.append(msg)
	return filtered
```

#### イベント設定リソースファイルの作成方法

**Godotエディタでの作成手順**:
1. Godotエディタで `res://data/event_config.tres` を新規作成
2. インスペクタで `EventConfigData` スクリプトをアタッチ
3. `events` 配列に `EventConfig` リソースを追加
4. 各 `EventConfig` に対して:
   - `event_id` を設定（"001", "002"など）
   - `dialogue_resources` 配列にDialogueDataのパスを追加（実行回数順）

**tres ファイルの実例**:
```
# data/event_config.tres
[gd_resource type="Resource" script_class="EventConfigData" load_steps=5 format=3 uid="uid://xxxxx"]

[ext_resource type="Script" path="res://scripts/events/event_config_data.gd" id="1_xxxxx"]
[ext_resource type="Script" path="res://scripts/events/event_config.gd" id="2_xxxxx"]

[sub_resource type="Resource" id="EventConfig_001"]
script = ExtResource("2_xxxxx")
event_id = "001"
dialogue_resources = Array[String](["res://data/dialogues/event_001_01.tres", "res://data/dialogues/event_001_02.tres"])

[sub_resource type="Resource" id="EventConfig_002"]
script = ExtResource("2_xxxxx")
event_id = "002"
dialogue_resources = Array[String](["res://data/dialogues/event_002_01.tres", "res://data/dialogues/event_002_02.tres"])

[sub_resource type="Resource" id="EventConfig_003"]
script = ExtResource("2_xxxxx")
event_id = "003"
dialogue_resources = Array[String](["res://data/dialogues/event_003_01.tres", "res://data/dialogues/event_003_02.tres", "res://data/dialogues/event_003_03.tres", "res://data/dialogues/event_003_04.tres"])

[resource]
script = ExtResource("1_xxxxx")
events = Array[EventConfig]([SubResource("EventConfig_001"), SubResource("EventConfig_002"), SubResource("EventConfig_003")])
```

**重要な注意点**:
- tres ファイルは手動で編集するのではなく、**Godotエディタのインスペクタで視覚的に作成・編集すること**
- 各サブリソースにはユニークなIDを付与（Godotエディタが自動生成）
- **プレイヤー状態による条件分岐は各DialogueDataリソース内のメッセージのconditionフィールドで処理**

#### EventAreaからの使用例
```gdscript
# scripts/levels/event_area.gd
@export var event_id: String = ""
@export var one_shot: bool = true

# イベント設定リソース（AutoLoadで管理するか、exportで設定）
var event_config: EventConfigData

func _ready() -> void:
	# イベント設定リソースを読み込み
	event_config = load("res://data/event_config.tres")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and event_config != null:
		var player = body as Player

		# 実行回数を取得してリソースパスを決定
		var count: int = SaveLoadManager.get_event_count(event_id)
		var dialogue_resource: String = event_config.get_dialogue_resource(event_id, count)
		if dialogue_resource == "":
			return

		# ゲーム全体を停止
		PauseManager.pause_game()

		# イベント開始
		player.start_event()
		# ダイアログ表示（DialogueEvent内でプレイヤー状態に基づくメッセージフィルタリングを実行）
		EventManager.start_dialogue(dialogue_resource)

		# イベント終了を待機（シグナル接続で処理）
		# EventManager.event_finished.connect(_on_event_finished)

		# one_shotの場合、発火後にエリアを無効化
		if one_shot:
			monitoring = false

# イベント終了時の処理
func _on_event_finished() -> void:
	# ゲームを再開
	PauseManager.resume_game()
```

#### SaveLoadManagerの主要メソッド（既存実装）
```gdscript
# scripts/autoload/save_load_manager.gd
extends Node

# イベント実行回数を記録する辞書
var event_counts: Dictionary = {}  # { "001": 2, "002": 1, ... }

# イベント実行回数管理
func get_event_count(event_id: String) -> int:
	return event_counts.get(event_id, 0)

func increment_event_count(event_id: String) -> void:
	var current_count: int = get_event_count(event_id)
	event_counts[event_id] = current_count + 1

# セーブ/ロード機能
# - save_game(slot: int): セーブデータをJSON形式で保存（event_countsを含む）
# - load_game(slot: int): セーブデータを読み込み（event_countsを復元）
# - get_save_file_path(slot: int): セーブファイルのパスを取得
# - save_exists(slot: int): セーブデータの存在確認
# - get_save_timestamp(slot: int): セーブデータのタイムスタンプ取得
```

### DialogueData実装における注意事項
- **キャラクター管理**: 会話に登場するキャラクターは事前に`characters`配列で定義
  - `character_id`は"001", "002"などの数値文字列形式
- **ナレーション処理**:
  - `speaker_id`が空文字列("")の場合はナレーション扱いとする
  - ナレーション時の動作:
    - 話者名を非表示にする
    - 顔画像を非表示にする
    - テキストは通常通り表示される
- **メッセージインデックス管理**:
  - 各メッセージに一意の`index`文字列を付与（"0", "1", "2", "3-a", "3-b"など）
  - 選択肢による分岐では末尾にアルファベット（-a, -b, -c...）を付与
  - インデックス検索用のヘルパー関数: `get_message_by_index(index: String) -> DialogueMessage`
- **顔画像パス構築**: `get_face_image_path(speaker_id, emotion)`メソッドで動的に構築
- **表情のフォールバック**: `emotion`が空文字列の場合は`default_emotion`を使用
- **顔画像の柔軟性**:
  - 顔画像が存在しない、または表示されていない場合でも、テキスト表示は正常に動作する
  - 顔画像のロードエラーや非表示状態は、会話の進行を妨げない
- **型安全性**: CharacterInfo、DialogueMessage、DialogueChoiceは全てtyped配列で管理
- **条件分岐処理**:
  - 各メッセージの`condition`フィールドでプレイヤー状態による表示条件を指定
  - `condition: ""` → 常に表示（プレイヤー状態に関係なく表示）
  - `condition: "normal"` → プレイヤーがnormal状態の時のみ表示
  - `condition: "expansion"` → プレイヤーがexpansion状態の時のみ表示
  - DialogueEvent内で`filter_messages_by_condition()`を使用してフィルタリング
  - 1つのDialogueDataリソース内に複数の状態に対応するメッセージを含めることが可能
- **多言語対応**:
  - `speaker_name`と`text`は辞書形式: `{"ja": "日本語", "en": "English"}`
  - 実行時に`GameSettings.current_language`に基づいて適切な言語を取得
  - 言語キーの取得方法:
    - `GameSettings.get_language_name().to_lower().substr(0, 2)` で言語コード（"ja", "en"）を取得
    - または、DialogueData側で`Language.JAPANESE`の場合は"ja"、`Language.ENGLISH`の場合は"en"にマッピング
  - 例: `speaker_name[language_code]` または `text[language_code]`
  - 言語設定はGameSettings（AutoLoad: `scripts/autoload/game_settings.gd`）で管理
  - **GameSettingsの主要API**:
    - `GameSettings.current_language`: 現在の言語（Language.JAPANESE または Language.ENGLISH）
    - `GameSettings.get_language_name()`: 言語名を取得（"Japanese" または "English"）
    - `GameSettings.set_language(language: Language)`: 言語を設定
    - `GameSettings.toggle_language()`: 言語を切り替え（Japanese ⇔ English）
    - `GameSettings.language_changed` シグナル: 言語変更時に発信される

## イベント発火の仕様

### 1. EventArea経由（自動発火）
- **event_id駆動**: 各EventAreaは`event_id`でEventConfigDataからイベント設定を識別
- プレイヤーがエリアに侵入すると自動的にイベント開始
- **プレイヤー状態による条件分岐**:
  - DialogueDataリソース内のメッセージのconditionフィールドで処理
  - DialogueEvent実行時に`player.get_current_state()`で現在の状態を取得し、メッセージをフィルタリング
  - 例: 同じイベントでもnormal状態とexpansion状態で異なる会話を表示
- **`one_shot = true`**: 一度だけ発火（デフォルト）
  - 発火後、`monitoring = false`でエリアを無効化
  - SaveLoadManagerにイベント実行回数を記録
- **`one_shot = false`**: 何度でも発火
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
2. EventConfigDataリソース（event_config.tres）を読み込み
   ↓
3. SaveLoadManager.get_event_count(event_id) で実行回数を取得
   ↓
4. event_config.get_dialogue_resource(event_id, count) でリソースパス取得
   ├─ EventConfigから該当するevent_idのdialogue_resourcesを取得
   ├─ 実行回数に応じたリソースを選択
   ├─ 初回（count=0） → dialogue_resources[0]（例: event_001_01.tres）
   ├─ 2回目（count=1） → dialogue_resources[1]（例: event_001_02.tres）
   ├─ 3回目（count=2） → dialogue_resources[2]（例: event_001_03.tres）
   └─ N回目以降 → dialogue_resources[last]（配列の最後の要素をリピート）
   ↓
5. EventManager.start_event() 呼び出し:
   a. player.start_event() でプレイヤーをEVENT状態に遷移
   b. PauseManager.pause_game() でゲーム全体を停止（背景のゲームプレイを停止）
   ↓
6. EventManager.start_dialogue(resource_path) でイベント実行
   a. DialogueDataリソースを読み込み
   b. DialogueEvent内でプレイヤーの現在の状態を取得
   c. メッセージ配列をプレイヤー状態でフィルタリング
      - 各メッセージのconditionフィールドをチェック
      - condition == "" または condition == player_state のメッセージのみを表示
   ↓
7. イベント終了後、EventManager._on_event_finished() 呼び出し:
   a. PauseManager.resume_game() でゲームを再開
   b. player.end_event() でIDLE状態に復帰
   ↓
8. SaveLoadManager.increment_event_count(event_id) で実行回数を記録
   ↓
9. one_shot=true の場合、EventAreaを無効化
```

## UI詳細仕様

### メッセージウィンドウ（DialogueBox）
- **配置**: 画面下部
- **サイズ**: 画面の縦幅の1/4（25%）
- **背景**: 黒色 (Color: #000000, Alpha: 0.5)
- **エフェクト**: 上部にフェード（グラデーション）を適用
- **テキスト**: 白色、1文字ずつ表示アニメーション
- **キャラクター名表示**: メッセージウィンドウ上部または左上に表示

### 顔画像表示（DialogueBox内）
- **配置**: メッセージウィンドウの左上
- **サイズ**: メッセージウィンドウ高さの約70%（正方形）
  - 例: メッセージウィンドウが200pxの高さの場合、顔画像は140x140px程度
- **エフェクト**:
  - 表示/非表示時のフェードイン/アウト
  - 話者が変わる際にフェード切り替え
- **ナレーション時**（speaker_idが空文字列""の場合）:
  - 顔画像を非表示
  - 話者名は非表示
- **顔画像がない場合の動作**:
  - 顔画像が存在しない場合でも、テキストは正常に表示される
  - 顔画像のロードエラーは会話の進行を妨げない

### DialogueBoxシーンのノード構成

**シーンファイル**: `scenes/dialogue/dialogue_box.tscn`
**アタッチスクリプト**: `scripts/dialogue/dialogue_box.gd`

#### ノード階層

```
DialogueBox (PanelContainer)
├── MarginContainer
│   └── VBoxContainer
│       ├── HBoxContainer (speaker_row)
│       │   ├── FaceImage (TextureRect)
│       │   └── VBoxContainer (text_column)
│       │       ├── SpeakerName (Label)
│       │       └── DialogueText (RichTextLabel)
│       └── HSeparator (optional)
```

#### 各ノードの詳細設定

**1. DialogueBox (PanelContainer)** - ルートノード
- **ノードタイプ**: `PanelContainer`
- **Custom Minimum Size**: 横幅1152px（プロジェクト解像度に合わせる）、縦幅200px（画面の約1/4）
- **Layout**:
  - Anchor Preset: `Bottom Wide`（画面下部全体に配置）
  - Grow Direction: `Begin`（上方向に成長）
  - Offset Top: `-200` （下から200px）
  - Offset Bottom: `0`
- **Theme Override / Styles**:
  - StyleBoxFlat を作成:
    - Background Color: `#000000`（黒）
    - Alpha: `0.5`（半透明）
    - Border Width: すべて `0`
    - Corner Radius: 上部のみ `8px`（上部を丸める）
- **Process Mode**: `PROCESS_MODE_ALWAYS`（ポーズ中も動作）

**2. MarginContainer** - 内側の余白管理
- **ノードタイプ**: `MarginContainer`
- **Theme Override / Constants**:
  - Margin Left: `24`
  - Margin Top: `16`
  - Margin Right: `24`
  - Margin Bottom: `16`

**3. VBoxContainer** - 縦方向レイアウト
- **ノードタイプ**: `VBoxContainer`
- **Theme Override / Constants**:
  - Separation: `8`（子要素間のスペース）

**4. HBoxContainer (speaker_row)** - 顔画像とテキストの横並び
- **ノードタイプ**: `HBoxContainer`
- **Name**: `SpeakerRow`
- **Theme Override / Constants**:
  - Separation: `16`（顔画像とテキストのスペース）

**5. FaceImage (TextureRect)** - 顔画像表示
- **ノードタイプ**: `TextureRect`
- **Name**: `FaceImage`
- **Custom Minimum Size**: `140x140` px（メッセージウィンドウ高さ200pxの70%）
- **Expand Mode**: `Keep Size`
- **Stretch Mode**: `Scale`
- **Modulate**: `Color(1, 1, 1, 1)`（初期は完全不透明、フェード用にTweenで変更）
- **Visibility**: 初期状態では `visible = true`（スクリプトで制御）

**6. VBoxContainer (text_column)** - 話者名とテキストの縦並び
- **ノードタイプ**: `VBoxContainer`
- **Name**: `TextColumn`
- **Size Flags Horizontal**: `Expand + Fill`（横方向に拡張）
- **Theme Override / Constants**:
  - Separation: `4`（話者名とテキストのスペース）

**7. SpeakerName (Label)** - 話者名表示
- **ノードタイプ**: `Label`
- **Name**: `SpeakerName`
- **Text**: `"話者名"`（プレースホルダー、実行時に動的変更）
- **Theme Override / Font Sizes**: `20`
- **Theme Override / Colors**:
  - Font Color: `#FFD700`（ゴールド、話者名を強調）
- **Autowrap Mode**: `Off`（折り返しなし）

**8. DialogueText (RichTextLabel)** - メッセージテキスト表示
- **ノードタイプ**: `RichTextLabel`
- **Name**: `DialogueText`
- **Text**: `"ここにメッセージが表示されます"`（プレースホルダー）
- **Theme Override / Font Sizes**: `16`
- **Theme Override / Colors**:
  - Default Font Color: `#FFFFFF`（白）
- **BBCode Enabled**: `true`（リッチテキスト対応、将来の拡張用）
- **Fit Content**: `true`（コンテンツに合わせてサイズ調整）
- **Scroll Active**: `false`（スクロール不要）
- **Visible Characters**: `-1`（初期状態、スクリプトで1文字ずつ表示制御）
- **Size Flags Vertical**: `Expand + Fill`（縦方向に拡張）

**9. HSeparator (optional)** - 区切り線（オプション）
- **ノードタイプ**: `HSeparator`
- **Name**: `Separator`
- **Visible**: `false`（必要に応じて表示）

#### シーン作成手順（Godotエディタ）

1. **新規シーン作成**:
   - FileMenuから「New Scene」
   - `PanelContainer`をルートノードとして選択
   - ノード名を`DialogueBox`に変更

2. **PanelContainerの設定**:
   - InspectorでLayout → Anchor Preset → `Bottom Wide`を選択
   - Rect → Size → yを`200`に設定
   - Theme Overrides → Styles → Panelを追加:
     - 新規`StyleBoxFlat`を作成
     - Bg Colorを`#000000`、Alphaを`128`（0.5の場合）に設定
     - Border Widthをすべて`0`に設定
     - Corner Radiusの`Top Left`と`Top Right`を`8`に設定

3. **子ノードの追加**（階層順）:
   - `DialogueBox`を右クリック → Add Child Node → `MarginContainer`
   - `MarginContainer`を右クリック → Add Child Node → `VBoxContainer`
   - `VBoxContainer`を右クリック → Add Child Node → `HBoxContainer`（名前を`SpeakerRow`に変更）
   - `SpeakerRow`を右クリック → Add Child Node → `TextureRect`（名前を`FaceImage`に変更）
   - `SpeakerRow`を右クリック → Add Child Node → `VBoxContainer`（名前を`TextColumn`に変更）
   - `TextColumn`を右クリック → Add Child Node → `Label`（名前を`SpeakerName`に変更）
   - `TextColumn`を右クリック → Add Child Node → `RichTextLabel`（名前を`DialogueText`に変更）

4. **各ノードのプロパティ設定**:
   - 上記「各ノードの詳細設定」に従って、Inspectorで各プロパティを設定

5. **シーン保存**:
   - Scene → Save Scene As... → `scenes/dialogue/dialogue_box.tscn`

6. **スクリプトアタッチ**:
   - `DialogueBox`ノードを選択
   - Attach Script → `scripts/dialogue/dialogue_box.gd`を作成
   - スクリプト内で`@onready`でノード参照をキャッシュ:
     ```gdscript
     extends PanelContainer

     @onready var face_image: TextureRect = $MarginContainer/VBoxContainer/SpeakerRow/FaceImage
     @onready var speaker_name: Label = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/SpeakerName
     @onready var dialogue_text: RichTextLabel = $MarginContainer/VBoxContainer/SpeakerRow/TextColumn/DialogueText
     ```

#### ノード構成の設計思想

- **PanelContainerをルート**に選択: 背景スタイリング（StyleBoxFlat）を直接適用可能
- **MarginContainerで余白管理**: テキストが枠に接触しないよう内側に余白を確保
- **VBoxContainerで縦レイアウト**: 話者情報とテキストを縦に配置、将来の拡張（選択肢表示など）に対応
- **HBoxContainerで横レイアウト**: 顔画像とテキストを横並びに配置
- **TextureRectで顔画像**: 画像の拡大縮小を適切に処理、Tweenでフェード制御
- **Labelで話者名**: シンプルなテキスト表示、色で強調
- **RichTextLabelでメッセージ**: BBCode対応で将来的に太字・色変更などの拡張可能、Visible Charactersで1文字ずつ表示制御

#### スクリプト側での制御ポイント

```gdscript
# scripts/dialogue/dialogue_box.gd (抜粋)

# 顔画像のフェード表示
func show_face_image(texture: Texture2D) -> void:
    face_image.texture = texture
    var tween = create_tween()
    tween.tween_property(face_image, "modulate:a", 1.0, 0.3)

# 顔画像の非表示（ナレーション時）
func hide_face_image() -> void:
    var tween = create_tween()
    tween.tween_property(face_image, "modulate:a", 0.0, 0.3)

# 話者名の設定
func set_speaker_name(name: String) -> void:
    if name == "":
        speaker_name.visible = false
    else:
        speaker_name.text = name
        speaker_name.visible = true

# テキストの1文字ずつ表示
func display_text(text: String, speed: float = 0.05) -> void:
    dialogue_text.text = text
    dialogue_text.visible_characters = 0
    var char_count = text.length()
    for i in range(char_count):
        dialogue_text.visible_characters = i + 1
        await get_tree().create_timer(speed).timeout
```

### DialogueSystemシーンのノード構成

**シーンファイル**: `scenes/dialogue/dialogue_system.tscn`
**アタッチスクリプト**: `scripts/dialogue/dialogue_system.gd`

#### ノード階層

```
DialogueSystem (CanvasLayer)
├── DialogueBoxContainer (Control)
│   └── DialogueBox (インスタンス: dialogue_box.tscn)
└── DialogueChoicesContainer (Control)
    └── VBoxContainer
        ├── ChoiceButton1 (インスタンス: dialogue_choice.tscn)
        └── ChoiceButton2 (インスタンス: dialogue_choice.tscn)
```

#### 各ノードの詳細設定

**1. DialogueSystem (CanvasLayer)** - ルートノード
- **ノードタイプ**: `CanvasLayer`
- **Layer**: `50`（UI表示用、TransitionManagerのlayer=100より下）
- **Process Mode**: `PROCESS_MODE_ALWAYS`（ポーズ中も動作）
- **Follow Viewport Enabled**: `true`（ビューポートに追従）

**2. DialogueBoxContainer (Control)** - DialogueBoxの配置コンテナ
- **ノードタイプ**: `Control`
- **Name**: `DialogueBoxContainer`
- **Layout**: `Full Rect`（画面全体に配置）
- **Mouse Filter**: `Ignore`（クリックイベントを無視）

**3. DialogueBox (インスタンス)** - メッセージウィンドウ
- **シーンインスタンス**: `scenes/dialogue/dialogue_box.tscn`をインスタンス化
- 親ノード: `DialogueBoxContainer`
- 配置: 画面下部（dialogue_box.tscn内で設定済み）

**4. DialogueChoicesContainer (Control)** - 選択肢の配置コンテナ
- **ノードタイプ**: `Control`
- **Name**: `DialogueChoicesContainer`
- **Layout**: `Full Rect`（画面全体に配置）
- **Mouse Filter**: `Ignore`（親はクリック無視、子のボタンのみ反応）
- **Visibility**: 初期状態では `visible = false`（選択肢表示時のみ表示）

**5. VBoxContainer** - 選択肢の縦並びレイアウト
- **ノードタイプ**: `VBoxContainer`
- **Anchor Preset**: `Center`（画面中央に配置）
- **Grow Horizontal/Vertical**: `Both`（中央から成長）
- **Alignment**: `Vertical = Center`, `Horizontal = Center`
- **Theme Override / Constants**:
  - Separation: `16`（選択肢間のスペース）

**6-7. ChoiceButton1, ChoiceButton2 (インスタンス)** - 選択肢ボタン
- **シーンインスタンス**: `scenes/dialogue/dialogue_choice.tscn`をインスタンス化（最大2つ）
- 親ノード: `VBoxContainer`
- 必要に応じて動的に追加・削除

#### シーン作成手順（Godotエディタ）

1. **新規シーン作成**:
   - FileMenuから「New Scene」
   - `CanvasLayer`をルートノードとして選択
   - ノード名を`DialogueSystem`に変更

2. **CanvasLayerの設定**:
   - InspectorでLayer → `50`に設定
   - Process → Mode → `Always`を選択

3. **子ノードの追加**（階層順）:
   - `DialogueSystem`を右クリック → Add Child Node → `Control`（名前を`DialogueBoxContainer`に変更）
   - `DialogueBoxContainer`のLayoutを`Full Rect`に設定
   - `DialogueBoxContainer`を右クリック → Instantiate Child Scene → `scenes/dialogue/dialogue_box.tscn`を選択

   - `DialogueSystem`を右クリック → Add Child Node → `Control`（名前を`DialogueChoicesContainer`に変更）
   - `DialogueChoicesContainer`のLayoutを`Full Rect`に設定、`visible = false`に設定
   - `DialogueChoicesContainer`を右クリック → Add Child Node → `VBoxContainer`
   - `VBoxContainer`のAnchor Presetを`Center`に設定

4. **シーン保存**:
   - Scene → Save Scene As... → `scenes/dialogue/dialogue_system.tscn`

5. **スクリプトアタッチ**:
   - `DialogueSystem`ノードを選択
   - Attach Script → `scripts/dialogue/dialogue_system.gd`を作成
   - スクリプト内で`@onready`でノード参照をキャッシュ:
     ```gdscript
     extends CanvasLayer

     @onready var dialogue_box: PanelContainer = $DialogueBoxContainer/DialogueBox
     @onready var choices_container: Control = $DialogueChoicesContainer
     @onready var choices_vbox: VBoxContainer = $DialogueChoicesContainer/VBoxContainer

     # 選択肢ボタンのシーンをプリロード
     const CHOICE_BUTTON_SCENE = preload("res://scenes/dialogue/dialogue_choice.tscn")
     ```

#### スクリプト側での制御ポイント

```gdscript
# scripts/dialogue/dialogue_system.gd (抜粋)

# ダイアログシステムの表示
func show_dialogue() -> void:
    show()  # CanvasLayerを表示
    dialogue_box.show()

# ダイアログシステムの非表示
func hide_dialogue() -> void:
    dialogue_box.hide()
    choices_container.hide()
    hide()  # CanvasLayerを非表示

# 選択肢を動的に生成
func show_choices(choice_texts: Array[String]) -> void:
    # 既存の選択肢をクリア
    for child in choices_vbox.get_children():
        child.queue_free()

    # 新しい選択肢を生成（最大2つ）
    for i in range(min(choice_texts.size(), 2)):
        var choice_button = CHOICE_BUTTON_SCENE.instantiate()
        choices_vbox.add_child(choice_button)
        choice_button.set_text(choice_texts[i])
        choice_button.choice_selected.connect(_on_choice_selected.bind(i))

    choices_container.show()

# 選択肢の非表示
func hide_choices() -> void:
    choices_container.hide()
    # 選択肢ボタンをクリア
    for child in choices_vbox.get_children():
        child.queue_free()

# 選択肢が選択された時の処理
func _on_choice_selected(choice_index: int) -> void:
    hide_choices()
    # 選択結果をDialogueEventに通知
    emit_signal("choice_made", choice_index)
```

### DialogueChoiceシーンのノード構成

**シーンファイル**: `scenes/dialogue/dialogue_choice.tscn`
**アタッチスクリプト**: `scripts/dialogue/dialogue_choice.gd`

#### ノード階層

```
ChoiceButton (Button)
└── Label (選択肢テキスト表示)
```

#### 各ノードの詳細設定

**1. ChoiceButton (Button)** - ルートノード
- **ノードタイプ**: `Button`
- **Custom Minimum Size**: 横幅`400px`、縦幅`60px`
- **Text**: 空（Labelで表示）
- **Theme Override / Styles**:
  - Normal: `StyleBoxFlat`を作成
    - Background Color: `#1A1A1A`（ダークグレー）
    - Alpha: `0.8`（半透明）
    - Border Width: すべて `2`
    - Border Color: `#FFFFFF`（白）
    - Corner Radius: すべて `8px`
  - Hover: `StyleBoxFlat`を作成
    - Background Color: `#333333`（明るいグレー）
    - Alpha: `0.9`
    - Border Width: すべて `3`
    - Border Color: `#FFD700`（ゴールド）
    - Corner Radius: すべて `8px`
  - Pressed: `StyleBoxFlat`を作成
    - Background Color: `#FFD700`（ゴールド）
    - Alpha: `0.5`
    - Border Width: すべて `3`
    - Border Color: `#FFFFFF`（白）
    - Corner Radius: すべて `8px`
  - Focus: Hoverと同じスタイル
- **Focus Mode**: `All`（キーボードフォーカス対応）

**2. Label** - 選択肢テキスト表示（オプション、Buttonの内部テキストでも可）
- **ノードタイプ**: `Label`
- **Anchor Preset**: `Full Rect`（ボタン全体に配置）
- **Horizontal Alignment**: `Center`
- **Vertical Alignment**: `Center`
- **Theme Override / Font Sizes**: `18`
- **Theme Override / Colors**:
  - Font Color: `#FFFFFF`（白）
- **Autowrap Mode**: `Word Smart`（長いテキストは折り返し）

#### シーン作成手順（Godotエディタ）

1. **新規シーン作成**:
   - FileMenuから「New Scene」
   - `Button`をルートノードとして選択
   - ノード名を`ChoiceButton`に変更

2. **Buttonの設定**:
   - InspectorでCustom Minimum Size → x: `400`, y: `60`に設定
   - Theme Overrides → Styles → Normal, Hover, Pressed, Focusを上記設定に従って作成
   - Focus → Mode → `All`を選択

3. **Labelの追加**（オプション）:
   - `ChoiceButton`を右クリック → Add Child Node → `Label`
   - Anchor Presetを`Full Rect`に設定
   - Horizontal/Vertical Alignmentを`Center`に設定
   - Theme Overrides → Font Sizeを`18`に設定
   - Theme Overrides → Colors → Font Colorを`#FFFFFF`に設定

4. **シーン保存**:
   - Scene → Save Scene As... → `scenes/dialogue/dialogue_choice.tscn`

5. **スクリプトアタッチ**:
   - `ChoiceButton`ノードを選択
   - Attach Script → `scripts/dialogue/dialogue_choice.gd`を作成
   - スクリプト内でシグナルとテキスト設定を実装:
     ```gdscript
     extends Button

     signal choice_selected

     @onready var label: Label = $Label  # Labelを使う場合

     # 選択肢テキストを設定
     func set_text(choice_text: String) -> void:
         # Labelを使う場合
         label.text = choice_text
         # または、Buttonの内部テキストを使う場合
         # text = choice_text

     func _ready() -> void:
         # ボタンが押された時にシグナルを発信
         pressed.connect(_on_pressed)

     func _on_pressed() -> void:
         choice_selected.emit()
     ```

#### スクリプト側での制御ポイント

```gdscript
# scripts/dialogue/dialogue_choice.gd (完全版)

extends Button

signal choice_selected

@onready var label: Label = $Label

# 選択肢テキストを設定
func set_text(choice_text: String) -> void:
    label.text = choice_text

# ボタンが押された時の処理
func _ready() -> void:
    pressed.connect(_on_pressed)

func _on_pressed() -> void:
    choice_selected.emit()

# キーボード入力対応（↑↓で選択移動）
func _input(event: InputEvent) -> void:
    if has_focus():
        # Enterキー/Zキーで決定
        if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
            _on_pressed()
```

#### ノード構成の設計思想

- **Buttonをルート**に選択: クリック/キーボード入力を標準的に処理
- **StyleBoxFlatでビジュアル制御**: Normal/Hover/Pressed状態で異なるスタイルを適用し、視覚的フィードバックを提供
- **Focus Mode対応**: キーボードナビゲーション（↑↓キー）で選択肢間を移動可能
- **Labelでテキスト表示**: 中央配置、折り返し対応で長いテキストにも対応
- **シグナル駆動**: `choice_selected`シグナルでDialogueSystemに通知、疎結合を維持

### 選択肢表示
- **配置**: 画面中央に縦並び
- **スタイル**: 半透明背景のボタン
- **操作**:
  - ↑↓ / WSキーで選択移動
  - Zキー / Enterキーで決定
- **最大数**: 2つまで

### 入力操作
- **Zキー / Enterキー**: テキスト送り、選択肢決定
- **↑↓ / WSキー**: 選択肢の移動
- **Shiftキー（長押し）**: 会話の高速スキップ

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

#### 例1: 基本的な会話（conditionなし）
```gdscript
# DialogueDataリソースの設定例
characters = [
    {
        "character_id": "001",
        "speaker_name": {"ja": "鈴蘭", "en": "Suzuran"},
        "face_image_path": "res://assets/images/faces/player/",
        "default_emotion": "normal"
    },
    {
        "character_id": "002",
        "speaker_name": {"ja": "商人", "en": "Merchant"},
        "face_image_path": "res://assets/images/faces/npcs/merchant/",
        "default_emotion": "smile"
    }
]

messages = [
    {
        "index": "0",
        "speaker_id": "002",
        "text": {"ja": "いらっしゃいませ！", "en": "Welcome!"},
        "emotion": "smile",
        "choices": [],
        "condition": ""  # 条件なし（常に表示）
    },
    {
        "index": "1",
        "speaker_id": "001",
        "text": {"ja": "手裏剣を買いたいのですが...", "en": "I'd like to buy some shuriken..."},
        "emotion": "",  # 空文字列 → default_emotion("normal")を使用
        "choices": [],
        "condition": ""
    },
    {
        "index": "2",
        "speaker_id": "002",
        "text": {"ja": "手裏剣ですか。どうしましょう？", "en": "Shuriken, you say. What would you like to do?"},
        "emotion": "thinking",
        "choices": [
            {"text": {"ja": "買う", "en": "Buy"}, "next_index": "3-a"},
            {"text": {"ja": "やめておく", "en": "Never mind"}, "next_index": "3-b"}
        ],
        "condition": ""
    },
    {
        "index": "3-a",  # 「買う」を選択した場合
        "speaker_id": "002",
        "text": {"ja": "ありがとうございます！", "en": "Thank you very much!"},
        "emotion": "happy",
        "choices": [],
        "condition": ""
    },
    {
        "index": "3-b",  # 「やめておく」を選択した場合
        "speaker_id": "002",
        "text": {"ja": "またのお越しをお待ちしております。", "en": "We look forward to seeing you again."},
        "emotion": "smile",
        "choices": [],
        "condition": ""
    }
]
```

#### 例2: プレイヤー状態による分岐（conditionあり）
```gdscript
# DialogueDataリソースの設定例（プレイヤー状態で会話が変わる）
characters = [
    {
        "character_id": "001",
        "speaker_name": {"ja": "鈴蘭", "en": "Suzuran"},
        "face_image_path": "res://assets/images/faces/player/",
        "default_emotion": "normal"
    },
    {
        "character_id": "003",
        "speaker_name": {"ja": "門番", "en": "Guard"},
        "face_image_path": "res://assets/images/faces/npcs/guard/",
        "default_emotion": "serious"
    }
]

messages = [
    # normal状態の場合のメッセージ
    {
        "index": "0",
        "speaker_id": "003",
        "text": {"ja": "ここから先は関係者以外立入禁止だ。", "en": "No unauthorized personnel beyond this point."},
        "emotion": "serious",
        "choices": [],
        "condition": "normal"  # normal状態の時のみ表示
    },
    {
        "index": "1",
        "speaker_id": "001",
        "text": {"ja": "なんとか通してもらえませんか？", "en": "Can you please let me through?"},
        "emotion": "worried",
        "choices": [],
        "condition": "normal"
    },
    {
        "index": "2",
        "speaker_id": "003",
        "text": {"ja": "ダメだ。規則は規則だ。", "en": "No. Rules are rules."},
        "emotion": "angry",
        "choices": [],
        "condition": "normal"
    },
    # expansion状態の場合のメッセージ
    {
        "index": "0",
        "speaker_id": "003",
        "text": {"ja": "おっと、その体では通れまい。", "en": "Whoa, you can't fit through with that body."},
        "emotion": "surprised",
        "choices": [],
        "condition": "expansion"  # expansion状態の時のみ表示
    },
    {
        "index": "1",
        "speaker_id": "001",
        "text": {"ja": "くっ...なんてこと。", "en": "Damn... this is bad."},
        "emotion": "embarrassed",
        "choices": [],
        "condition": "expansion"
    },
    {
        "index": "2",
        "speaker_id": "003",
        "text": {"ja": "元の姿に戻ってから出直してくれ。", "en": "Come back after you return to normal."},
        "emotion": "smile",
        "choices": [],
        "condition": "expansion"
    }
]
```

**conditionフィールドの動作**:
- `condition: ""` → 常に表示（プレイヤー状態に関係なく表示）
- `condition: "normal"` → プレイヤーがnormal状態の時のみ表示
- `condition: "expansion"` → プレイヤーがexpansion状態の時のみ表示
- DialogueEvent内で `filter_messages_by_condition()` を使用してフィルタリング
```

### UI配置
- 画面中央に選択肢ボタンを縦並び表示
- 最大2つまでの選択肢に対応
- 選択後はボタンを非表示にして会話を続行

## event_id駆動設計の利点

### 1. コードの再利用性と保守性
- **共通ロジックの一元管理**: EventArea.gdに共通処理を集約
- **設定のリソース化**: イベント固有の設定はEventConfigDataリソースに集約
- **変更の局所化**: 共通処理の修正は一箇所で済み、設定変更はエディタで直感的に編集可能

### 2. 拡張性と柔軟性
- **新イベントの追加が容易**: event_config.tresに新しいイベント設定を追加するだけ
- **コードファイル不要**: 個別スクリプトファイルを作成する必要がない
- **視覚的な編集**: Godotエディタのインスペクタで設定を編集可能

### 3. データ駆動開発
- **シーンエディタで管理**: EventAreaインスタンスごとに`event_id`を設定
- **一括管理**: 全イベント設定を一つのtresファイルで管理
- **デザイナーフレンドリー**: プログラマでなくてもイベント設定を追加・編集可能

## event_id駆動設計のベストプラクティス

### 1. リソースファイルの命名規則

#### 基本命名パターン
- **統一形式**: `event_[ID]_[回数].tres`
  - 例: `event_001_01.tres`, `event_001_02.tres`
- **IDは3桁のゼロパディング**: `001`, `002`, `003`...
- **回数は2桁のゼロパディング**: `01`, `02`, `03`...
- **配列順序と一致**: dialogue_resources配列のインデックス順にファイル番号を付与
- **リピート用リソース**: 配列の最後の要素が2回目以降すべてに使用される
- **一貫性の維持**: プロジェクト全体で統一されたルールを適用
- **プレイヤー状態による分岐**: ファイル名ではなく、各DialogueData内のメッセージのconditionフィールドで処理

#### 命名例

**パターン1: シンプルなイベント**
```
event_001_01.tres  # 初回
event_001_02.tres  # 2回目以降（リピート）
```

**パターン2: 複数回異なる会話**
```
event_003_01.tres  # 1回目
event_003_02.tres  # 2回目
event_003_03.tres  # 3回目
event_003_04.tres  # 4回目以降（リピート）
```

**パターン3: プレイヤー状態による分岐を含むイベント**
```
# event_004_01.tres の中身:
# - normal状態のメッセージ（condition: "normal"）
# - expansion状態のメッセージ（condition: "expansion"）
# の両方を含む

event_004_01.tres  # 初回（内部でプレイヤー状態により分岐）
event_004_02.tres  # 2回目以降（内部でプレイヤー状態により分岐）
```

### 2. SaveLoadManagerとの連携
- **イベント実行回数の記録**: EventManagerがイベント完了時に自動的に記録
- **セーブ/ロード**: SaveLoadManagerがイベント実行回数（event_counts）をセーブデータに保存/復元
- **永続化**: セーブデータにはevent_countsが含まれ、ロード時に復元される

### 3. イベントシステムとセーブ機能の統合仕様

#### 設計の背景
当初、イベント実行回数を管理する専用のAutoLoad「GameProgress」を導入する計画でしたが、既存のSaveLoadManagerが同等の機能を実装していることが判明しました。設計の重複を避け、保守性を向上させるため、SaveLoadManagerを拡張する方針に変更しました。

#### SaveLoadManagerの役割
- **イベント実行回数管理**: `event_counts: Dictionary`でイベントIDごとの実行回数を保持
- **セーブデータの永続化**: JSON形式でイベント実行回数を保存（user://save_XXX.json）
- **ロード時の復元**: セーブデータからイベント実行回数を復元し、ゲーム進行状態を正確に再現

#### セーブデータの構造（event_countsフィールド）
```json
{
  "save_number": 1,
  "timestamp": "2025-10-18T15:30:45",
  "current_scene": "res://scenes/levels/level_0.tscn",
  "player_data": { ... },
  "event_counts": {
    "001": 2,  // イベント001は2回実行済み
    "002": 1,  // イベント002は1回実行済み
    "003": 0   // イベント003は未実行
  }
}
```

#### データフロー
```
イベント発火
    ↓
SaveLoadManager.get_event_count(event_id) で実行回数取得
    ↓
EventConfigData.get_dialogue_resource(event_id, count) で適切なリソース選択
    ↓
イベント実行（DialogueEvent）
    ↓
イベント完了
    ↓
SaveLoadManager.increment_event_count(event_id) で実行回数をカウントアップ
    ↓
セーブ時: event_counts辞書をJSON形式で保存
    ↓
ロード時: JSONから復元してevent_counts辞書を再構築
```

#### 統合のメリット
1. **コードの重複を回避**: 新規AutoLoad（GameProgress）を追加せず、既存実装を活用
2. **保守性の向上**: イベント実行回数とセーブ機能が同一箇所で管理される
3. **データ整合性**: セーブ/ロード処理とイベント管理が密結合し、状態の不整合を防止
4. **実装の簡略化**: 新規AutoLoadの作成、登録、テストが不要

## まとめ

event_id駆動設計とEventConfigDataリソースにより、以下を実現：

1. **リソースベースの設計**: 全イベント設定を一つのtresファイルで一括管理
2. **データ駆動開発**: シーンエディタでイベントを管理し、視覚的に配置
3. **拡張性**: 新イベントの追加はevent_config.tresに設定を追加するだけ
4. **保守性**: 共通処理の変更が一箇所で済み、設定変更もエディタで簡単
5. **コードの削減**: 個別スクリプトファイルが不要で、プロジェクト構造がシンプル
6. **プレイヤー状態連動**: normalやexpansionなどのプレイヤー状態に応じた会話分岐
7. **柔軟なリソース管理**: 実行回数に応じた複数パターンの会話を配列で管理
8. **ファイル内条件分岐**: DialogueData内のconditionフィールドでプレイヤー状態による分岐を処理
9. **シンプルな命名規則**: `event_XXX_YY.tres`形式で一貫性を保持
10. **設計の簡略化**: ConditionConfigを削除し、EventConfigとEventConfigDataを簡略化
11. **セーブ/ロード統合**: SaveLoadManagerによるイベント実行回数の永続化（event_countsをJSON形式で保存/復元）
12. **既存実装の活用**: 既存のSaveLoadManagerを拡張し、新規AutoLoad（GameProgress）の重複を回避

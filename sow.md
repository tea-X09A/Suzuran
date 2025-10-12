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
  - **pause_managerとの連携**（イベント実行中のゲーム停止）:
    - イベント開始時に`PauseManager.pause_game()`を呼び出してゲーム全体を停止
    - イベント終了時に`PauseManager.resume_game()`を呼び出してゲームを再開
    - これにより、イベント中は背景のゲームプレイ（敵の動き、タイマーなど）が完全に停止する
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
- **EventConfigData参照**: `event_id`に基づいてEventConfigDataリソースからイベント設定を取得
  - 例: `event_id = "001"` → event_config.tres内の"001"設定を参照
- **`one_shot`機能**: 一度だけ発火するか、何度でも発火するかを制御

#### EventConfigData（イベント設定リソース）
- 全イベントの設定を一つのtresファイルで一括管理
- **主な機能**:
  - **条件判定**: `can_trigger(event_id, player_state) -> bool` - プレイヤー状態に基づくイベント発火条件のチェック
  - **リソース選択**: `get_dialogue_resource(event_id, count) -> String` - 実行回数に基づくリソースパス取得
  - **設定取得**: `get_event_config(event_id) -> EventConfig` - イベントIDから設定を取得

- **EventConfig構造**:
  - `event_id: String` - イベント識別子（"001", "002"など）
  - `conditions: Array[ConditionConfig]` - 条件とリソースのペアの配列
    - 複数の条件を持つことで、同じevent_idでもプレイヤー状態に応じて異なる会話を表示可能
    - 配列の上から順に評価され、最初にマッチした条件のリソースが使用される
    - 空文字列("")のrequired_player_stateは「状態不問」として最後に配置すること

- **ConditionConfig構造**:
  - `required_player_state: String` - 必要なプレイヤー状態（"normal", "expansion"など、空文字列=""は状態不問）
  - `dialogue_resources: Array[String]` - DialogueDataリソースパスの配列（実行回数順: [01, 02, 03, ...]）
    - 例: `["res://data/dialogues/event_001_normal_01.tres", "res://data/dialogues/event_001_normal_02.tres"]`
    - インデックス0が初回、1が2回目、2が3回目...
    - 配列の範囲外の場合は最後の要素を返す（リピート用）

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
│   ├── condition_config.gd            # 条件設定リソースクラス（新規）
│   ├── event_config.gd                # イベント個別設定リソースクラス（新規）
│   └── event_config_data.gd           # イベント設定データリソースクラス（新規）
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
├── event_config.tres           # 全イベント設定を管理するリソース（新規）
└── dialogues/                  # DialogueDataリソース格納フォルダ（新規）
    ├── event_001_normal_01.tres      # イベント001・normal状態・1回目
    ├── event_001_normal_02.tres      # イベント001・normal状態・2回目以降
    ├── event_001_expansion_01.tres   # イベント001・expansion状態・1回目
    ├── event_001_expansion_02.tres   # イベント001・expansion状態・2回目以降
    ├── event_002_normal_01.tres      # イベント002・normal状態・1回目
    ├── event_002_normal_02.tres      # イベント002・normal状態・2回目以降
    ├── event_003_normal_01.tres      # イベント003・normal状態・1回目
    ├── event_003_normal_02.tres      # イベント003・normal状態・2回目
    ├── event_003_normal_03.tres      # イベント003・normal状態・3回目
    ├── event_003_normal_04.tres      # イベント003・normal状態・4回目以降
    └── ...                           # 他の会話データ
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

2. **イベント設定システム**
   - ConditionConfig リソースクラス実装（`scripts/events/condition_config.gd`）
   - EventConfig リソースクラス実装（`scripts/events/event_config.gd`）
   - EventConfigData リソースクラス実装（`scripts/events/event_config_data.gd`）
   - event_config.tres リソースファイル作成（Godotエディタで視覚的に作成）
   - EventArea共通スクリプト拡張（EventConfigData使用）

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
- **pause_managerとの統合**: イベント実行中はゲーム全体を停止し、プレイヤーに集中した体験を提供
- **event_id駆動設計**:
  - EventAreaは共通スクリプトを使用し、コードの重複を防止
  - 各EventAreaは`event_id`でイベントを識別
  - イベント固有の設定はEventConfigDataリソースに集約
  - 一つのtresファイルで全イベントの設定を一括管理

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

var event_config: EventConfigData

func _ready() -> void:
	# イベント設定リソースを読み込み
	event_config = load("res://data/event_config.tres")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and event_config != null:
		var player = body as Player

		# プレイヤーの現在の状態を取得
		var player_state: String = player.get_current_state()  # "normal", "expansion"など

		# 発火条件チェック（EventConfigDataを使用）
		if not event_config.can_trigger(event_id, player_state):
			return

		# 実行回数を取得してリソースパスを決定
		var count: int = GameProgress.get_event_count(event_id)
		var dialogue_resource: String = event_config.get_dialogue_resource(event_id, player_state, count)
		if dialogue_resource == "":
			return

		# ゲーム全体を停止（背景のゲームプレイを停止）
		PauseManager.pause_game()

		# イベント開始
		player.start_event()
		# ダイアログ表示
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
# scripts/events/condition_config.gd
# 条件と会話リソースのペア
class_name ConditionConfig
extends Resource

@export var required_player_state: String = ""       # 必要なプレイヤー状態（"normal", "expansion"など、空文字列=""は状態不問）
@export var dialogue_resources: Array[String] = []   # 実行回数順のDialogueDataパス配列
```

```gdscript
# scripts/events/event_config.gd
# イベント個別設定
class_name EventConfig
extends Resource

@export var event_id: String = ""                    # イベント識別子（"001", "002"など）
@export var conditions: Array[ConditionConfig] = []  # 条件とリソースのペアの配列
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

# プレイヤー状態に一致する条件設定を取得
func get_matching_condition(event_id: String, player_state: String) -> ConditionConfig:
	var config: EventConfig = get_event_config(event_id)
	if config == null or config.conditions.is_empty():
		return null

	# 配列の上から順に評価し、最初にマッチした条件を返す
	for condition in config.conditions:
		# 具体的な状態指定がある場合、プレイヤー状態と一致するかチェック
		if condition.required_player_state != "" and condition.required_player_state == player_state:
			return condition

	# 一致する具体的な条件がない場合、状態不問（""）の条件を探す
	for condition in config.conditions:
		if condition.required_player_state == "":
			return condition

	return null

# イベント発火条件チェック
func can_trigger(event_id: String, player_state: String) -> bool:
	var condition: ConditionConfig = get_matching_condition(event_id, player_state)
	return condition != null

# 実行回数に基づいてDialogueDataリソースパスを取得
func get_dialogue_resource(event_id: String, player_state: String, count: int) -> String:
	var condition: ConditionConfig = get_matching_condition(event_id, player_state)
	if condition == null or condition.dialogue_resources.is_empty():
		push_error("No matching condition or dialogue_resources is empty for event: %s, player_state: %s" % [event_id, player_state])
		return ""

	# countに対応するリソースを取得
	# 配列の範囲外の場合は最後の要素を返す（リピート用）
	var index: int = min(count, condition.dialogue_resources.size() - 1)
	return condition.dialogue_resources[index]
```

#### イベント設定リソースファイルの作成方法

**Godotエディタでの作成手順**:
1. Godotエディタで `res://data/event_config.tres` を新規作成
2. インスペクタで `EventConfigData` スクリプトをアタッチ
3. `events` 配列に `EventConfig` リソースを追加
4. 各 `EventConfig` の `conditions` 配列に `ConditionConfig` リソースを追加
5. 各 `ConditionConfig` に対して:
   - `required_player_state` を設定（"normal", "expansion"など）
   - `dialogue_resources` 配列にDialogueDataのパスを追加

**tres ファイルの実例**:
```
# data/event_config.tres
[gd_resource type="Resource" script_class="EventConfigData" load_steps=10 format=3 uid="uid://xxxxx"]

[ext_resource type="Script" path="res://scripts/events/event_config_data.gd" id="1_xxxxx"]
[ext_resource type="Script" path="res://scripts/events/event_config.gd" id="2_xxxxx"]
[ext_resource type="Script" path="res://scripts/events/condition_config.gd" id="3_xxxxx"]

[sub_resource type="Resource" id="ConditionConfig_event001_normal"]
script = ExtResource("3_xxxxx")
required_player_state = "normal"
dialogue_resources = Array[String](["res://data/dialogues/event_001_normal_01.tres", "res://data/dialogues/event_001_normal_02.tres"])

[sub_resource type="Resource" id="ConditionConfig_event001_expansion"]
script = ExtResource("3_xxxxx")
required_player_state = "expansion"
dialogue_resources = Array[String](["res://data/dialogues/event_001_expansion_01.tres", "res://data/dialogues/event_001_expansion_02.tres"])

[sub_resource type="Resource" id="EventConfig_001"]
script = ExtResource("2_xxxxx")
event_id = "001"
conditions = Array[ConditionConfig]([SubResource("ConditionConfig_event001_normal"), SubResource("ConditionConfig_event001_expansion")])

[sub_resource type="Resource" id="ConditionConfig_event002_normal"]
script = ExtResource("3_xxxxx")
required_player_state = "normal"
dialogue_resources = Array[String](["res://data/dialogues/event_002_normal_01.tres", "res://data/dialogues/event_002_normal_02.tres"])

[sub_resource type="Resource" id="EventConfig_002"]
script = ExtResource("2_xxxxx")
event_id = "002"
conditions = Array[ConditionConfig]([SubResource("ConditionConfig_event002_normal")])

[sub_resource type="Resource" id="ConditionConfig_event003_normal"]
script = ExtResource("3_xxxxx")
required_player_state = "normal"
dialogue_resources = Array[String](["res://data/dialogues/event_003_normal_01.tres", "res://data/dialogues/event_003_normal_02.tres", "res://data/dialogues/event_003_normal_03.tres", "res://data/dialogues/event_003_normal_04.tres"])

[sub_resource type="Resource" id="EventConfig_003"]
script = ExtResource("2_xxxxx")
event_id = "003"
conditions = Array[ConditionConfig]([SubResource("ConditionConfig_event003_normal")])

[resource]
script = ExtResource("1_xxxxx")
events = Array[EventConfig]([SubResource("EventConfig_001"), SubResource("EventConfig_002"), SubResource("EventConfig_003")])
```

**重要な注意点**:
- **すべてのイベントは必ず `required_player_state` を指定すること**（"normal", "expansion"など）
- 状態不問（""）のイベントは作成しない方針
- tres ファイルは手動で編集するのではなく、**Godotエディタのインスペクタで視覚的に作成・編集すること**
- 各サブリソースにはユニークなIDを付与（GodotエディタWASが自動生成）

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
		var player_state: String = player.get_current_state()

		# 発火条件チェック
		if not event_config.can_trigger(event_id, player_state):
			return

		# 実行回数を取得してリソースパスを決定
		var count: int = GameProgress.get_event_count(event_id)
		var dialogue_resource: String = event_config.get_dialogue_resource(event_id, player_state, count)
		if dialogue_resource == "":
			return

		# ゲーム全体を停止
		PauseManager.pause_game()

		# イベント開始
		player.start_event()
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
- **プレイヤー状態による条件判定**:
  - `player.get_current_state()`で現在の状態を取得
  - `event_config.can_trigger(event_id, player_state)`で発火可否を判定
  - 例: expansion状態でのみ発火するイベント
- **`one_shot = true`**: 一度だけ発火（デフォルト）
  - 発火後、`monitoring = false`でエリアを無効化
  - GameProgressにイベント実行回数を記録
- **`one_shot = false`**: 何度でも発火
  - 毎回、EventConfigDataで条件判定
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
3. プレイヤーの現在の状態（normal/expansionなど）を取得
   ↓
4. event_config.can_trigger(event_id, player_state) で条件判定
   ├─ false → イベント不発火（プレイヤー状態に合致する条件が存在しない）
   └─ true → 次へ
   ↓
5. GameProgress.get_event_count(event_id) で実行回数を取得
   ↓
6. event_config.get_dialogue_resource(event_id, player_state, count) でリソースパス取得
   ├─ プレイヤー状態に一致するConditionConfigを検索
   ├─ 該当するConditionConfig内のdialogue_resourcesから実行回数に応じたリソースを選択
   ├─ 初回（count=0） → dialogue_resources[0]（例: event_001_normal_01.tres）
   ├─ 2回目（count=1） → dialogue_resources[1]（例: event_001_normal_02.tres）
   ├─ 3回目（count=2） → dialogue_resources[2]（例: event_001_normal_03.tres）
   └─ N回目以降 → dialogue_resources[last]（配列の最後の要素をリピート）
   ↓
7. PauseManager.pause_game() でゲーム全体を停止（背景のゲームプレイを停止）
   ↓
8. player.start_event() でプレイヤーをEVENT状態に遷移
   ↓
9. EventManager.start_dialogue(resource_path) でイベント実行
   ↓
10. イベント終了後、player.end_event() でIDLE状態に復帰
   ↓
11. PauseManager.resume_game() でゲームを再開
   ↓
12. GameProgress.increment_event_count(event_id) で実行回数を記録
   ↓
13. one_shot=true の場合、EventAreaを無効化
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
  - ↑↓ / WSキーで選択移動
  - Zキー / Enterキーで決定
- **最大数**: 2つまで

### 入力操作
- **Zキー / Enterキー**: テキスト送り、選択肢決定
- **↑↓ / WSキー**: 選択肢の移動
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
- **状態不問の場合**: `event_[ID]_[回数].tres`
  - 例: `event_001_01.tres`, `event_001_02.tres`
- **プレイヤー状態が条件の場合**: `event_[ID]_[状態]_[回数].tres`
  - 例: `event_001_normal_01.tres`, `event_001_expansion_01.tres`
- **IDは3桁のゼロパディング**: `001`, `002`, `003`...
- **回数は2桁のゼロパディング**: `01`, `02`, `03`...
- **状態名**: `normal`, `expansion`, `default`など（小文字）
- **配列順序と一致**: dialogue_resources配列のインデックス順にファイル番号を付与
- **リピート用リソース**: 配列の最後の要素が2回目以降すべてに使用される
- **一貫性の維持**: プロジェクト全体で統一されたルールを適用

#### 命名例

**パターン1: 状態不問のシンプルなイベント**
```
event_001_01.tres  # 初回
event_001_02.tres  # 2回目以降（リピート）
```

**パターン2: 複数回異なる会話（状態不問）**
```
event_003_01.tres  # 1回目
event_003_02.tres  # 2回目
event_003_03.tres  # 3回目
event_003_04.tres  # 4回目以降（リピート）
```

**パターン3: 同じevent_idで複数のプレイヤー状態に対応**
```
# normal状態のとき
event_004_normal_01.tres   # 初回
event_004_normal_02.tres   # 2回目以降（リピート）

# expansion状態のとき
event_004_expansion_01.tres   # 初回
event_004_expansion_02.tres   # 2回目以降（リピート）

# フォールバック（状態不問）
event_004_default_01.tres
```

### 4. GameProgressとの連携
- **イベント実行回数の記録**: EventManagerがイベント完了時に自動的に記録
- **フラグ管理**: イベント中でフラグを設定し、他のイベントの条件に使用
- **セーブ/ロード**: GameProgressの状態をセーブデータに保存

## まとめ

event_id駆動設計とEventConfigDataリソースにより、以下を実現：

1. **リソースベースの設計**: 全イベント設定を一つのtresファイルで一括管理
2. **データ駆動開発**: シーンエディタでイベントを管理し、視覚的に配置
3. **拡張性**: 新イベントの追加はevent_config.tresに設定を追加するだけ
4. **保守性**: 共通処理の変更が一箇所で済み、設定変更もエディタで簡単
5. **コードの削減**: 個別スクリプトファイルが不要で、プロジェクト構造がシンプル
6. **プレイヤー状態連動**: normalやexpansionなどのプレイヤー状態に応じたイベント発火
7. **柔軟なリソース管理**: 実行回数に応じた複数パターンの会話を配列で管理
8. **複数条件対応**: 同じevent_idで複数のプレイヤー状態に対応する会話を定義可能
9. **優先順位制御**: 条件配列の順序で評価優先度を制御し、フォールバック処理を実現
10. **シンプルな命名規則**: `event_XXX_[状態]_YY.tres`形式で一貫性を保持

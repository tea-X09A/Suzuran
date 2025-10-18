# 会話イベントシステム実装計画

## 概要
プレイヤーが特定エリアに入ると会話イベントを実行できるシステムを構築する。

## 実装する機能

### 1. イベント基盤システム

#### BaseEvent (基底クラス)
全イベントの共通インターフェース
- 実行開始/完了シグナル
- スキップ可否判定
- 実行ステータス管理

#### EventManager (AutoLoad)
イベント実行の中央管理
- イベントキューの管理
- プレイヤー操作の制御（イベント中は移動不可）
- **PauseManager連携**: イベント中はゲーム全体を停止（`pause_game()` / `resume_game()`）
- **EnemyManager連携**: イベント中は全エネミーを無効化・非表示化（`disable_all_enemies()` / `enable_all_enemies()`）
- 任意のタイミングでイベントを開始する公開API
- 複数の発火方法に対応（EventAreaからの自動発火、NPCやトラップからの手動発火）

#### EventState (プレイヤー制御)
イベント中のプレイヤー状態管理
- BaseStateを継承したステートクラス
- 全ての入力を無視
- 速度を完全停止
- アニメーションをIDLEに固定
- 重力のみ適用（空中でイベント開始した場合の着地対応）
- API: `Player.start_event()`, `Player.end_event()`, `Player.get_current_state()`

### 2. 会話システム

#### DialogueEvent
会話実行イベント
- テキスト表示
- キャラクター名表示
- 顔画像の表示制御
- 複数メッセージの連続表示
- 次へ進む入力待ち（Zキー/Enterキー）
- 選択肢表示と分岐処理
- プレイヤー状態に基づくメッセージフィルタリング

#### DialogueBox (UI)
会話表示ボックス（ノベルゲーム風）
- 画面下部4分の1のサイズ
- 黒色背景（opacity 0.5）
- テキストアニメーション（1文字ずつ表示）
- キャラクター名表示
- 顔画像表示（メッセージウィンドウ左上、高さの約70%）
- Shiftキー長押しで高速スキップ

#### DialogueChoice (UI)
選択肢ボタン
- 画面中央に縦並び表示
- 選択エフェクト
- Zキー/Enterキーで決定、↑↓/WSキーで選択移動
- 最大2つまで

#### DialogueData (Resource)
会話データ定義リソース
- 登場キャラクター定義配列
- 会話メッセージ配列
- 表示速度設定
- 多言語対応（日本語/英語）

**キャラクター定義構造**:
```gdscript
class CharacterInfo:
    var character_id: String        # "001", "002"など
    var speaker_name: Dictionary    # {"ja": "スズラン", "en": "Suzuran"}
    var face_image_path: String     # 顔画像フォルダパス
    var default_emotion: String     # デフォルト表情
```

**メッセージ配列の構造**:
```gdscript
class DialogueMessage:
    var index: String           # "0", "1", "3-a", "3-b"など
    var speaker_id: String      # キャラクター識別子（""=ナレーション）
    var text: Dictionary        # {"ja": "...", "en": "..."}
    var emotion: String         # 表情差分（空=""ならdefault使用）
    var choices: Array          # 選択肢配列
    var condition: String       # プレイヤー状態: "normal", "expansion", ""=条件なし
```

### 3. イベントトリガーとリソース管理

#### EventArea（共通スクリプト）
- 全てのEventAreaは`event_area.gd`を共有
- `@export var event_id: String`でイベント識別子を指定
- EventConfigDataリソースから設定を取得
- `one_shot`機能: 一度だけ発火 or 何度でも発火

#### EventConfigData（イベント設定リソース）
全イベントの設定を一つのtresファイルで一括管理

**EventConfig構造**:
```gdscript
class EventConfig extends Resource:
    @export var event_id: String = ""
    @export var dialogue_resources: Array[String] = []  # 実行回数順のDialogueDataパス
    @export var max_execution_count: int = -1  # 最大実行回数（-1=無制限、0=無効、>0=指定回数まで）
```

**EventConfigData構造**:
```gdscript
class EventConfigData extends Resource:
    @export var events: Array[EventConfig] = []

    func get_event_config(event_id: String) -> EventConfig
    func get_dialogue_resource(event_id: String, count: int) -> String
```

- `dialogue_resources`は実行回数順の配列
  - インデックス0が初回、1が2回目...
  - 配列の範囲外は最後の要素を返す（リピート用）
- `max_execution_count`でイベント実行回数の上限を制御
  - `-1`: 無制限（デフォルト）- 何度でも実行可能
  - `0`: 無効 - イベントを発火しない（デバッグ用）
  - `>0`: 指定回数まで実行可能 - 上限到達後は発火しない
- プレイヤー状態による条件分岐は各DialogueData内のメッセージの`condition`フィールドで処理

#### 任意オブジェクトからの発火
- NPC、トラップなどから`EventManager.start_event(event_data)`を呼び出し
- 何度でも発火可能

## ファイル構成

```
scripts/
├── events/
│   ├── base_event.gd
│   ├── dialogue_event.gd
│   ├── event_config.gd                # EventConfig リソースクラス
│   └── event_config_data.gd           # EventConfigData リソースクラス
│
├── dialogue/
│   ├── dialogue_box.gd
│   ├── dialogue_choice.gd
│   └── dialogue_data.gd
│
├── player/
│   ├── player.gd                      # 拡張（start_event/end_eventメソッド追加）
│   └── states/
│       └── event_state.gd             # 新規
│
├── autoload/
│   ├── event_manager.gd               # 新規AutoLoad
│   ├── pause_manager.gd               # 既存
│   ├── game_settings.gd               # 既存（言語設定管理）
│   └── save_load_manager.gd           # 既存（イベント実行回数管理含む）
│
├── global/
│   └── enemy_manager.gd               # 既存
│
└── levels/
    └── event_area.gd                  # 共通スクリプト（event_id駆動）

scenes/
├── dialogue/
│   ├── dialogue_system.tscn           # 会話システム全体（UIルート）
│   ├── dialogue_box.tscn              # メッセージウィンドウ
│   └── dialogue_choice.tscn           # 選択肢ボタン
│
└── levels/
    └── event_area.tscn                # 既存シーン（拡張）

assets/images/faces/                   # 顔画像格納フォルダ
├── player/                            # プレイヤー表情
└── npcs/                              # NPC顔画像

data/
├── event_config.tres                  # 全イベント設定を管理
└── dialogues/                         # DialogueDataリソース格納
    ├── event_001_01.tres              # イベント001・1回目
    ├── event_001_02.tres              # イベント001・2回目以降
    └── ...
```

## 実装順序

1. **基盤構築**
   - BaseEvent基底クラス
   - EventManager AutoLoad
   - EventState実装とPlayer統合

2. **イベント設定システム**
   - EventConfig リソースクラス
   - EventConfigData リソースクラス
   - event_config.tres リソース作成（Godotエディタで視覚的に作成）
   - EventArea共通スクリプト拡張

3. **会話システム**
   - DialogueData リソース
   - DialogueBox UI
   - DialogueEvent 実装

4. **統合とテスト**
   - サンプルDialogueDataリソース作成
   - level1での動作確認
   - プレイヤー状態による条件分岐のテスト

5. **統合テスト**
   - NPCスクリプトでの会話呼び出し実装例
   - トラップでのイベント発火実装例

## 設計方針

- **シグナルベースの疎結合**: ノード間の直接参照を避ける
- **ステートパターン準拠**: Player実装と同様の設計思想
- **メモリリーク防止**: weakref、queue_free、disconnect徹底
- **拡張性**: 新イベントタイプを容易に追加可能
- **再利用性**: イベントデータはResourceとして外部定義
- **PauseManager統合**: イベント実行中はゲーム全体を停止
- **EnemyManager統合**: イベント実行中は全エネミーを無効化・非表示化
- **event_id駆動設計**: EventAreaは共通スクリプトを使用し、コードの重複を防止

## イベント発火の仕様

### イベント実行フロー（EventArea）

```
1. プレイヤーがEventAreaに侵入
   ↓
2. EventConfigDataリソース（event_config.tres）を読み込み
   ↓
3. SaveLoadManager.get_event_count(event_id) で実行回数を取得
   ↓
4. 実行回数の上限チェック
   - max_execution_count >= 0 かつ count >= max_execution_count の場合、発火せずに終了
   - それ以外は続行
   ↓
5. event_config.get_dialogue_resource(event_id, count) でリソースパス取得
   - 初回（count=0） → dialogue_resources[0]
   - 2回目（count=1） → dialogue_resources[1]
   - N回目以降 → dialogue_resources[last]（配列の最後の要素をリピート）
   ↓
6. EventManager.start_event() 呼び出し:
   - player.start_event() でEVENT状態に遷移
   - PauseManager.pause_game() でゲーム全体を停止
   - EnemyManager.disable_all_enemies(get_tree()) で全エネミーを無効化
   ↓
7. DialogueEvent実行（プレイヤー状態でメッセージフィルタリング）
   ↓
8. イベント終了時:
   - PauseManager.resume_game() でゲームを再開
   - EnemyManager.enable_all_enemies(get_tree()) で全エネミーを再有効化
   - player.end_event() でIDLE状態に復帰
   ↓
9. SaveLoadManager.increment_event_count(event_id) で実行回数を記録
   ↓
10. one_shot=true の場合、EventAreaを無効化
```

### プレイヤー状態による条件分岐

DialogueEvent内で`player.get_current_state()`を取得し、メッセージの`condition`フィールドでフィルタリング:
- `condition: ""` → 常に表示
- `condition: "normal"` → プレイヤーがnormal状態の時のみ
- `condition: "expansion"` → プレイヤーがexpansion状態の時のみ

1つのDialogueDataリソース内に複数の状態に対応するメッセージを含めることが可能。

## UI仕様

### DialogueBoxシーンのノード構成

```
DialogueBox (PanelContainer)
├── MarginContainer
│   └── VBoxContainer
│       └── HBoxContainer (speaker_row)
│           ├── FaceImage (TextureRect) - 顔画像表示（140x140px）
│           └── VBoxContainer (text_column)
│               ├── SpeakerName (Label) - 話者名（ゴールド色）
│               └── DialogueText (RichTextLabel) - メッセージテキスト
```

**主要プロパティ**:
- PanelContainer: 画面下部、高さ200px、黒背景（alpha 0.5）
- FaceImage: 正方形140x140px、フェードイン/アウト対応
- DialogueText: 1文字ずつ表示、BBCode対応

### DialogueSystemシーンのノード構成

```
DialogueSystem (CanvasLayer, layer=50)
├── DialogueBoxContainer (Control)
│   └── DialogueBox (インスタンス)
└── DialogueChoicesContainer (Control)
    └── VBoxContainer - 画面中央配置
        └── ChoiceButton (インスタンス、最大2つ)
```

### DialogueChoiceシーンのノード構成

```
ChoiceButton (Button)
└── Label - 選択肢テキスト
```

**スタイル仕様**:

**選択状態のスタイル** (選択中のボタン):
- 背景色: `Color(1.0, 1.0, 1.0, 0.3)` - 白色30%不透明度
- ボーダー色: `Color(1.0, 1.0, 1.0, 1.0)` - 白色100%不透明度（完全不透明）
- ボーダー幅: 3ピクセル（上下左右すべて）
- コーナー半径: 8ピクセル（すべてのコーナー）

**非選択状態のスタイル** (選択されていないボタン):
- 背景色: `Color(0.0, 0.0, 0.0, 0.0)` - 完全透明
- ボーダー色: `Color(1.0, 1.0, 1.0, 0.0)` - 透明なボーダー（レイアウトシフトを防ぐため3px幅を維持）
- ボーダー幅: 3ピクセル（上下左右すべて）
- コーナー半径: 8ピクセル（すべてのコーナー）

**実装方法**:
- `StyleBoxFlat` を使用してスタイルを動的に作成
- 選択状態は `"normal"`, `"pressed"`, `"focus"` のすべてのボタン状態に同じスタイルを適用
- 非選択状態も同様にすべてのボタン状態に適用
- スタイルは `_ready()` で一度だけ作成し、`@onready var` でキャッシュしてパフォーマンスを最適化
- `add_theme_stylebox_override()` を使用してボタンにスタイルを適用
- settingsの実装（`base_settings.gd`）と同じ方式を採用

### 入力操作

- **Zキー / Enterキー**: テキスト送り、選択肢決定
- **↑↓ / WSキー**: 選択肢の移動
- **Shiftキー（長押し）**: 会話の高速スキップ

## データ構造とリソース管理

### DialogueDataの使用例（簡略版）

**基本的な会話**:
```gdscript
characters = [
    {"character_id": "001", "speaker_name": {"ja": "鈴蘭"}, ...},
    {"character_id": "002", "speaker_name": {"ja": "商人"}, ...}
]

messages = [
    {"index": "0", "speaker_id": "002", "text": {"ja": "いらっしゃいませ！"}, ...},
    {"index": "1", "speaker_id": "001", "text": {"ja": "手裏剣を買いたいのですが..."}, ...},
    {"index": "2", "speaker_id": "002", "text": {"ja": "どうしましょう？"},
     "choices": [
         {"text": {"ja": "買う"}, "next_index": "3-a"},
         {"text": {"ja": "やめておく"}, "next_index": "3-b"}
     ]},
    {"index": "3-a", "speaker_id": "002", "text": {"ja": "ありがとうございます！"}, ...},
    {"index": "3-b", "speaker_id": "002", "text": {"ja": "またのお越しをお待ちしております。"}, ...}
]
```

**プレイヤー状態による分岐**:
```gdscript
messages = [
    # normal状態用
    {"index": "0", "speaker_id": "003", "text": {"ja": "立入禁止だ。"}, "condition": "normal"},
    {"index": "1", "speaker_id": "001", "text": {"ja": "通してください。"}, "condition": "normal"},

    # expansion状態用
    {"index": "0", "speaker_id": "003", "text": {"ja": "その体では通れまい。"}, "condition": "expansion"},
    {"index": "1", "speaker_id": "001", "text": {"ja": "くっ...。"}, "condition": "expansion"}
]
```

### リソースファイルの命名規則

**統一形式**: `event_[ID]_[回数].tres`
- IDは3桁のゼロパディング: `001`, `002`, `003`
- 回数は2桁のゼロパディング: `01`, `02`, `03`

**例**:
```
event_001_01.tres  # 初回
event_001_02.tres  # 2回目以降（リピート）

event_003_01.tres  # 1回目
event_003_02.tres  # 2回目
event_003_03.tres  # 3回目
event_003_04.tres  # 4回目以降（リピート）
```

### max_execution_countの使用例

| イベント種別 | max_execution_count | dialogue_resources | 動作 |
|--------------|---------------------|-------------------|------|
| 商店NPC | `-1` | `[shop_01.tres]` | 無制限リピート |
| ストーリーNPC | `3` | `[story_01.tres, story_02.tres, story_03.tres]` | 3回まで実行可能 |
| 一度きりイベント | `1` | `[oneshot_01.tres]` | 1回のみ（one_shotと同等） |
| 無効化イベント | `0` | `[disabled.tres]` | 発火しない（デバッグ用） |

### SaveLoadManagerとの連携

**イベント実行回数の記録**:
- `SaveLoadManager.event_counts: Dictionary` - イベントIDごとの実行回数を保持
- セーブデータにJSON形式で保存/復元
- `get_event_count(event_id: String) -> int`
- `increment_event_count(event_id: String) -> void`

**セーブデータ構造**:
```json
{
  "event_counts": {
    "001": 2,
    "002": 1,
    "003": 0
  }
}
```

## event_id駆動設計の利点

### コードの再利用性と保守性
- 共通ロジックの一元管理（EventArea.gd）
- 設定のリソース化（EventConfigData）
- 変更の局所化

### 拡張性と柔軟性
- 新イベントの追加が容易（event_config.tresに設定を追加するだけ）
- コードファイル不要
- 視覚的な編集（Godotエディタで設定可能）

### データ駆動開発
- シーンエディタでEventAreaごとに`event_id`を設定
- 全イベント設定を一括管理
- デザイナーフレンドリー

## まとめ

event_id駆動設計とEventConfigDataリソースにより、以下を実現：

1. **リソースベースの設計**: 全イベント設定を一つのtresファイルで一括管理
2. **データ駆動開発**: シーンエディタでイベントを管理
3. **拡張性**: 新イベントの追加はevent_config.tresに設定を追加するだけ
4. **保守性**: 共通処理の変更が一箇所で済む
5. **コードの削減**: 個別スクリプトファイルが不要
6. **プレイヤー状態連動**: プレイヤー状態に応じた会話分岐
7. **柔軟なリソース管理**: 実行回数に応じた複数パターンの会話を配列で管理
8. **ファイル内条件分岐**: DialogueData内のconditionフィールドで処理
9. **セーブ/ロード統合**: SaveLoadManagerによるイベント実行回数の永続化
10. **エネミー制御統合**: EnemyManagerとの連携により、イベント中は全エネミーを自動的に無効化・非表示化
11. **実行回数制御**: max_execution_countによるイベントごとの柔軟な上限設定（無制限/回数制限/無効化）

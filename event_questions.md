# イベントシステム実装 - 確認事項

## 1. DialogueDataのデータ構造

### 会話の範囲
- 1つのDialogueDataリソースに含める範囲は？
  - [ ] 1つの会話全体（分岐含む）を1ファイル
  - [ ] 分岐ごとに別ファイル

### 選択肢の分岐参照方法
- **A案：インデックス参照**（同一ファイル内で`next_index`で参照）
- **B案：リソースパス参照**（別ファイルへの`next_dialogue_path`で参照）
- どちらを採用？または両方対応？

### メッセージ配列の構造案
```gdscript
{
    "speaker": "PlayerName",
    "text": "メッセージ内容",
    "portrait_path": "res://assets/images/portrait/player/happy.png",  # オプション
    "speaker_side": "left"  # "left" or "right"
}
```

## 2. プレイヤー制御方法

イベント中のプレイヤー入力制御：
- **A案**：`auto_move_mode = true` + `velocity = Vector2.ZERO`
- **B案**：新フラグ`event_mode: bool`を追加（推奨）
- **C案**：新ステート`EventState`を追加

どれを採用？

## 3. 立ち絵表示の詳細

- 立ち絵なしの会話：対応する？
- 3人以上の会話：想定する？
- 表情差分：メッセージごとに切り替え可能にする？

## 4. 選択肢の条件判定

`DialogueChoice.condition`の仕様：
- フラグ判定（例：`"flag:met_npc_before"`）
- アイテム所持（例：`"item:key"`）
- ステータス（例：`"hp:>2"`）
- その他の条件は？

または条件判定用コールバック関数方式？

## 5. メッセージウィンドウの上部フェードエフェクト

実装方法：
- **A案**：カスタムShaderでグラデーションマスク
- **B案**：TextureRect + グラデーションPNG画像
- **C案**：ColorRectを複数重ねて透明度調整

どれを採用？

## 6. EventAreaの拡張

追加するエクスポート変数案：
```gdscript
@export_enum("dialogue", "animation", "cutscene") var event_type: String = "dialogue"
@export_file("*.tres") var event_data_path: String = ""
```

この方針で問題ない？

# 鈴蘭（Suzuran）の顔画像

このディレクトリには、主人公・鈴蘭の表情画像を配置します。

## 必要なファイル

対話システムで使用する顔画像ファイル：

- `suzuran_normal.png` - 通常の表情（デフォルト）
- `suzuran_happy.png` - 喜び
- `suzuran_sad.png` - 悲しみ
- `suzuran_angry.png` - 怒り
- `suzuran_surprised.png` - 驚き
- その他、必要に応じて感情に応じたバリエーションを追加

## 仕様

- **ファイル形式**: PNG（透過対応）
- **推奨サイズ**: 140x140ピクセル以上
- **命名規則**: `suzuran_{emotion}.png`
  - `{emotion}` には感情名を小文字英字で指定（例: normal, happy, sad）

## 使用方法

対話システムでは、以下のように自動的に画像パスが構築されます：

```
res://assets/images/faces/player/suzuran_normal.png
```

ベースパス（`res://assets/images/faces/player/suzuran_`）に、感情名と拡張子（`.png`）が追加されます。

## 注意事項

- 画像ファイルが存在しない場合でも、対話システムは正常に動作します
- 画像がない場合、顔画像の領域は透明になりますが、レイアウトのスペースは確保されます
- テスト用のプレースホルダー画像として、140x140pxの単色画像を使用することもできます

# 包括的実装スラッシュコマンド

自然言語で指示されたタスクを段階的に処理し、品質を保証しながら実装を行います。

## 引数
- `$1`: 実装するタスクの詳細説明

## 実行プロセス

### Phase 1: プロジェクト分析（並行実行）
```
以下のサブエージェントを Task tool で並行実行：

1. directory-analyzer
   - プロジェクト構造を分析し、${1}の実装に最適な場所を特定

2. config-file-investigator  
   - 現在の設定ファイルを調査し、${1}の実装に必要な設定変更があるか確認

3. dependency-analyzer
   - ${1}の実装に関連する既存コードの依存関係を分析

4. typescript-type-coverage-analyzer
   - 既存コードベースのTypeScript型カバレッジを分析
   - 実装前に型安全性の現状を把握

5. code-duplication-detector
   - 既存の重複コードパターンを検出
   - 新機能実装時の重複回避に活用
```

### Phase 2: 実装計画作成
TodoWrite tool でタスク管理しながら以下を計画：
- 実装に必要なファイルの特定
- コンポーネント設計（React単一責任原則）
- 状態管理戦略（Zustand）
- スタイリング方針（CSS Modules）
- 型定義戦略（TypeScript厳格型定義）
- テスト戦略

### Phase 3: 段階的実装（サブエージェント使用）
```
以下のサブエージェントを Task tool で並行実行し、TodoWrite で進捗管理：

1. typescript-type-enhancer
   - ${1}に必要なTypeScript型定義とインターフェースを作成
   - 厳格な型定義の実装（`any`型の使用禁止）
   - 既存型との整合性確保

2. large-scale-refactoring（状態管理が必要な場合）
   - Zustandストアの実装・統合
   - 関心事ごとのStore分割設計
   - イミュータブルな更新パターンの実装

3. react-hooks-optimizer
   - Reactコンポーネントの実装・最適化
   - 単一責任の原則に基づくコンポーネント設計
   - カスタムフックの抽出と最適化
   - Presentational/Containerパターンの適用

4. css-modules-consolidator
   - CSS Modulesによるスタイリング実装
   - ローカルスコープの確保
   - camelCase命名規則の適用
   - 既存スタイルとの統合

5. performance-optimizer
   - 実装したコンポーネントの統合とパフォーマンス最適化
   - レンダリング最適化とメモ化の適用
   - バンドルサイズとランタイム効率の改善
```

### Phase 4: 規則違反確認（並行実行）
```
以下のサブエージェントを Task tool で並行実行：

1. post-format-code-reviewer  
   - CLAUDE.mdの原則に違反していないか確認
   - コーディング原則の遵守状況を検証

2. typescript-error-checker
   - TypeScript厳格型定義の原則違反を確認
   - any型の不適切な使用がないか検証
```

## 実行方法
```
/implement [実装したい機能の説明]
```

## 使用例
```
/implement ユーザーが設定画面でダークモードを切り替えられる機能を追加してください

/implement ホーム画面にクイック設定パネルを追加し、音量とテキスト速度を調整できるようにする

/implement シナリオ画面で文字表示速度をリアルタイムで変更できるスライダーを追加

/implement バックログ画面に検索機能を追加し、キーワードでログを絞り込めるようにする
```

## エラーハンドリング
- 各フェーズでエラーが発生した場合、該当フェーズで停止
- 問題の詳細と推奨される対処法を表示
- 大規模なリファクタリングが必要な場合は、large-scale-refactoring エージェントの使用を提案

## 品質保証原則
- 既存のコード品質基準を維持し、新しいコードも同じ水準に保つ
- CLAUDE.mdの全原則を厳守
- TypeScript厳格型定義、React設計原則、Zustand状態管理パターンの遵守
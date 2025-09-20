# Git Reset Remote コマンド

現在のローカル状態をリモートリポジトリに強制プッシュします。⚠️ 注意：この操作はリモートの履歴を変更します。

## 処理内容
1. 現在の状態確認
2. リモートとの差分確認
3. リモートリポジトリへの強制プッシュ
4. 最終状態の確認

```bash
# 現在の状態を確認
echo "=== 現在の状態 ==="
echo "ローカルコミット: $(git rev-parse --short HEAD)"
git status

# リモートとの差分を確認
echo "=== リモートとの差分 ==="
git log --oneline origin/$(git branch --show-current)..HEAD 2>/dev/null || echo "リモートより進んでいます"
git log --oneline HEAD..origin/$(git branch --show-current) 2>/dev/null || echo "リモートより遅れています"

# 確認メッセージ
echo "⚠️  警告: この操作により、リモートの履歴が変更されます。"
echo "他の開発者がいる場合は注意してください。"

# リモートリポジトリに強制プッシュ
echo "=== リモートに強制プッシュ中... ==="
git push --force-with-lease

# 最終状態を確認
echo "=== 強制プッシュ完了 - 最終状態 ==="
git status
echo "リモートリポジトリに現在のローカル状態を反映しました。"
```
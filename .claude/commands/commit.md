# Git Commit & Push コマンド

ステージングされた変更をコミットし、リモートリポジトリにプッシュします。コミットメッセージを自動生成して適用します。

## 処理内容
1. ステージングされたファイルの確認
2. 変更内容の確認
3. コミットメッセージの自動生成と適用
4. リモートリポジトリへの自動プッシュ
5. 最終状態の確認

```bash
# ステージングされたファイルを確認
echo "=== ステージングされたファイル ==="
STAGED_FILES=$(git diff --cached --name-status)
echo "$STAGED_FILES"

# 変更内容を確認
echo "=== 変更内容 ==="
git diff --cached --stat

# ステージングされた変更があるかチェック
if [ -z "$(git diff --cached --name-only)" ]; then
    echo "ステージングされた変更がありません。"
    echo "変更をステージングしてから再実行してください。"
    exit 1
fi

# 変更されたファイルの種類から適切なコミットメッセージを生成
COMMIT_TYPE="update"
COMMIT_SCOPE=""
COMMIT_MESSAGE="プロジェクトファイルの更新"

# ファイル変更内容を分析してコミットタイプを決定
if echo "$STAGED_FILES" | grep -q "^A"; then
    COMMIT_TYPE="feat"
    COMMIT_MESSAGE="新機能追加"
elif echo "$STAGED_FILES" | grep -E "\.(test|spec)\." > /dev/null; then
    COMMIT_TYPE="test"
    COMMIT_MESSAGE="テストファイル更新"
elif echo "$STAGED_FILES" | grep -E "\.(css|scss|module\.css)" > /dev/null; then
    COMMIT_TYPE="style"
    COMMIT_MESSAGE="スタイル更新"
elif echo "$STAGED_FILES" | grep -E "package\.json|package-lock\.json|yarn\.lock" > /dev/null; then
    COMMIT_TYPE="build"
    COMMIT_MESSAGE="依存関係更新"
elif echo "$STAGED_FILES" | grep -E "\.md$|README" > /dev/null; then
    COMMIT_TYPE="docs"
    COMMIT_MESSAGE="ドキュメント更新"
fi

# コミットメッセージを生成してコミット実行（ユーザー入力なし）
echo "=== コミット自動実行 ==="
git commit -m "$(cat <<EOF
${COMMIT_TYPE}: ${COMMIT_MESSAGE}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# コミット結果を確認
echo "=== コミット完了 ==="
git log -1 --oneline

# リモートリポジトリに自動プッシュ
echo "=== リモートへ自動プッシュ中 ==="
# 現在のブランチ名を取得
CURRENT_BRANCH=$(git branch --show-current)
echo "現在のブランチ: $CURRENT_BRANCH"

# コミット成功確認
if [ $? -eq 0 ]; then
    echo "コミット成功 - プッシュを開始します"
    
    # リモートの存在確認
    if ! git remote | grep -q "origin"; then
        echo "❌ リモート 'origin' が設定されていません"
        echo "リモートリポジトリを設定してください"
        exit 1
    fi
    
    # 自動プッシュ実行（ユーザー確認なし）
    if git push -u origin HEAD 2>/dev/null; then
        echo "✅ プッシュ成功"
    else
        echo "⚠️ upstream設定でのプッシュに失敗 - 通常プッシュを試行中..."
        if git push origin $CURRENT_BRANCH 2>/dev/null; then
            echo "✅ プッシュ成功"
        else
            echo "⚠️ 通常プッシュも失敗 - 強制プッシュを試行中..."
            if git push --force-with-lease origin $CURRENT_BRANCH 2>/dev/null; then
                echo "✅ 強制プッシュ成功"
            else
                echo "❌ すべてのプッシュ試行に失敗"
                echo "リモートの状態とネットワークを確認してください"
                git remote -v
                exit 1
            fi
        fi
    fi
else
    echo "❌ コミットに失敗したため、プッシュをスキップします"
    exit 1
fi

# プッシュ結果を確認
echo "=== プッシュ確認 ==="
git log origin/$CURRENT_BRANCH -1 --oneline 2>/dev/null || echo "リモートブランチの確認に失敗"

# 最終状態を確認
echo "=== プッシュ完了 - 最終状態 ==="
git status
```
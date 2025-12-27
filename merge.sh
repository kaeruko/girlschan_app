#!/bin/bash
set -e # エラー時は即停止

# --- 設定 ---
TARGET_BRANCH="main"
REMOTE_NAME="origin"
# ------------

echo "Fetching latest info..."
git fetch --prune

# 最新のリモートブランチを取得（mainとHEADを除外）
LATEST_REMOTE_REF=$(git for-each-ref --sort=-committerdate refs/remotes/$REMOTE_NAME --format='%(refname:short)' \
  | grep -v "$REMOTE_NAME/$TARGET_BRANCH" \
  | grep -v "$REMOTE_NAME/HEAD" \
  | head -n 1)

# 変数チェック
if [ -z "$LATEST_REMOTE_REF" ]; then
  echo "Error: マージ対象のブランチが見つかりませんでした。"
  exit 1
fi

LATEST_BRANCH_NAME=${LATEST_REMOTE_REF#$REMOTE_NAME/}

echo "Target Branch: $LATEST_BRANCH_NAME"

# 作業ディレクトリの汚れチェック（安全のため残している）
if [ -n "$(git status --porcelain)" ]; then
  echo "Error: 作業ディレクトリに変更があります。commitかstashしてください。"
  exit 1
fi

# mainを最新化してマージ
git checkout "$TARGET_BRANCH"
git pull "$REMOTE_NAME" "$TARGET_BRANCH"

echo "Merging $LATEST_BRANCH_NAME into $TARGET_BRANCH..."
git merge "$LATEST_REMOTE_REF"

echo "Success: $LATEST_BRANCH_NAME was merged into $TARGET_BRANCH."
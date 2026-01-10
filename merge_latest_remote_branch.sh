set -euo pipefail

# 環境変数 FILTER があれば前方一致で絞る
# 例 FILTER=origin/codex/ bash /tmp/merge_latest_remote_branch.sh

filter="${FILTER:-}"

git fetch origin

picked="$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin \
  | grep -v '^origin/HEAD$' \
  | grep -v '^origin/main$' \
  | { if [ "$filter" = "" ]; then cat; else grep "^$filter"; fi; } \
  | head -n 1)"

if [ "${picked:-}" = "" ]; then
  echo "対象ブランチが見つからない"
  echo "FILTER を見直してね"
  exit 1
fi

echo "取り込むブランチ"
echo "$picked"

git switch main
git pull --ff-only origin main
git merge "$picked"
git push origin main

echo "完了"

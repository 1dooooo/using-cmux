#!/usr/bin/env bash
set -euo pipefail

# 同步并翻译脚本
# 从 upstream 拉取最新更改，并检测需要翻译的文件

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== 同步上游仓库 ==="
cd "$REPO_DIR"

# 获取 upstream 最新
git fetch upstream

# 检查是否有新提交
LOCAL=$(git rev-parse HEAD)
UPSTREAM=$(git rev-parse upstream/main)

if [[ "$LOCAL" == "$UPSTREAM" ]]; then
  echo "已是最新，无需同步。"
  exit 0
fi

echo "检测到上游有新更改。"
echo "  本地:      $LOCAL"
echo "  上游:      $UPSTREAM"

# 合并上游更改
git merge upstream/main -m "chore: 同步上游更改"

echo ""
echo "=== 检测需要翻译的文件 ==="

# 列出变更的文件
CHANGED=$(git diff HEAD~1 --name-only | grep -E '\.(md|sh)$' || true)

if [[ -z "$CHANGED" ]]; then
  echo "没有需要翻译的文件变更。"
  exit 0
fi

echo "以下文件已更改:"
echo "$CHANGED"

echo ""
echo "请在后续会话中手动翻译这些文件，或提示 Claude Code 重新翻译。"
echo ""
echo "同步完成！"

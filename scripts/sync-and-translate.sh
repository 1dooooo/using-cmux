#!/usr/bin/env bash
set -euo pipefail

# sync-and-translate.sh
# 一键同步上游更新并翻译日文内容
# 用法: ./scripts/sync-and-translate.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_DIR"

echo "=== 🔄 同步上游仓库 ==="
git fetch upstream

# 检查是否有新提交
LOCAL=$(git rev-parse HEAD)
UPSTREAM=$(git rev-parse upstream/main)

if [[ "$LOCAL" == "$UPSTREAM" ]]; then
  echo "✅ 已是最新，无需同步。"
  exit 0
fi

echo "检测到上游更新："
echo "  本地:  $LOCAL"
echo "  上游:  $UPSTREAM"
echo ""

# 合并上游更改
echo "=== 🔀 合并上游更改 ==="
git merge upstream/main --no-edit

# 找出变更的文件
echo ""
echo "=== 📝 检测需要翻译的文件 ==="
CHANGED=$(git diff HEAD~1 --name-only | grep -E '\.(md|sh)$' || true)

if [[ -z "$CHANGED" ]]; then
  echo "没有需要翻译的文件变更。"
  echo "推送合并结果..."
  git push origin main
  exit 0
fi

echo "以下文件已更改:"
echo "$CHANGED"
echo ""

# 检测包含日文的文件
echo "=== 🔍 检查日文内容 ==="
FILES_TO_TRANSLATE=""

while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    # 检测日文字符（平假名、片假名、汉字范围）
    if LC_ALL=C grep -q $'\xe3\x81[\x80-\xbf]\|'$\xe3\x82[\x80-\xbf]\|'$\xe4[\x80-\xbf][\x80-\xbf]' "$file" 2>/dev/null || \
       LC_ALL=C grep -q $'\xe3\x83[\x80-\xbf]$\xe3\x84[\x80-\xbf]$\xe3\x85[\x80-\xbf]' "$file" 2>/dev/null; then
      FILES_TO_TRANSLATE="$FILES_TO_TRANSLATE $file"
      echo "  📝 $file (包含日文)"
    else
      echo "  ✅ $file (无需翻译)"
    fi
  fi
done <<< "$CHANGED"

if [[ -z "$FILES_TO_TRANSLATE" ]]; then
  echo ""
  echo "没有需要翻译的文件。"
  echo "推送合并结果..."
  git push origin main
  exit 0
fi

echo ""
echo "=== 🌐 需要翻译的文件 ==="
for file in $FILES_TO_TRANSLATE; do
  echo "  - $file"
done

echo ""
echo "=== 🤖 翻译方式选择 ==="
echo "请选择翻译方式："
echo "  1) 手动翻译（默认）- 脚本会列出文件，你手动翻译后提交"
echo "  2) Claude Code 自动翻译 - 需要 claude 命令可用"
echo ""
read -t 30 -p "选择 (1/2, 30秒后默认1): " TRANSLATE_MODE || TRANSLATE_MODE="1"
echo ""

if [[ "$TRANSLATE_MODE" == "2" ]] && command -v claude &> /dev/null; then
  echo "使用 Claude Code 进行翻译..."
  for file in $FILES_TO_TRANSLATE; do
    echo "翻译: $file"
    # 备份原文件
    cp "$file" "${file}.bak"
    # 使用 claude 翻译（非交互模式）
    claude --dangerously-skip-permissions --print "请将文件 ${file}.bak 中的日文内容翻译成中文，保持 Markdown 格式、代码块、表格不变。直接输出翻译后的内容，不要额外解释。" 2>/dev/null > "${file}.tmp" || true
    
    if [[ -s "${file}.tmp" ]]; then
      mv "${file}.tmp" "$file"
      rm -f "${file}.bak"
      echo "  ✅ $file 翻译完成"
    else
      echo "  ❌ $file 翻译失败，恢复备份"
      mv "${file}.bak" "$file"
      rm -f "${file}.tmp"
    fi
  done
else
  echo "请手动翻译以下文件，完成后运行:"
  echo "  git add . && git commit -m '翻译：同步上游后的日文内容翻译' && git push origin main"
  echo ""
  echo "需要翻译的文件:"
  for file in $FILES_TO_TRANSLATE; do
    echo "  - $file"
  done
  exit 0
fi

echo ""
echo "=== 💾 提交翻译结果 ==="
git add .
if ! git diff --cached --quiet; then
  git commit -m "翻译：同步上游后的日文内容翻译"
  echo "推送更改..."
  git push origin main
  echo "✅ 同步并翻译完成！"
else
  echo "没有新的翻译变更需要提交。"
  echo "推送合并结果..."
  git push origin main
fi

echo ""
echo "=== ✅ 同步完成 ==="

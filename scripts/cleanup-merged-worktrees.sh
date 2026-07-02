#!/usr/bin/env bash
# cleanup-merged-worktrees.sh — 清理本地已合并（远端分支已删）的 worktree
#
# 使用方式（在主目录根执行）：
#   ./scripts/cleanup-merged-worktrees.sh            # 全部自动清理（默认）
#   ./scripts/cleanup-merged-worktrees.sh --dry-run  # 交互确认，逐个清理
#
# 判断逻辑（两层，满足其一即清理）：
#   1. git tracking gone：PR 合并后 GitHub 删除远端分支 → fetch --prune 后变 gone
#   2. gh pr merged：upstream 未正确绑定自身远端时的兜底，查 GitHub PR 状态确认已合并
#
# 不会动以下内容：
#   - 主目录（即当前 git worktree）
#   - develop / main 分支
#   - 远端分支仍存在的 worktree（PR 尚未合并）
#   - 有未提交改动的 worktree（强制跳过，需手动处理）

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "  [错误] 请在 git 仓库根目录下执行此脚本。"
  exit 1
fi

AUTO=true
if [ "${1:-}" = "--dry-run" ]; then
  AUTO=false
fi

echo ""
echo "  PSA worktree 清理工具"
echo "  正在拉取远端分支状态..."
git -C "$REPO_ROOT" fetch --prune --quiet
echo ""

# 收集所有 worktree 信息（每条格式：<path> <HEAD> <branch>）
WORKTREE_LIST=$(
  git -C "$REPO_ROOT" worktree list --porcelain \
    | awk '
      /^worktree / { path=$2; head=""; branch="" }
      /^HEAD /     { head=$2 }
      /^branch /   { branch=$2 }
      /^$/         { if (path && head) print path " " head " " (branch ? branch : "DETACHED") }
    '
)

MAIN_WORKTREE_PATH="$REPO_ROOT"
REMOVED=0
SKIPPED=0

while IFS= read -r line; do
  [ -z "$line" ] && continue

  WT_PATH=$(echo "$line" | awk '{print $1}')
  WT_BRANCH_REF=$(echo "$line" | awk '{print $3}')
  WT_BRANCH="${WT_BRANCH_REF#refs/heads/}"

  # 跳过空分支名
  if [ -z "$WT_BRANCH" ]; then
    continue
  fi

  # 跳过主目录
  if [ "$WT_PATH" = "$MAIN_WORKTREE_PATH" ]; then
    continue
  fi

  # 跳过目录不存在
  if [ ! -d "$WT_PATH" ]; then
    echo "  ⚠️  跳过（目录不存在）: $WT_PATH"
    SKIPPED=$((SKIPPED + 1))
    echo ""
    continue
  fi

  # 跳过 develop / main
  if [ "$WT_BRANCH" = "develop" ] || [ "$WT_BRANCH" = "main" ]; then
    continue
  fi

  # 跳过 detached HEAD
  if [ "$WT_BRANCH" = "DETACHED" ]; then
    continue
  fi

  # 判断一：upstream gone（远端分支已删）
  TRACKING=$(git -C "$REPO_ROOT" for-each-ref --format='%(upstream:track)' "refs/heads/$WT_BRANCH" 2>/dev/null || true)

  IS_MERGED=false
  MERGE_REASON=""
  if [ "$TRACKING" = "[gone]" ]; then
    IS_MERGED=true
    MERGE_REASON="远端分支已删（PR 已合并）"
  else
    # 判断二：gh 兜底——upstream 指向错误时查 GitHub PR 状态
    if command -v gh &>/dev/null; then
      PR_STATE=$(gh pr list --head "$WT_BRANCH" --state merged --json number --jq 'length' 2>/dev/null || echo "0")
      if [ "${PR_STATE}" != "0" ] && [ -n "${PR_STATE}" ]; then
        IS_MERGED=true
        MERGE_REASON="PR 已合并（upstream 未绑定自身远端，由 gh 兜底识别）"
      fi
    fi
  fi

  if ! $IS_MERGED; then
    continue
  fi

  # 检查是否有未提交修改
  if ! git -C "$WT_PATH" diff --quiet 2>/dev/null || ! git -C "$WT_PATH" diff --cached --quiet 2>/dev/null; then
    echo "  ⚠️  跳过（有未提交改动）: $WT_PATH"
    echo "      分支: $WT_BRANCH"
    SKIPPED=$((SKIPPED + 1))
    echo ""
    continue
  fi

  echo "  可清理: $WT_PATH"
  echo "    分支: $WT_BRANCH"
  echo "    状态: $MERGE_REASON"

  DO_REMOVE=false
  if $AUTO; then
    DO_REMOVE=true
  else
    printf "    → 删除此 worktree 和本地分支？[y/N] "
    read -r CONFIRM < /dev/tty
    if [[ "${CONFIRM:-N}" =~ ^[yY]$ ]]; then
      DO_REMOVE=true
    fi
  fi

  if $DO_REMOVE; then
    git -C "$REPO_ROOT" worktree remove "$WT_PATH" 2>/dev/null || git -C "$REPO_ROOT" worktree remove "$WT_PATH" --force 2>/dev/null || true
    git -C "$REPO_ROOT" branch -D "$WT_BRANCH" 2>/dev/null || true
    echo "    ✓ 已清理"
    REMOVED=$((REMOVED + 1))
  else
    echo "    - 跳过"
    SKIPPED=$((SKIPPED + 1))
  fi

  echo ""
done <<< "$WORKTREE_LIST"

echo "  完成：清理 $REMOVED 个，跳过 $SKIPPED 个。"
echo ""
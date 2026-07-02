#!/usr/bin/env bash
# serve-worktree.sh — 在 worktree 中启动前端开发服务器，自动分配端口
#
# 使用方式（在任意 worktree 目录下执行）：
#   ./scripts/serve-worktree.sh           # 自动从分支名推断端口
#   ./scripts/serve-worktree.sh 8123      # 手动指定端口
#
# 端口规则（与 vue.config.js 的 process.env.port 对接）：
#   主目录 main / develop  → 80（直接 pnpm local）
#   worktree issue-N       → 8000 + (N % 1000)
#   例：fix/issue-220-xxx  → 8220
#       feature/issue-55   → 8055
#
# 前提：psa-front-desk-pc/.env.local 需由开发者本人按照项目模板自行配置。
#   参考主目录已有的 .env.local，复制后放到本 worktree 的同路径下。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/psa-front-desk-pc"

# ── 1. 确定端口 ───────────────────────────────────────────────────────────────
if [ "${1:-}" != "" ]; then
  PORT="$1"
else
  BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  ISSUE_NUM=$(echo "$BRANCH" | grep -oE 'issue-[0-9]+' | grep -oE '[0-9]+' | head -1)
  if [ -n "${ISSUE_NUM:-}" ]; then
    PORT=$((8000 + ISSUE_NUM % 1000))
  else
    PORT=8080  # fallback：分支名没有 issue-N 时使用
  fi
fi

BRANCH_DISPLAY=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# ── 2. 检查 .env.local ────────────────────────────────────────────────────────
ENV_LOCAL="$FRONTEND_DIR/.env.local"
if [ ! -f "$ENV_LOCAL" ]; then
  echo ""
  echo "  [警告] 未找到 $ENV_LOCAL"
  echo "  请将主目录的 psa-front-desk-pc/.env.local 复制到本 worktree 对应位置后重试。"
  echo "  参考命令（在 repo 根目录执行，替换 <主目录路径>）："
  echo "    cp <主目录路径>/psa-front-desk-pc/.env.local $ENV_LOCAL"
  echo ""
  exit 1
fi

# ── 3. 打印信息并启动（通过环境变量 port 覆盖端口，不修改 .env.local）────────
echo ""
echo "  PSA worktree dev server"
echo "  Branch : $BRANCH_DISPLAY"
echo "  Port   : http://localhost:$PORT"
echo "  API    : http://localhost:48080  (proxy via /proxy-api)"
echo ""

cd "$FRONTEND_DIR"
exec env port="$PORT" pnpm local

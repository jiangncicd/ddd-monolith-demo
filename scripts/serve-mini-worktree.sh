#!/usr/bin/env bash
# serve-mini-worktree.sh — 在 worktree 中启动小程序本地 watch（编译到 dist/dev/mp-weixin）
#
# 使用方式（在任意 worktree 目录下执行）：
#   ./scripts/serve-mini-worktree.sh                      # 自动探测局域网 IP
#   ./scripts/serve-mini-worktree.sh 192.168.6.100        # 手动指定后端 LAN IP
#   PSA_GATEWAY_LAN_IP=192.168.6.100 ./scripts/serve-mini-worktree.sh
#
# 产物输出：<worktree>/psa-mini-program-new/dist/dev/mp-weixin
# 使用微信开发者工具 "导入项目" 指向上述目录进行调试。
#
# 注意：此脚本负责 watch 编译，不会影响 PC 端口，两个脚本可以同时运行。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MINI_DIR="$REPO_ROOT/psa-mini-program-new"

# ── 1. 确定后端 LAN IP ────────────────────────────────────────────────────────
detect_lan_ip() {
  # 优先使用路由表默认出口对应网卡的 IP（与 local-dev-tools 脚本保持一致）
  local iface
  iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}' | head -1)
  if [ -n "${iface:-}" ]; then
    ipconfig getifaddr "$iface" 2>/dev/null || true
  fi
}

if [ -n "${1:-}" ]; then
  LAN_IP="$1"
elif [ -n "${PSA_GATEWAY_LAN_IP:-}" ]; then
  LAN_IP="$PSA_GATEWAY_LAN_IP"
else
  LAN_IP="$(detect_lan_ip)"
fi

if [ -z "${LAN_IP:-}" ]; then
  echo ""
  echo "  [错误] 未能自动识别局域网 IP。"
  echo "  请手动指定：./scripts/serve-mini-worktree.sh 192.168.x.x"
  echo "  或者设置环境变量后重试：export PSA_GATEWAY_LAN_IP=192.168.x.x"
  echo ""
  exit 1
fi

GATEWAY_BASE_URL="http://$LAN_IP:48080"
BRANCH_DISPLAY=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
DIST_DIR="$MINI_DIR/dist/dev/mp-weixin"

echo ""
echo "  PSA 小程序 worktree dev watch"
echo "  Branch  : $BRANCH_DISPLAY"
echo "  API     : $GATEWAY_BASE_URL"
echo "  产物目录 : $DIST_DIR"
echo "  → 微信开发者工具「导入项目」选择上述产物目录"
echo ""

cd "$MINI_DIR"
exec env VUE_APP_LOCAL_GATEWAY_BASE_URL="$GATEWAY_BASE_URL" npm run runlocal

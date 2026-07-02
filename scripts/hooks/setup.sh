#!/usr/bin/env bash
# PSA hooks 依赖体检 + 一键安装
#
# 用法：
#   bash scripts/hooks/setup.sh           # 只检测，不动手装
#   bash scripts/hooks/setup.sh --install  # 检测 + 缺什么自动装（可能 sudo）
#
# 设计意图：
# - 新成员入职 / 系统重装时一键确认 hook 能跑
# - 默认不静默装东西（避免意外 sudo）；--install 显式同意才装
# - Claude 看到无 --install 时报错也能提议"我帮你跑 --install 版"

set -o pipefail

INSTALL=false
[ "${1:-}" = "--install" ] && INSTALL=true

# 让自己能用工具集（与 hook 一致的 PATH 兜底）
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

echo "═══ PSA Hooks 依赖体检 ═══"
echo ""

# ── 检测 ────────────────────────────────────────────────────────────
HAS_JQ=0
HAS_PY3=0
HAS_GIT=0
PY3_NAME=""

if command -v jq >/dev/null 2>&1; then
  echo "  ✅ jq        $(jq --version 2>&1)"
  HAS_JQ=1
else
  echo "  ❌ jq        未安装"
fi

for candidate in python3 py python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0]>=3 else 1)' >/dev/null 2>&1; then
      VER=$("$candidate" --version 2>&1)
      echo "  ✅ Python 3  $candidate ($VER)"
      HAS_PY3=1
      PY3_NAME="$candidate"
      break
    fi
  fi
done
[ $HAS_PY3 -eq 0 ] && echo "  ❌ Python 3  未安装（jq 缺失时作为 fallback）"

if command -v git >/dev/null 2>&1; then
  echo "  ✅ git       $(git --version)"
  HAS_GIT=1
else
  echo "  ⚠️  git      未安装（hook 仍可跑，但分支守卫与文档同步会失效）"
fi

echo ""

# ── 判定 ────────────────────────────────────────────────────────────
if [ $HAS_JQ -eq 1 ] || [ $HAS_PY3 -eq 1 ]; then
  echo "═══ ✅ 依赖满足，PSA hooks 可正常运行 ═══"
  exit 0
fi

# 两者都缺 → 给安装命令
OS=$(uname -s 2>/dev/null || echo unknown)
INSTALL_CMD=""

case "$OS" in
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      INSTALL_CMD="brew install jq"
    else
      INSTALL_CMD='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && brew install jq'
    fi
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      INSTALL_CMD="sudo apt-get update && sudo apt-get install -y jq"
    elif command -v dnf >/dev/null 2>&1; then
      INSTALL_CMD="sudo dnf install -y jq"
    elif command -v yum >/dev/null 2>&1; then
      INSTALL_CMD="sudo yum install -y jq"
    elif command -v apk >/dev/null 2>&1; then
      INSTALL_CMD="sudo apk add jq"
    elif command -v pacman >/dev/null 2>&1; then
      INSTALL_CMD="sudo pacman -S --noconfirm jq"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    if command -v winget >/dev/null 2>&1; then
      INSTALL_CMD="winget install jqlang.jq"
    elif command -v scoop >/dev/null 2>&1; then
      INSTALL_CMD="scoop install jq"
    elif command -v choco >/dev/null 2>&1; then
      INSTALL_CMD="choco install jq"
    fi
    ;;
esac

echo "═══ ❌ jq 与 Python 3 都未安装，hook 无法工作 ═══"
echo ""
if [ -n "$INSTALL_CMD" ]; then
  echo "  推荐安装命令（已按你当前系统检测）："
  echo ""
  echo "    $INSTALL_CMD"
  echo ""
  if $INSTALL; then
    echo "  → 检测到 --install，正在执行..."
    echo ""
    eval "$INSTALL_CMD"
    rc=$?
    echo ""
    if [ $rc -eq 0 ]; then
      echo "═══ ✅ 安装完成，请重新执行 bash scripts/hooks/setup.sh 验证 ═══"
    else
      echo "═══ ❌ 安装失败（退出码 ${rc}），请手工排查 ═══"
    fi
    exit $rc
  else
    echo "  请手工运行上述命令，或重跑本脚本带 --install 参数自动安装："
    echo "    bash scripts/hooks/setup.sh --install"
  fi
else
  echo "  未识别到合适的包管理器（OS=${OS}）。请参考："
  echo "    macOS:   先装 Homebrew (https://brew.sh) 再 brew install jq"
  echo "    Linux:   用你的发行版包管理器装 jq"
  echo "    Windows: 装 winget / scoop / choco 之一，再装 jq"
fi
exit 1

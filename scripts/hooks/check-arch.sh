#!/usr/bin/env bash
# Git pre-push hook：push 前跑 ArchitectureTest，分层违规时阻断推送。
#
# 安装方式（二选一）：
#   ln -sf ../../scripts/hooks/check-arch.sh .git/hooks/pre-push
#   或直接复制到 .git/hooks/pre-push 并 chmod +x
#
# 跳过方式（紧急情况）：
#   git push --no-verify

set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# 定位 JDK 8（macOS），CI 和本地都必须用 JDK 8，否则 Lombok 注解处理器静默失败
if [ "$(uname -s)" = "Darwin" ] && command -v /usr/libexec/java_home >/dev/null 2>&1; then
  JDK8=$(/usr/libexec/java_home -v 1.8 2>/dev/null || true)
  if [ -n "$JDK8" ]; then
    export JAVA_HOME="$JDK8"
  fi
fi

echo ""
echo "══════════════════════════════════════════"
echo "  🏗️  架构守卫：running ArchitectureTest"
echo "══════════════════════════════════════════"
echo ""

# 只编译 + 跑 ArchitectureTest，不跑全量测试（快）
OUTPUT=$(mvn -B test -Dtest=ArchitectureTest -pl . 2>&1)
RESULT=$?

if [ $RESULT -eq 0 ]; then
  echo ""
  echo "  ✅ 架构检查通过，允许推送"
  echo ""
  exit 0
else
  echo ""
  echo "$OUTPUT" | grep -E "FAILURE|Architecture Violation|was violated|Field <|Tests run:"
  echo ""
  echo "  ❌ 架构检查失败！存在分层依赖违规，请修复后再 push"
  echo ""
  echo "  规则说明："
  echo "    domain    ✗→ infrastructure / application / trigger"
  echo "    application ✗→ trigger"
  echo "    trigger   ✗→ infrastructure"
  echo ""
  echo "  跳过（不推荐）：git push --no-verify"
  echo ""
  exit 1
fi

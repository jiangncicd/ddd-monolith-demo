#!/usr/bin/env bash
# Claude Code hooks 回归测试套件
#
# 覆盖：
#   - guard-branch.sh：worktree 文件放行 / develop 阻断 / .git 放行 / 相对路径放行 / Windows 路径
#   - guard-gh-command.sh：label/project/base 校验、body 节匹配（含层级 typo）、Test Plan、Issue 关联
#                          heredoc 兜底、PSA_HOOK_SKIP_PROJECT bypass 与 reminder、git push -u
#   - remind-doc-sync.sh：docs/design/* 触发、CLAUDE.md 触发、AGENTS.md 不触发
#   - _common.sh：jq 主路径 / python3 fallback / get_field 自检 / 数组路径拒绝
#
# 用法：
#   bash scripts/hooks/test-hooks.sh
#
# 退出码：通过 0 / 任一失败 1。
# 建议改 hook 后本地手工跑一次；尚未自动接入 CI workflow（如要接入：新增
# .github/workflows/hooks-test.yml + paths 触发 scripts/hooks/**）。

set -o pipefail

HOOKS=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HOOKS/../.." && pwd)
PASS=0
FAIL=0
FAIL_LIST=""

run() {
  local name="$1" expect="$2" script="$3" payload="$4"
  local extra_env="${5:-}"
  local got exit_code
  if [ -n "$extra_env" ]; then
    got=$(printf '%s' "$payload" | env $extra_env bash "$HOOKS/$script" 2>&1; echo "__EXIT=$?")
  else
    got=$(printf '%s' "$payload" | bash "$HOOKS/$script" 2>&1; echo "__EXIT=$?")
  fi
  exit_code=$(echo "$got" | tail -1 | sed 's/__EXIT=//')
  if [ "$exit_code" = "$expect" ]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ ${name}（期望 exit=${expect} 实际 exit=${exit_code}）"
    echo "$got" | head -6 | sed 's/^/       | /'
    FAIL=$((FAIL+1))
    FAIL_LIST="${FAIL_LIST}\n  - $name"
  fi
}

# 期待 stderr 包含指定文本的运行（exit 同样校验）
run_with_stderr() {
  local name="$1" expect_exit="$2" expect_text="$3" script="$4" payload="$5"
  local extra_env="${6:-}"
  local got exit_code
  if [ -n "$extra_env" ]; then
    got=$(printf '%s' "$payload" | env $extra_env bash "$HOOKS/$script" 2>&1; echo "__EXIT=$?")
  else
    got=$(printf '%s' "$payload" | bash "$HOOKS/$script" 2>&1; echo "__EXIT=$?")
  fi
  exit_code=$(echo "$got" | tail -1 | sed 's/__EXIT=//')
  if [ "$exit_code" = "$expect_exit" ] && echo "$got" | grep -q "$expect_text"; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ ${name}（期望 exit=${expect_exit} 含 '${expect_text}'，实际 exit=${exit_code}）"
    echo "$got" | head -6 | sed 's/^/       | /'
    FAIL=$((FAIL+1))
    FAIL_LIST="${FAIL_LIST}\n  - $name"
  fi
}

# 期待 stdout 是 JSON 且 hookSpecificOutput.additionalContext 包含指定文本
run_with_json_context() {
  local name="$1" expect_event="$2" expect_text="$3" script="$4" payload="$5"
  local extra_env="${6:-}"
  local stdout exit_code
  if [ -n "$extra_env" ]; then
    stdout=$(printf '%s' "$payload" | env $extra_env bash "$HOOKS/$script" 2>/dev/null)
    exit_code=$?
  else
    stdout=$(printf '%s' "$payload" | bash "$HOOKS/$script" 2>/dev/null)
    exit_code=$?
  fi
  # 校验 JSON 合法 + hookEventName 匹配 + additionalContext 含关键字
  if [ "$exit_code" = "0" ] && \
     echo "$stdout" | jq -e --arg ev "$expect_event" --arg t "$expect_text" \
       '.hookSpecificOutput.hookEventName == $ev and (.hookSpecificOutput.additionalContext | contains($t))' >/dev/null 2>&1; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ ${name}（期望 JSON.hookSpecificOutput.{hookEventName=${expect_event}, additionalContext 含 '${expect_text}'}，exit=${exit_code}）"
    echo "$stdout" | head -3 | sed 's/^/       | /'
    FAIL=$((FAIL+1))
    FAIL_LIST="${FAIL_LIST}\n  - $name"
  fi
}

# 用 jq 编码 command 字段为 JSON payload
encode_cmd() {
  jq -n --arg c "$1" '{tool_input:{command:$c}}'
}

# ─────────────────────────────────────────────────────────────────────
echo "[A] guard-branch.sh"
# A1：worktree 内文件放行（cwd=主仓库根，file_path 反查 worktree 分支）
run "A1 worktree feature 分支文件放行" 0 guard-branch.sh \
  "{\"tool_input\":{\"file_path\":\"$REPO_ROOT/scripts/hooks/guard-branch.sh\"}}"
# A2：主仓库 develop 阻断（前提：主仓库当前在 develop）
# 注：本测试当主仓库不在 develop/main 时可能误报；可选跳过
MAIN_REPO=$(git -C "$REPO_ROOT/../.." rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$MAIN_REPO" ]; then
  MAIN_BRANCH=$(git -C "$MAIN_REPO" branch --show-current 2>/dev/null)
  if [ "$MAIN_BRANCH" = "develop" ] || [ "$MAIN_BRANCH" = "main" ]; then
    run "A2 主仓库 $MAIN_BRANCH 分支文件阻断" 2 guard-branch.sh \
      "{\"tool_input\":{\"file_path\":\"$MAIN_REPO/README.md\"}}"
  else
    echo "  ⏭  A2 跳过（主仓库当前在 ${MAIN_BRANCH}，非 develop/main）"
  fi
fi
# A3：.git/ 内文件放行
run "A3 .git/config 放行" 0 guard-branch.sh \
  "{\"tool_input\":{\"file_path\":\"$REPO_ROOT/.git/config\"}}"
# A4：相对路径触发 S5 防御 warn + 放行
run_with_stderr "A4 相对路径 warn + 放行" 0 "非绝对路径" guard-branch.sh \
  '{"tool_input":{"file_path":"scripts/x.sh"}}'
# A5：Windows 风格绝对路径不再触发 S5 warn（即便不在 git 树里也走正常 detached 放行）
OUT=$(echo '{"tool_input":{"file_path":"C:\\Users\\dev\\project\\file.md"}}' | bash "$HOOKS/guard-branch.sh" 2>&1)
if ! echo "$OUT" | grep -q "非绝对路径"; then
  echo "  ✅ A5 Windows 路径 C:\\... 视为绝对（不触发相对路径 warn）"
  PASS=$((PASS+1))
else
  echo "  ❌ A5 Windows 路径仍被判为非绝对：$OUT"
  FAIL=$((FAIL+1))
  FAIL_LIST="${FAIL_LIST}\n  - A5"
fi
# A6：file_path 缺失放行
run "A6 file_path 缺失放行" 0 guard-branch.sh '{"tool_input":{}}'

# ─────────────────────────────────────────────────────────────────────
echo ""
echo "[B] guard-gh-command.sh — flag 校验"
CMD_OK_ISSUE='gh issue create --title x --label P2 --project PSA --body "## 问题点
## 业务背景
## 目标
## 验收标准
## 边界场景清单（AI 辅助）
## 优先级建议"'
CMD_OK_PR='gh pr create --title x --label P2 --base develop --project PSA --body "## 概要
## 改动范围
## 关联 Issue
closes #1
## Test Plan
- [x] ok"'

# B1：完整合规 Issue 放行
run "B1 完整合规 Issue 放行" 0 guard-gh-command.sh "$(encode_cmd "$CMD_OK_ISSUE")"
# B2：完整合规 PR 放行
run "B2 完整合规 PR 放行" 0 guard-gh-command.sh "$(encode_cmd "$CMD_OK_PR")"
# B3：缺 --label 阻断
CMD=$(echo "$CMD_OK_ISSUE" | sed 's/--label P2 //')
run "B3 缺 --label 阻断" 2 guard-gh-command.sh "$(encode_cmd "$CMD")"
# B4：缺 --project 阻断
CMD=$(echo "$CMD_OK_ISSUE" | sed 's/--project PSA //')
run "B4 缺 --project 阻断" 2 guard-gh-command.sh "$(encode_cmd "$CMD")"
# B5：缺 --base 阻断
CMD=$(echo "$CMD_OK_PR" | sed 's/--base develop //')
run "B5 PR 缺 --base 阻断" 2 guard-gh-command.sh "$(encode_cmd "$CMD")"
# B6：--label=P2 等号形式放行
CMD=$(echo "$CMD_OK_ISSUE" | sed 's/--label P2/--label=P2/')
run "B6 --label=P2 等号形式放行" 0 guard-gh-command.sh "$(encode_cmd "$CMD")"

echo ""
echo "[C] guard-gh-command.sh — body 节"
# C1：### 问题点（错层级）应被拒
CMD=$(echo "$CMD_OK_ISSUE" | sed 's/## 问题点/### 问题点/')
run_with_stderr "C1 ### 问题点（错层级）拦下" 2 "## 问题点" guard-gh-command.sh "$(encode_cmd "$CMD")"
# C2：节名缺空格后缀（## 问题点foo）应被拒
CMD=$(echo "$CMD_OK_ISSUE" | sed 's/## 问题点/## 问题点foo/')
run_with_stderr "C2 ## 问题点foo（无边界）拦下" 2 "## 问题点" guard-gh-command.sh "$(encode_cmd "$CMD")"
# C3：缺 (AI 辅助) 后缀应被拒
CMD=$(echo "$CMD_OK_ISSUE" | sed 's/## 边界场景清单（AI 辅助）/## 边界场景清单/')
run_with_stderr "C3 边界场景清单 缺 AI 辅助 后缀拦下" 2 "AI 辅助" guard-gh-command.sh "$(encode_cmd "$CMD")"

echo ""
echo "[D] guard-gh-command.sh — Test Plan / Issue 关联"
# D1：- [X] 大写应通过
CMD=$(echo "$CMD_OK_PR" | sed 's/- \[x\] ok/- [X] ok/')
run "D1 大写 [X] 通过" 0 guard-gh-command.sh "$(encode_cmd "$CMD")"
# D2：缺 [x] 应被拒
CMD=$(echo "$CMD_OK_PR" | sed 's/- \[x\] ok/- [ ] todo/')
run_with_stderr "D2 全 [ ] 未勾选拦下" 2 "已勾选项" guard-gh-command.sh "$(encode_cmd "$CMD")"
# D3：Closes: #N 带冒号通过
CMD=$(echo "$CMD_OK_PR" | sed 's/closes #1/Closes: #123/')
run "D3 Closes: #123 带冒号通过" 0 guard-gh-command.sh "$(encode_cmd "$CMD")"
# D4：Closes:#N 冒号紧贴通过
CMD=$(echo "$CMD_OK_PR" | sed 's/closes #1/Closes:#42/')
run "D4 Closes:#42 紧贴冒号通过" 0 guard-gh-command.sh "$(encode_cmd "$CMD")"
# D5：缺 Issue 关联应被拒
CMD=$(echo "$CMD_OK_PR" | sed 's/closes #1//')
run_with_stderr "D5 缺 Issue 关联拦下" 2 "Issue 关联" guard-gh-command.sh "$(encode_cmd "$CMD")"

echo ""
echo "[E] guard-gh-command.sh — heredoc / 命令前缀"
# E1：heredoc 缺节阻断
CMD='gh pr create --title x --label P2 --base develop --project PSA --body "$(cat << EOF
随便
EOF
)"'
run "E1 heredoc 缺节阻断" 2 guard-gh-command.sh "$(encode_cmd "$CMD")"
# E2：heredoc 完整放行
CMD='gh pr create --title x --label P2 --base develop --project PSA --body "$(cat << EOF
## 概要
## 改动范围
## 关联 Issue
closes #1
## Test Plan
- [x] ok
EOF
)"'
run "E2 heredoc 完整放行" 0 guard-gh-command.sh "$(encode_cmd "$CMD")"
# E3：echo 中字面 gh pr create 不误触发 PR 校验
run "E3 echo 字符串中 gh pr create 不误触发" 0 guard-gh-command.sh \
  "$(encode_cmd 'echo "示例 gh pr create ..."')"
# E4：env 前缀 + gh pr create 触发校验
run "E4 env 前缀 + gh pr create 触发校验" 2 guard-gh-command.sh \
  "$(encode_cmd 'GH_TOKEN=xxx gh pr create --title x')"

echo ""
echo "[F] guard-gh-command.sh — PSA_HOOK_SKIP_PROJECT bypass + reminder"
# F1：bypass 跳过校验
CMD=$(echo "$CMD_OK_ISSUE" | sed 's/--project PSA //')
run "F1a bypass=1 Issue 缺 project 放行" 0 guard-gh-command.sh "$(encode_cmd "$CMD")" "PSA_HOOK_SKIP_PROJECT=1"
# F1b：bypass 触发时 stderr 有 reminder
run_with_stderr "F1b bypass=1 stderr 含 reminder" 0 "手工归属 PSA 看板" guard-gh-command.sh "$(encode_cmd "$CMD")" "PSA_HOOK_SKIP_PROJECT=1"
# F2：未设 bypass 应阻断
run "F2 无 bypass 仍阻断" 2 guard-gh-command.sh "$(encode_cmd "$CMD")"

echo ""
echo "[G] guard-gh-command.sh — git push -u"
# 必须在已 tracking 分支上不阻断
run "G1 git push 在已 tracking 分支放行（取决于 cwd）" 0 guard-gh-command.sh "$(encode_cmd 'git push')"
# G2：git push -u 显式带 -u 放行
run "G2 git push -u 放行" 0 guard-gh-command.sh "$(encode_cmd 'git push -u origin x')"

echo ""
echo "[H] remind-doc-sync.sh — JSON 协议注入 Claude 上下文"
# H1：docs/design/*.md 触发 PostToolUse additionalContext
mkdir -p "$REPO_ROOT/docs/design"
touch "$REPO_ROOT/docs/design/_test_$$.md"
run_with_json_context "H1 docs/design/*.md 通过 JSON 注入文档同步提示" \
  "PostToolUse" "CLAUDE.md 中的对应规则是否需要同步" remind-doc-sync.sh \
  "{\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/design/_test_$$.md\"}}"
rm -f "$REPO_ROOT/docs/design/_test_$$.md"
# H2：CLAUDE.md 触发 PostToolUse additionalContext
run_with_json_context "H2 CLAUDE.md 通过 JSON 注入系统开发流程.md 同步提示" \
  "PostToolUse" "系统开发流程.md" remind-doc-sync.sh \
  "{\"tool_input\":{\"file_path\":\"$REPO_ROOT/CLAUDE.md\"}}"
# H3：AGENTS.md 不触发任何提示（stdout 应为空）
OUT=$(echo "{\"tool_input\":{\"file_path\":\"$REPO_ROOT/psa-backend/AGENTS.md\"}}" | bash "$HOOKS/remind-doc-sync.sh" 2>/dev/null)
if [ -z "$OUT" ]; then
  echo "  ✅ H3 AGENTS.md 不触发（stdout 为空，符合设计）"
  PASS=$((PASS+1))
else
  echo "  ❌ H3 AGENTS.md 误触发，stdout: $OUT"
  FAIL=$((FAIL+1))
  FAIL_LIST="${FAIL_LIST}\n  - H3"
fi
# H4：guard-branch.sh 非规范分支通过 JSON 注入 warn（用临时 git 仓库验证）
TMP_REPO=$(mktemp -d)
git -C "$TMP_REPO" init -q
git -C "$TMP_REPO" config user.email "t@t.t" && git -C "$TMP_REPO" config user.name "t"
touch "$TMP_REPO/file.md"
git -C "$TMP_REPO" add file.md && git -C "$TMP_REPO" commit -qm init
git -C "$TMP_REPO" checkout -qb weird-branch-name
run_with_json_context "H4 guard-branch.sh 非规范分支通过 JSON 注入 warn" \
  "PreToolUse" "不符合命名规范" guard-branch.sh \
  "{\"tool_input\":{\"file_path\":\"$TMP_REPO/file.md\"}}"
rm -rf "$TMP_REPO"

echo ""
echo "[I] _common.sh — JSON 工具检测"
# I1：当前环境（有 jq）应选 jq
OUT=$(/bin/bash -c "source $HOOKS/_common.sh; require_json_tool; echo \$JSON_TOOL")
if [ "$OUT" = "jq" ]; then
  echo "  ✅ I1 有 jq 时选 jq"
  PASS=$((PASS+1))
else
  echo "  ❌ I1 选了 $OUT 而非 jq"
  FAIL=$((FAIL+1))
  FAIL_LIST="${FAIL_LIST}\n  - I1"
fi

# I2：jq 不可达时 fallback 到 python3（构造只含 python3 的临时 PATH）
TMP_BIN=$(mktemp -d)
if command -v python3 >/dev/null 2>&1; then
  ln -s "$(command -v python3)" "$TMP_BIN/python3"
  ln -s "$(command -v cat)" "$TMP_BIN/cat" 2>/dev/null || true
  OUT=$(PATH="$TMP_BIN" /bin/bash -c "source $HOOKS/_common.sh; require_json_tool; echo \$JSON_TOOL")
  if [ "$OUT" = "python3" ]; then
    echo "  ✅ I2 无 jq 时 fallback 到 python3"
    PASS=$((PASS+1))
  else
    echo "  ❌ I2 fallback 失败: $OUT"
    FAIL=$((FAIL+1))
    FAIL_LIST="${FAIL_LIST}\n  - I2"
  fi
  # I3：fallback 路径下 get_field 能正确解析 JSON
  OUT=$(PATH="$TMP_BIN" /bin/bash -c "
source $HOOKS/_common.sh
require_json_tool
INPUT='{\"tool_input\":{\"command\":\"git push origin main\"}}'
get_field '.tool_input.command'
")
  if [ "$OUT" = "git push origin main" ]; then
    echo "  ✅ I3 python3 fallback 下 get_field 工作"
    PASS=$((PASS+1))
  else
    echo "  ❌ I3 get_field 返回: '$OUT'"
    FAIL=$((FAIL+1))
    FAIL_LIST="${FAIL_LIST}\n  - I3"
  fi
else
  echo "  ⏭  I2/I3 跳过（环境无 python3）"
fi
rm -rf "$TMP_BIN"

# I4：get_field 未先调 require_json_tool 应给出明确报错
OUT=$(/bin/bash -c "
source $HOOKS/_common.sh
INPUT='{\"x\":1}'
get_field '.x' 2>&1
")
if echo "$OUT" | grep -q "未先调用 require_json_tool"; then
  echo "  ✅ I4 get_field 自检（缺 init）报错"
  PASS=$((PASS+1))
else
  echo "  ❌ I4 自检未触发，输出: '$OUT'"
  FAIL=$((FAIL+1))
  FAIL_LIST="${FAIL_LIST}\n  - I4"
fi

# I5：F1 数组下标应被入口拒绝
OUT=$(/bin/bash -c "
source $HOOKS/_common.sh
require_json_tool
INPUT='{\"foo\":[\"a\",\"b\"]}'
get_field '.foo[0]' 2>&1
")
if echo "$OUT" | grep -q "不支持数组下标"; then
  echo "  ✅ I5 数组下标 path 被入口拒绝（防 jq/python3 后端语义分叉）"
  PASS=$((PASS+1))
else
  echo "  ❌ I5 数组下标未被拦截，输出: '$OUT'"
  FAIL=$((FAIL+1))
  FAIL_LIST="${FAIL_LIST}\n  - I5"
fi

# I6：detect_install_cmd 在当前平台输出合理的安装命令
OUT=$(/bin/bash -c "
source $HOOKS/_common.sh
detect_install_cmd
")
EXPECT_KEYWORD=""
case "$(uname -s)" in
  Darwin) EXPECT_KEYWORD="brew install jq" ;;
  Linux)  EXPECT_KEYWORD="install -y jq" ;;
  MINGW*|MSYS*|CYGWIN*) EXPECT_KEYWORD="jq" ;;
esac
if echo "$OUT" | grep -q "$EXPECT_KEYWORD"; then
  echo "  ✅ I6 detect_install_cmd 输出当前平台安装命令: $OUT"
  PASS=$((PASS+1))
else
  echo "  ❌ I6 detect_install_cmd 未输出预期关键字 '$EXPECT_KEYWORD'，实际: '$OUT'"
  FAIL=$((FAIL+1))
  FAIL_LIST="${FAIL_LIST}\n  - I6"
fi

echo ""
echo "[J] guard-gh-command.sh — F2/S2 跨平台 Unicode 边界"
# J1：节名后紧贴中文应放行（合规节名 + 中文内容）
CMD='gh pr create --title x --label P2 --base develop --project PSA --body "## 概要中文段落
## 改动范围
## 关联 Issue
closes #1
## Test Plan
- [x] ok"'
run "J1 ## 概要中文段落 放行（中文不应被当 alnum 拒）" 0 guard-gh-command.sh "$(encode_cmd "$CMD")"

# J2：节名后紧贴 ASCII 字母仍应拒（保证不漏放 typo）
CMD='gh pr create --title x --label P2 --base develop --project PSA --body "## 概要foo
## 改动范围
## 关联 Issue
closes #1
## Test Plan
- [x] ok"'
run_with_stderr "J2 ## 概要foo 仍被拒（ASCII alnum 是真 typo）" 2 "## 概要" guard-gh-command.sh "$(encode_cmd "$CMD")"

# J3：节名后紧贴数字仍应拒
CMD='gh pr create --title x --label P2 --base develop --project PSA --body "## 概要1
## 改动范围
## 关联 Issue
closes #1
## Test Plan
- [x] ok"'
run_with_stderr "J3 ## 概要1 仍被拒（数字是 typo）" 2 "## 概要" guard-gh-command.sh "$(encode_cmd "$CMD")"

# ─────────────────────────────────────────────────────────────────────
echo ""
echo "═════════════════════════════════════════════"
echo "PASS=$PASS  FAIL=$FAIL"
if [ $FAIL -gt 0 ]; then
  echo "失败用例："
  printf "%b\n" "$FAIL_LIST"
  exit 1
fi
exit 0

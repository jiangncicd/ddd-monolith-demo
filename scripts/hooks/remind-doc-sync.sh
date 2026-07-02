#!/usr/bin/env bash
# PostToolUse hook：文档一致性双向提示
#
# Hook 1：编辑 docs/design/*.md → 提示确认 CLAUDE.md 是否需要同步
# Hook 2：编辑 CLAUDE.md        → 提示确认 docs/design/系统开发流程.md 是否需要同步
#
# 设计点：
# - 仓库根用 file_path 反查（兼容主仓库 + worktree 双场景；用 cwd 会漏报）
# - 故意不覆盖各子项目 AGENTS.md：它们是 L1 细则，与 CLAUDE.md 叠加生效，
#   不直接对应系统开发流程文档；若以后规则变化再补
# - 提示通过 hookSpecificOutput.additionalContext 注入 Claude 下一轮上下文
#   （exit 0 + stderr 在 Claude Code 主视图与 Claude 上下文里都不可见，
#    必须走 JSON 协议——见 _common.sh::emit_hook_context）
# - 只提示不阻断（exit 0）

set -euo pipefail

# PATH 兜底（必须在 source 之前；dirname 自身就是 /usr/bin 工具）
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# shellcheck source=./_common.sh
source "$(dirname "$0")/_common.sh"

require_json_tool
read_input

FILE=$(get_field '.tool_input.file_path')
[ -z "$FILE" ] && exit 0

# S5：非绝对路径不可靠，不参与提示逻辑（提示比阻断风险低，但仍保持一致）。
# Windows 风格绝对路径（C:\... / D:/...）也算绝对。
if ! is_absolute_path "$FILE"; then
  exit 0
fi

REPO_ROOT=$(repo_root_for_file "$FILE") || exit 0
[ -z "$REPO_ROOT" ] && exit 0
REL="${FILE#"$REPO_ROOT"/}"

# Hook 1：docs/design/ 下的文档
if echo "$REL" | grep -qE '^docs/design/.+\.md$'; then
  emit_hook_context PostToolUse "💡 [文档同步] 已修改 ${REL}。请确认 CLAUDE.md 中的对应规则是否需要同步更新；如需同步请主动修改 CLAUDE.md 相应段落，如确认无需同步请明示。"
fi

# Hook 2：CLAUDE.md（顶层或任意子目录）
if echo "$REL" | grep -qE '(^|/)CLAUDE\.md$'; then
  emit_hook_context PostToolUse "💡 [文档同步] 已修改 CLAUDE.md。请确认 docs/design/系统开发流程.md 是否需要同步更新；如需同步请主动修改流程文档相应段落，如确认无需同步请明示。"
fi

exit 0

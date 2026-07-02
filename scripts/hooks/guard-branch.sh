#!/usr/bin/env bash
# PreToolUse hook：分支守卫
#
# 在 develop / main 分支上执行任意文件编辑（Edit / Write）时阻断，
# 引导走 worktree 流程。git 操作由用户授权后执行。
#
# 关键设计：分支判断基于"被编辑文件所属的工作树"（用 file_path 反查），
# 而非 hook 进程的 cwd——否则在主仓库根启动 Claude Code、编辑 worktree
# 内文件的工作流会被误杀。
#
# 放行：feature/* | fix/* | hotfix/* 分支，或 detached HEAD。
# 非规范分支：仅 warn（exit 0），不阻断，避免历史/实验分支被卡死。
# 阻断：develop / main 上的 Edit/Write，退出码 2。
#
# 注意：Bash 通道的写文件（echo > foo、sed -i、tee 等）不在本守卫覆盖范围；
# Bash matcher 由 guard-gh-command.sh 占用，叠加分支检查会让所有 Bash 调用
# 都先过 git，得不偿失。

set -euo pipefail

# PATH 兜底（必须在 source 之前；dirname 自身就是 /usr/bin 工具）
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# shellcheck source=./_common.sh
source "$(dirname "$0")/_common.sh"

require_json_tool
read_input

FILE=$(get_field '.tool_input.file_path')
[ -z "$FILE" ] && exit 0

# S5：file_path 不是绝对路径时不可靠（dirname 退到 "."，git -C 会拿 hook
# 进程 cwd 的分支误判）。Claude Code 当前总传绝对路径，加防御避免未来回归。
# 同时支持 Windows 风格绝对路径（C:\... / D:/...）以兼容 Git Bash 用户。
if ! is_absolute_path "$FILE"; then
  echo "⚠️ [分支守卫] file_path '$FILE' 非绝对路径，跳过守卫避免误判" >&2
  exit 0
fi

# .git/ 内部文件（config / hooks / info 等）不归本守卫管，
# 这类文件本就不该按分支模型保护，强行阻断只会让 Claude 无法处理 git 内置任务。
# 同时兼容 Windows 反斜杠路径分隔符。
case "$FILE" in
  */.git|*/.git/*|*\\.git|*\\.git\\*) exit 0 ;;
esac

BRANCH=$(branch_for_file "$FILE") || exit 0
[ -z "$BRANCH" ] && exit 0   # detached HEAD 或非 git 目录，不干预

case "$BRANCH" in
  main|develop)
    cat >&2 << EOF

🚫 [分支守卫] 文件 '$FILE' 所属工作树当前在 '$BRANCH' 分支，不允许直接修改。

所有改动必须在独立的 feature/fix 分支上进行。建议步骤：
  1. 确认已有对应 Issue（没有先创建）
  2. 新建 worktree（将 N 替换为 Issue 编号）：
       git worktree add .worktrees/issue-N-描述 feature/issue-N-描述
  3. 在 .worktrees/issue-N-描述/ 目录内继续工作

需要我现在帮你完成上述步骤吗？

EOF
    exit 2
    ;;
  feature/*|fix/*|hotfix/*)
    exit 0
    ;;
  *)
    # 非规范分支：仅提示，不阻断。
    # 走 JSON 协议而非 stderr——后者在 exit 0 时主视图与 Claude 上下文均不可见。
    emit_hook_context PreToolUse "⚠️ [分支守卫] 分支名 '$BRANCH' 不符合命名规范（feature/* | fix/* | hotfix/*）。本次操作已放行，但建议尽早改名或新建规范分支。详见 CLAUDE.md §5。"
    exit 0
    ;;
esac

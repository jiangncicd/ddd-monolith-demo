#!/usr/bin/env bash
# PreToolUse hook：git push / gh issue create / gh pr create 规范守卫
#
# 1. git push 首次推送缺 -u 时阻断
# 2. gh issue create 缺必填元素 / 正文节缺失时阻断
# 3. gh pr create 缺必填元素 / body 节缺失 / Test Plan / Issue 关联时阻断
#
# 设计点：
# - body 校验同时兼容 --body-file 与 heredoc/`--body "..."` 两种写法：
#   PreToolUse 拿到的 command 是 Bash 展开前的原始字符串，heredoc 体的字面
#   文本就在里面，所以 --body-file 路径取不到时直接对整个 COMMAND 兜底 grep
# - 兼容 BSD grep（不使用 -P / PCRE），改用 sed -E 提取 body-file 路径
# - 各 flag 值严格校验（label P0-P3 边界、project=PSA、base=develop|main）
# - 退出码 2 = 阻断工具调用

set -euo pipefail

# PATH 兜底（必须在 source 之前；dirname 自身就是 /usr/bin 工具）
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# shellcheck source=./_common.sh
source "$(dirname "$0")/_common.sh"

require_json_tool
read_input

COMMAND=$(get_field '.tool_input.command')
[ -z "$COMMAND" ] && exit 0

# ── 读取 --body-file 指向的内容（兼容 --body-file /p 与 --body-file=/p）──
read_body_file() {
  local cmd="$1"
  local path
  path=$(printf '%s\n' "$cmd" \
    | sed -nE 's/.*--body-file[= ]+"?'\''?([^'\'' "]+).*/\1/p' \
    | head -n1)
  if [ -n "$path" ] && [ -f "$path" ]; then
    cat "$path"
  fi
}

emit_errors() {
  local guard="$1"
  local cmd="$2"
  local errors="$3"
  # %b 解释 \n。errors 全部由本文件内硬编码字符串拼装，不含用户输入，
  # 故不存在 \x 等转义被误解释的风险（S7 评审顾虑已确认为理论边界）。
  printf "\n🚫 [%s] %s 不符合规范，请补充后重试：%b\n\n" "$guard" "$cmd" "$errors" >&2
  exit 2
}

# ── gh issue create 校验 ─────────────────────────────────────────────
check_issue_create() {
  local errors=""

  if ! echo "$COMMAND" | grep -qE -- "--label[= ]+['\"]?P[0-3]([\"' ]|$)"; then
    errors="${errors}\n  ✗ 缺少优先级标签：--label P0/P1/P2/P3"
  fi
  # B1：CLAUDE.md §7 允许无 project scope 时手工选 PSA 看板；
  # 设 PSA_HOOK_SKIP_PROJECT=1 跳过本检查，通过 JSON 协议提醒事后手工归属
  # （stderr exit 0 在 Claude Code 主视图/上下文都不可见——见 _common.sh）
  if [ "${PSA_HOOK_SKIP_PROJECT:-}" = "1" ]; then
    emit_hook_context PreToolUse "⚠️ [Issue 守卫] PSA_HOOK_SKIP_PROJECT=1：跳过 --project 校验，请在 Issue 页面右侧手工归属 PSA 看板（Status=Todo），不可遗漏。"
  else
    if ! echo "$COMMAND" | grep -qE -- "--project[= ]+['\"]?PSA(['\"]|[[:space:]]|$)"; then
      errors="${errors}\n  ✗ 缺少项目归属：--project \"PSA\"（或设 PSA_HOOK_SKIP_PROJECT=1 跳过，事后必须手工归属）"
    fi
  fi

  # body 校验：先 --body-file，否则兜底用 COMMAND 自身（heredoc / --body "..."）
  local body
  body=$(read_body_file "$COMMAND")
  [ -z "$body" ] && body="$COMMAND"

  # F1：前置非 # + 后置非"ASCII alnum/_/#" 双向边界，
  #   - 拦下 ### 问题点（层级 typo）/ ## 问题点foo（粘连字母）/ ## 问题点1 等
  #   - 允许节名后紧跟 " ' 空白 标点 行尾 中文（合规 PR/Issue 常见结尾形式）
  # F2/S2：用显式 [A-Za-z0-9_#] 而非 POSIX [[:alnum:]]。后者在 BSD/GNU grep +
  # UTF-8 locale 下对中文判定不一致（macOS BSD grep 把中文当 alnum），会导致
  # "## 概要中文段落" 这种合规节名误报缺节、卡死团队。
  # 已知小限制：a## 问题点 这种粘连仍能过（前置 'a' 是非 #），实际极罕见。
  # 不用 ^ 严格行首锚定，是因为 body 字符串里节名常附着在 --body " 后面。
  # B3：节名与 CLAUDE.md §7 模板严格对齐（边界场景清单 含 AI 辅助 后缀）
  for section in "## 问题点" "## 业务背景" "## 目标" "## 验收标准" "## 边界场景清单（AI 辅助）" "## 优先级建议"; do
    if ! echo "$body" | grep -qE "(^|[^#])$section([^A-Za-z0-9_#]|$)"; then
      errors="${errors}\n  ✗ Issue 正文缺少必填节：$section"
    fi
  done

  if [ -n "$errors" ]; then emit_errors "Issue 守卫" "gh issue create" "$errors"; fi
}

# ── gh pr create 校验 ────────────────────────────────────────────────
check_pr_create() {
  local errors=""

  if ! echo "$COMMAND" | grep -qE -- "--label[= ]+['\"]?P[0-3]([\"' ]|$)"; then
    errors="${errors}\n  ✗ 缺少优先级标签：--label P0/P1/P2/P3"
  fi
  if ! echo "$COMMAND" | grep -qE -- "--base[= ]+['\"]?(develop|main)(['\"]|[[:space:]]|$)"; then
    errors="${errors}\n  ✗ 缺少或错误的目标分支：--base develop（hotfix 用 main）"
  fi
  # B1：CLAUDE.md §7 允许无 project scope 时手工选 PSA 看板
  if [ "${PSA_HOOK_SKIP_PROJECT:-}" = "1" ]; then
    emit_hook_context PreToolUse "⚠️ [PR 守卫] PSA_HOOK_SKIP_PROJECT=1：跳过 --project 校验，请在 PR 页面右侧手工归属 PSA 看板（Status=Todo），不可遗漏。"
  else
    if ! echo "$COMMAND" | grep -qE -- "--project[= ]+['\"]?PSA(['\"]|[[:space:]]|$)"; then
      errors="${errors}\n  ✗ 缺少项目归属：--project \"PSA\"（或设 PSA_HOOK_SKIP_PROJECT=1 跳过，事后必须手工归属）"
    fi
  fi

  local body
  body=$(read_body_file "$COMMAND")
  [ -z "$body" ] && body="$COMMAND"

  # F1：前置非 # + 后置空白/行尾 双向边界（详见 check_issue_create 注释）
  for section in "## 概要" "## 改动范围" "## 关联 Issue" "## Test Plan"; do
    if ! echo "$body" | grep -qE "(^|[^#])$section([^A-Za-z0-9_#]|$)"; then
      errors="${errors}\n  ✗ PR 正文缺少必填节：$section"
    fi
  done
  if ! echo "$body" | grep -qE '\-[[:space:]]+\[[xX]\]'; then
    errors="${errors}\n  ✗ Test Plan 缺少已勾选项（- [x]）"
  fi
  # F2：兼容三种写法 closes #N / closes: #N / closes:#N（紧贴冒号）
  if ! echo "$body" | grep -qiE '(closes|fixes|resolves|refs|relates to)(:[[:space:]]*|[[:space:]]+)#[0-9]+'; then
    errors="${errors}\n  ✗ 缺少 Issue 关联语句（closes #N 或 refs #N，冒号可选、可紧贴）"
  fi

  if [ -n "$errors" ]; then emit_errors "PR 守卫" "gh pr create" "$errors"; fi
}

# ── git push 首次推送 -u 检查 ────────────────────────────────────────
check_git_push() {
  if echo "$COMMAND" | grep -qE -- '(-u|--set-upstream)'; then
    return
  fi

  # 推断 git 目录：优先看 git -C <dir>，其次看 cd <dir> && 前缀，最后退到 cwd。
  # 否则在主仓库根启动 Claude Code、用 'cd worktree && git push' 推 worktree
  # 首次分支时，守卫会用 cwd（主仓库 develop）的 tracking 误判放行。
  local push_dir="."
  local dir
  dir=$(printf '%s' "$COMMAND" | sed -nE 's|.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*|\1|p' | head -n1)
  if [ -n "$dir" ] && [ -d "$dir" ]; then push_dir="$dir"; fi
  if [ "$push_dir" = "." ]; then
    dir=$(printf '%s' "$COMMAND" | sed -nE 's|^[[:space:]]*cd[[:space:]]+([^[:space:]&;]+).*|\1|p' | head -n1)
    if [ -n "$dir" ] && [ -d "$dir" ]; then push_dir="$dir"; fi
  fi

  local branch
  branch=$(git -C "$push_dir" branch --show-current 2>/dev/null) || return
  [ -z "$branch" ] && return

  local tracking
  tracking=$(git -C "$push_dir" for-each-ref --format='%(upstream:trackshort)' "refs/heads/$branch" 2>/dev/null || true)
  [ -n "$tracking" ] && return

  cat >&2 << EOF

🚫 [推送守卫] 首次推送缺少 -u 参数，远端分支删除后本地分支无法被清理脚本识别。

请改为：
  git push -u origin $branch

EOF
  exit 2
}

# ── 主逻辑 ───────────────────────────────────────────────────────────
# 严格基于"命令开头"判别，避免 echo / body 文本里出现 gh pr create 等字面
# 被误判。剥掉前置 env vars（VAR=val）和 cd ... && 前缀后，看真正的首命令。
strip_prefix() {
  local cmd="$1"
  # 去前置空白
  cmd=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]+//')
  # 反复剥 VAR=val 形式的环境变量前缀
  while printf '%s' "$cmd" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+'; do
    cmd=$(printf '%s' "$cmd" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+//')
  done
  # 剥一段 cd <dir> && 前缀
  cmd=$(printf '%s' "$cmd" | sed -E 's/^cd[[:space:]]+[^&;]+(&&|;)[[:space:]]*//')
  printf '%s' "$cmd"
}

EFFECTIVE=$(strip_prefix "$COMMAND")

# 已知限制：本守卫看 COMMAND 字符串前缀判命令、用 grep 找 flag。
# heredoc/--body "..." 模式下 body 文本与 flag 字符串混在同一行内，
# 极端情况下 body 里写 "--label Pn" 这类示例文本可能让 flag 校验误判已传。
# 实际工作中这种 PR 极少，已在 README 中标注；不做完美 shell 解析。

case "$EFFECTIVE" in
  "git push"*|"git push -"*|"git -C "*" push"*|"git -C "*" push -"*)
    check_git_push
    ;;
  "gh issue create"*|"gh issue create -"*)
    check_issue_create
    ;;
  "gh pr create"*|"gh pr create -"*)
    check_pr_create
    ;;
esac

exit 0

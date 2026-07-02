#!/usr/bin/env bash
# 共用辅助：JSON 工具检测（jq / python3 fallback）、stdin 解析、文件 → 工作树映射
#
# 设计点：hook 进程的 cwd 是 Claude Code 启动时的目录，不一定等于被编辑文件
# 所属的 git 工作树（典型场景：主仓库根启动 Claude Code、改 worktree 内文件）。
# 因此所有"文件 → 分支 / 仓库根"的反查都必须以 file_path 为准，禁止用 cwd。
#
# 各 hook 通过 source 引入：
#   source "$(dirname "$0")/_common.sh"
# 注意：各 hook 自身也应在文件顶部、source 之前加一行 PATH 兜底（因为
# source 依赖 dirname，dirname 本身就是 /usr/bin 工具）。
#
# 调试模式：设 PSA_HOOK_DEBUG=1 时，python3 fallback 不再吞错，便于排查
# 协议演进或 JSON 形态变化造成的静默失败。

# JSON_TOOL 设计为跨函数共享的全局变量（require_json_tool 写，get_field 读）。
# 各 hook 是独立 bash 进程，无 cross-talk 风险。bash 3.2 兼容性 OK。
JSON_TOOL=""

# 探测当前平台 + 包管理器，输出精准的安装命令。
# Claude 看到这个命令后能直接提议 "我帮你跑 X？"，省去用户手工查文档。
detect_install_cmd() {
  local os
  os=$(uname -s 2>/dev/null || echo unknown)
  case "$os" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        echo "brew install jq"
      else
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && brew install jq'
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        echo "sudo apt-get update && sudo apt-get install -y jq"
      elif command -v dnf >/dev/null 2>&1; then
        echo "sudo dnf install -y jq"
      elif command -v yum >/dev/null 2>&1; then
        echo "sudo yum install -y jq"
      elif command -v apk >/dev/null 2>&1; then
        echo "sudo apk add jq"
      elif command -v pacman >/dev/null 2>&1; then
        echo "sudo pacman -S --noconfirm jq"
      else
        echo "请用你的发行版包管理器安装 jq（apt-get / dnf / yum / apk / pacman）"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if command -v winget >/dev/null 2>&1; then
        echo "winget install jqlang.jq"
      elif command -v scoop >/dev/null 2>&1; then
        echo "scoop install jq"
      elif command -v choco >/dev/null 2>&1; then
        echo "choco install jq"
      else
        echo "请先装 winget（Win 10/11 自带 App Installer）/ scoop / choco 之一，然后 winget install jqlang.jq"
      fi
      ;;
    *)
      echo "请为你的操作系统 ($os) 手动安装 jq"
      ;;
  esac
}

# 兑现 Issue #354 验收清单：jq 优先；jq 不可用时按 python3 → py → python 顺序
# 查找一个真实的 Python 3 解释器。考虑 Windows + Git Bash 上 `python3` 通常不
# 存在，但有 `py` launcher 或 `python`（需是 3.x）。
# 两者都缺时：输出精准平台安装命令到 stderr，Claude 会自动接手提议安装。
require_json_tool() {
  if command -v jq >/dev/null 2>&1; then
    JSON_TOOL=jq
    return
  fi
  local candidate
  for candidate in python3 py python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0]>=3 else 1)' >/dev/null 2>&1; then
        JSON_TOOL="$candidate"
        return
      fi
    fi
  done
  local install_cmd
  install_cmd=$(detect_install_cmd)
  cat >&2 << EOF
🚫 [hook] 缺少 jq 与 python3，无法解析 hook 输入，已阻断当前工具调用。

请运行以下命令安装 jq（已按你当前系统检测）：
    $install_cmd

或安装 Python 3：
    macOS:   brew install python3        （python3 在 /usr/bin 通常已自带）
    Linux:   用包管理器安装 python3
    Windows: https://www.python.org 下载安装时勾选 "Add to PATH"

安装完成后重试当前操作即可。
EOF
  exit 2
}

# 读取 PreToolUse / PostToolUse 的 JSON 输入到全局 INPUT
read_input() {
  INPUT=$(cat)
}

# get_field <jq-path>：返回字段值（找不到返回空字符串）
# 硬性约束：仅支持简单点路径（如 .tool_input.command / .tool_input.file_path）。
# 不支持数组下标（如 .foo[0]）—— jq 分支会成功、python3 fallback 会静默返空，
# 两端语义不等价。为避免守门漏判，入口直接拒绝含 [ 的 path。
get_field() {
  local path="$1"
  # S6：require_json_tool 必须先被调用。未来如有人忘了调用，给出清晰报错而非静默返空
  if [ -z "${JSON_TOOL:-}" ]; then
    echo "⚠️ [hook] get_field 调用前未先调用 require_json_tool，可能是编码错误" >&2
    return 1
  fi
  # F1：拒绝数组下标，避免 jq/python3 后端语义分叉
  case "$path" in
    *\[*)
      echo "⚠️ [hook] get_field 不支持数组下标（path='$path'），当前仅支持 dot path" >&2
      return 1
      ;;
  esac
  if [ "$JSON_TOOL" = "jq" ]; then
    printf '%s' "$INPUT" | jq -r "$path // \"\"" 2>/dev/null || true
    return
  fi
  # python3 fallback：PSA_HOOK_DEBUG=1 时不吞错，方便排查协议变更
  if [ "${PSA_HOOK_DEBUG:-}" = "1" ]; then
    printf '%s' "$INPUT" | JQ_PATH="$path" "$JSON_TOOL" -c '
import sys, json, os
d = json.load(sys.stdin)
path = os.environ.get("JQ_PATH", "").strip(".")
if not path:
    print(""); sys.exit(0)
for k in path.split("."):
    if isinstance(d, dict) and k in d:
        d = d[k]
    else:
        print(""); sys.exit(0)
print(d if d is not None else "")
'
  else
    printf '%s' "$INPUT" | JQ_PATH="$path" "$JSON_TOOL" -c '
import sys, json, os
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); sys.exit(0)
path = os.environ.get("JQ_PATH", "").strip(".")
if not path:
    print(""); sys.exit(0)
for k in path.split("."):
    if isinstance(d, dict) and k in d:
        d = d[k]
    else:
        print(""); sys.exit(0)
print(d if d is not None else "")
' 2>/dev/null || true
  fi
}

# 根据被编辑文件路径解析其所属工作树根；空表示不在 git 树里
repo_root_for_file() {
  local file="$1"
  [ -z "$file" ] && return 1
  local dir
  dir=$(dirname "$file")
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null
}

# 根据被编辑文件路径解析其所属工作树当前分支
branch_for_file() {
  local file="$1"
  [ -z "$file" ] && return 1
  local dir
  dir=$(dirname "$file")
  git -C "$dir" branch --show-current 2>/dev/null
}

# 判断 file_path 是否为绝对路径。POSIX 风格 (/...) 或 Windows 风格 (C:\... 或 C:/...)
# 均视为绝对。供 guard-branch.sh / remind-doc-sync.sh 共用，避免重复实现。
is_absolute_path() {
  case "$1" in
    /*|[A-Za-z]:[/\\]*) return 0 ;;
    *) return 1 ;;
  esac
}

# 通过 Claude Code 的 JSON 输出协议把字符串注入 Claude 下一轮对话上下文。
# 任何 hook 用 exit 0 + stderr 都不会进 Claude 上下文（也不在用户主对话视图
# 显示，仅 transcript mode 下可见）；要让 Claude 看到"软提示"必须走
# hookSpecificOutput.additionalContext 字段。本函数封装 JSON 生成，
# 避免每个 hook 自己拼字符串转义。
#
# 用法：emit_hook_context PostToolUse "提示文本"
#       emit_hook_context PreToolUse "警告文本"
emit_hook_context() {
  local event="$1"
  local msg="$2"
  [ -z "$msg" ] && return 0
  if [ "${JSON_TOOL:-}" = "jq" ]; then
    jq -nc --arg ev "$event" --arg msg "$msg" '{
      hookSpecificOutput: {
        hookEventName: $ev,
        additionalContext: $msg
      }
    }'
  elif [ -n "${JSON_TOOL:-}" ]; then
    EVENT="$event" MSG="$msg" "$JSON_TOOL" -c '
import json, os
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": os.environ["EVENT"],
        "additionalContext": os.environ["MSG"]
    }
}, ensure_ascii=False))
'
  fi
}

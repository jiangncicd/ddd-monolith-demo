# PSA Claude Code Hooks

四个 hook 在工具调用前后自动守门，保证：

- `develop` / `main` 分支不被直接编辑（引导走 worktree）
- `gh issue create` / `gh pr create` 必填元素齐全（label / project / base / body 节）
- `git push` 首次推送带 `-u`，避免远端分支删除后本地无法清理
- 改 `CLAUDE.md` 或 `docs/design/*.md` 时双向提示文档同步

## 首次使用

```bash
bash scripts/hooks/setup.sh
```

| 输出 | 含义 | 下一步 |
|---|---|---|
| `✅ 依赖满足` | 可直接用 | 无 |
| `❌ jq 与 Python 3 都未安装` | hook 跑不起来 | 跑 `bash scripts/hooks/setup.sh --install`，或让 Claude 帮你装 |

实际上 hook 运行时一旦发现缺依赖也会自动报错 + 给出当前平台的安装命令，**Claude 看到报错会主动提议帮装**，所以不跑 setup.sh 也行——只是 setup.sh 让首次确认更直观。

## 平台覆盖

| 平台 | jq | python3 fallback | 行为 |
|---|---|---|---|
| macOS 26+ | ✅ `/usr/bin/jq` 系统自带 | ✅ `/usr/bin/python3` 自带 | 零配置 |
| macOS 12-25 | 需 `brew install jq` | ✅ 自带 | python3 fallback 接管，无需装 jq |
| Linux | 多数发行版 jq 默认或一行 apt | ✅ 通常自带 | 零配置或一行 |
| Windows + Git Bash | `winget install jqlang.jq` | 需装 Python 3.x | 装其一 |
| Windows 原生 cmd / PowerShell | — | — | **不支持**，请用 WSL 或 Git Bash |

## 调试

| 环境变量 | 作用 |
|---|---|
| `PSA_HOOK_SKIP_PROJECT=1` | 跳过 `gh issue/pr create` 的 `--project "PSA"` 校验（无 project scope 时降级用，事后必须手工归属 PSA 看板） |
| `PSA_HOOK_DEBUG=1` | python3 fallback 不再吞错，便于排查协议变更导致的解析失败 |

## 验证

改动 hook 后本地跑：

```bash
bash scripts/hooks/test-hooks.sh
```

包含 39+ 用例，覆盖：flag 校验、body 节匹配（含 `### 问题点` 层级 typo / 中文紧贴 / 等号形式）、heredoc 兜底、Test Plan、Issue 关联、bypass + reminder、git push -u、文档同步、jq → python3 fallback、数组路径拒绝、平台 install 命令。

## 已知限制

- `bash -c "..."` / `&& gh pr create` 链式调用穿不透——守卫只看命令首段
- Bash 通道写文件（`tee` / `sed -i` / `echo >`）不在分支守卫覆盖范围
- `gh pr edit` / `gh issue edit` / `gh issue close` 不被守门（创建期已是关键卡点）
- Issue Type GraphQL 补设（CLAUDE.md §7 三要素之一）hook 看不到，仍靠人工守

## 文件构成

```
scripts/hooks/
├── _common.sh             # 共用 helper（JSON 工具检测 + 字段解析 + 平台 install 命令）
├── guard-branch.sh        # PreToolUse Edit/Write：分支守卫
├── guard-gh-command.sh    # PreToolUse Bash：git push -u / gh issue|pr create 守卫
├── remind-doc-sync.sh     # PostToolUse Edit/Write：文档同步双向提示
├── setup.sh               # 依赖体检 + 一键安装
├── test-hooks.sh          # 回归测试套件
└── README.md              # 本文件
```

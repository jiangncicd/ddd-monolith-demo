# AGENTS.md

本文件为 Codex（Codex.ai/code）在此仓库中工作时的行为准则与项目说明。
仓库为 monorepo，**栈级别的细则下沉到各子项目目录下的 `AGENTS.md`**：

当你在某子项目目录内工作时，对应的 L1 文件会被自动加载，与本文件叠加生效。本文件只承载跨栈通用约束。

---

## 1. 工作原则

- 默认直接输出可落地的生产代码，不输出示意性、占位性、无法验证的半成品实现。
- 修改前先理解当前代码结构与调用链；结论不确定时，先说明假设，再用最小验证动作确认。
- 优先定位并修复根因，避免表层补丁、重复逻辑和无关副作用。
- 所有改动力求小而精、边界清晰，并与仓库现有风格保持一致。
- 完成实质性修改后，立即执行距改动最近的校验（编译、构建、测试、lint、typecheck、接口验证）；无法执行时需明确说明原因。
- 从具体入口点开始（当前文件、报错位置、调用点、测试命令），搜索范围保持最小，只读解决当前问题所需的邻近代码。
- 第一次实质性修改后先做一次冒烟验证，再决定是否继续扩展改动范围。
- 不主动修复无关问题；发现与当前任务直接冲突的不一致时，提示用户确认后再处理。

---

## 2. 通用代码规范

- 不因"看起来更现代"而替换现有可工作的写法，除非任务明确要求重构。
- 不静默修改公共接口、数据库语义、流程状态语义；涉及此类变更时，必须显式说明影响面。
- 注释保持克制：只在业务规则、状态流转、边界判断等处补充必要说明，不做描述性复述。

> 栈专属代码规范（DO 字段注释、`this.methodName` 约定、pnpm 强制、uni-app 写法等）见各子项目 AGENTS.md。

### 2.1 横切安全规则（三端共同遵守）

以下规则对应项目已知高风险技术债，**任何子项目的任何 PR 均适用**：

- **凭据禁入代码**：禁止在代码、注释、配置文件中出现任何 Token / Secret / AES Key / 数据库密码 / API 密钥；必须放 Nacos 配置中心，本地使用 `application-local-secret.yaml`（已在 `.gitignore`）。发现存量时立即告知，不在 PR 中扩散。
- **接口字段变更须同步**：后端 DTO 增删字段时，必须同步检查 `psa-front-desk-pc/src/api/` 与小程序 `api/` 的对应调用点，并在 PR 正文"改动范围"中显式列出受影响文件（X2 API 契约自动化建立之前的人工守门）。
- **DDL 变更须说明 + 走 Flyway**：新增/修改表结构必须在 PR 正文"改动范围"列出 DDL 内容；**自 B1（#477）起 Flyway 已建立**，DDL 一律写 `V{yyyyMMddHHmmss}__{描述}.sql`（落 `psa-backend/yudao-module-fst/yudao-module-fst-biz/src/main/resources/db/migration/`，**SQL Server 方言**；已合并脚本永不改、只追加）。**Flyway 版本锁 `7.15.0`，禁止升级到 V8+**——Flyway Community 自 V8 起不支持 SQL Server 2016（dev/prod 库版本），升上去 fst 在 dev/prod 启动时会抛 license 异常、无法启动；且**本地 Testcontainers 只有 2017、验不出 2016 的 edition 闸**，涉 DB 版本敏感依赖须 dev 真机最终确认。完整规则见《Flyway 迁移操作规范》(`docs/design/Flyway迁移操作规范.md`)（§6.1 版本约束）。
- **枚举 / 状态值 SSOT**：触碰业务状态值时，优先查找 `enums.registry` 包（X1 SSOT 建设方向）中的现有枚举；新增状态常量前说明无法复用已有枚举的原因。禁止向 `FSTConstant` 追加新的状态常量内部类。

---

## 3. 项目快照
### 团队角色

| 角色 | 姓名 | 职责要点 |
|---|---|---|
| 业务 Admin | 都业梁 | 需求 Issue、dev 环境验收、Issue 关闭 |
| IT Admin | 江勇超 | Tech Lead、复杂 PR Review、架构规划、生产部署 |
| 全栈开发 | 刘浩之、刘富之、吴云杰 | 功能开发、简单 PR 互相 Review |

简单 PR（< 100 行，不涉及 migration / 跨模块 / 核心业务规则）：开发之间互相 Review 即可合并；复杂 PR 需 IT Admin Review。

---

## 4. 架构地图

> 后端本地依赖（Nacos / Redis / RocketMQ / SQL Server / XXL-JOB 地址及 Profile 配置）见 [psa-backend/AGENTS.md §5](psa-backend/AGENTS.md)。

### 环境说明

| 环境 | 对应分支 | 用途 |
|---|---|---|
| local | feature / fix 分支 | 开发人员本地调试 |
| dev | `develop` | 功能集成 + 业务 Admin 验收（阿里云 ECS，独立库，Nacos/Redis/RocketMQ 与 prod 共用实例但不同 namespace） |
| prod | `main` | 生产环境（阿里云） |

---

### 前后端对应关系

PC 端 `src/api/` 和 `src/views/` 按业务域组织（project、bpm、accounting、system 等），与后端模块路由一一对应。小程序端 `pages/` 分为 `work/`、`mine/`、`qyLogin/`、`common/`。

> 各栈的模块分层细节、构建命令、本地依赖见对应子项目 AGENTS.md。

---

## 5. 分支与集成流程

### 分支模型

| 分支 | 对应环境 | 用途 |
|---|---|---|
| `main` | prod | 生产分支；只承接 `develop → main` release PR |
| `develop` | dev（阿里云 ECS） | 集成验收分支；承接所有功能开发 PR |
| `feature/issue-{N}-{简述}` | local | 日常功能开发分支 |
| `fix/issue-{N}-{简述}` | local | Bug 修复分支 |
| `hotfix/issue-{N}-{简述}` | local | P0 紧急修复，从 `main` 创建，合并后同步回 `develop` |

### 开发流程

- **所有改动**：从 `develop` 创建分支 → 本地自测 → PR 到 `develop` → CI + Review → 合并 → 部署 dev → 业务 Admin 验收（需验收的 Issue）→ `develop → main` release PR → 部署 prod
- **hotfix（P0 紧急）**：从 `main` 创建分支 → PR 到 `main` → 合并 → 部署 prod → 同步 cherry-pick 到 `develop`

### 合并策略

统一使用 **Squash and merge**，保持 `main` / `develop` 历史干净。每个 PR 对应一个 commit，commit message 含 Issue 编号。

### 分支推送约束

首次推送本地分支时必须带 `-u`：`git push -u origin <branch-name>`。

---

## 6. CI/CD 流水线

### PR 门禁（自动触发）

| Workflow | 作用 |
|---|---|
| `pr-gate.yml` | 路径过滤 + 按需执行：后端编译、P0 单元测试、**Flyway 迁移真跑（ubuntu Testcontainers SQL Server，仅 `db/migration` 变更时）+ 迁移卫生（不可变性/单调性，见《Flyway 迁移操作规范》）**、前端构建 + Lint、小程序构建、状态契约校验 |
| `pr-hygiene.yml` | 检查 PR 格式合规：优先级标签、Issue 关联语句、Test Plan |
| `cd-dev.yml` | `develop` 合并后自动部署到 dev 环境 |

`pr-gate` 和 `pr-hygiene` 全部通过是合并的必要条件（分支保护规则硬卡）。

> 后端 P0 单元测试清单见 [psa-backend/AGENTS.md](psa-backend/AGENTS.md)。

---

## 7. Issue 与 PR 规范

> 完整规范见 `docs/design/PSA开发流程.md`，本节列出 Codex 需要遵守的核心约束。

### 基本原则

- 所有涉及 GitHub 的操作（Issue、PR、评论、标签、关闭等）必须使用 `gh` CLI，不使用网页手动操作。
- Issue 和 PR 的标题与正文全部使用中文。
- Issue 描述问题（场景 + 验收标准 + 边界案例），不起草技术方案；PR 描述本次提交做了什么，必须关联对应 Issue。

---

### Issue 规范

#### Issue 格式

**标题**：`{type}({scope}): 简短中文描述`

**正文必须包含**：`## 问题点`、`## 业务背景`、`## 目标`、`## 验收标准`、`## 边界场景清单（AI 辅助）`、`## 优先级建议`

#### Issue 创建三要素

**Issue 必须同时完成以下三项，缺一不可：**

| 要素 | 值域 | 设置方式 |
|---|---|---|
| **优先级标签** | `P0` / `P1` / `P2` / `P3` | `gh issue create --label P2 ...` |
| **项目归属** | `PSA` 看板 | `gh issue create --project "PSA" ...` |
| **Issue Type** | `Bug` / `Feature` / `Task` | 创建后 GraphQL API 补设（见下） |

Type 取值说明：

| Type | 适用场景 |
|---|---|
| `Bug` | 非预期行为、功能错误、数据异常 |
| `Feature` | 新功能、用户可感知的改进 |
| `Task` | 工程任务、CI / 基础设施、文档、重构 |

`gh issue create` 不支持 `--type`，Type 须在创建后通过 GraphQL API 补设。**标准操作序列（含三要素）**：

```bash
# 1. 创建 Issue（同时指定 label + project，两者不可遗漏）
ISSUE_URL=$(gh issue create \
  --title "type(scope): 中文描述" \
  --label "P2" \
  --project "PSA" \
  --body-file /tmp/body.md)
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

# 2. 获取 Issue Node ID（Type 设置需要 Node ID）
ISSUE_NODE_ID=$(gh api graphql -f query='
  query($owner:String!,$repo:String!,$num:Int!) {
    repository(owner:$owner,name:$repo){ issue(number:$num){ id } }
  }' -f owner=FORCITIS -f repo=PSA -F num=$ISSUE_NUM \
  --jq '.data.repository.issue.id')

# 3. 设置 Type（三要素最后一步，必须完成）
# Type IDs（FORCITIS/PSA 仓库固定值）：
#   Task:    IT_kwDOENt5is4B_Sqj
#   Bug:     IT_kwDOENt5is4B_Sqk
#   Feature: IT_kwDOENt5is4B_Sql
gh api graphql -f query='
  mutation($issueId:ID!, $typeId:ID!) {
    updateIssue(input:{id:$issueId, issueTypeId:$typeId}){ issue{ number } }
  }' -f issueId="$ISSUE_NODE_ID" -f typeId="IT_kwDOENt5is4B_Sqj"
```

**项目归属说明**：`--project` 需要 token 具备 `project` scope；首次使用前执行一次 `gh auth refresh -s project`（会打开浏览器授权）。若暂时无 `project` scope，退化为：创建后在 Issue / PR 页面右侧 `Projects` 栏手动选择 `PSA`（Status 选 `Todo`），但**必须补上，不可遗漏**。PR 同样需要归入 `PSA` 看板：`gh pr create ... --project "PSA"`。

**优先级缺省规则**：新建 Issue 时若无法判断，按正文"## 优先级建议"取值，缺省 `P2`；PR 优先级与关联 Issue 保持一致。

需要业务验收的 Issue，PR 合并后保持 OPEN，验收通过后由业务 Admin 手动关闭并补充验收记录。

---

### PR 规范

#### PR 格式

**标题**：`{type}({scope}): 简短中文描述 (#IssueNumber)`

- `type` 必须是以下之一（小写，与 `pr-hygiene.yml` 正则一致）：`fix` / `feature` / `chore` / `docs` / `refactor` / `discuss`
- `scope` 只允许小写字母 / 数字 / 连字符（正则 `[a-z0-9-]+`），不能用中文 / 下划线 / 空格
- 示例：`chore(timesheet): approval_time → approved_time 命名规整 (#134)`

**正文必须包含**：
- `## 概要`
- `## 改动范围`
- `## 关联 Issue`（`closes #N` 或 `refs #N`）
- `## Test Plan`（至少一条已勾选项，否则 PR Hygiene 门禁不通过）

**Test Plan 执行约束**：调用 `gh pr create` 时，Test Plan 段**必须包含至少一条 `- [x]` 已勾选项**，不允许整段都是 `- [ ]`。已勾选项应是创建 PR 前已经完成的事实（例如代码审查通过、关键路径自测、迁移脚本幂等性已校验等），不要勾"未来才会做"的事。示例：

```markdown
## Test Plan

- [x] 本地编译通过 (`mvn compile -pl yudao-module-fst/yudao-module-fst-biz -am`)
- [x] 关键路径代码审查完成，无遗漏引用
- [ ] dev 环境部署后业务侧验收（合并后执行）
```

**分支命名约束**：本地分支必须使用 `feature/issue-{N}-{简述}` / `fix/issue-{N}-{简述}` / `hotfix/issue-{N}-{简述}` 格式（见第 5 节）；不使用 `chore/`、`docs/` 等其他前缀，否则 PR Hygiene 会出 warning。Issue 类型用 PR 标题前缀区分（`chore(scope):` / `docs(scope):` 等），分支名按以上三选一。

**PR Hygiene rerun 限制**：通过 `gh pr edit --body` / `gh pr edit --title` / `gh pr edit --add-label` 修改 PR 元数据后，**`gh run rerun` 不会让 hygiene 拿到新数据** —— rerun 使用的是首次 `pull_request` 事件触发时的 payload 快照。如果第一次创建 PR 时漏了必备项（缺 `[x]`、缺 label、标题格式错），修复后必须 **push 新 commit**（例如空提交 `git commit --allow-empty`）或 close/reopen PR 触发新事件，hygiene 才会重新评估。注：本限制只影响读取 PR metadata 的检查（hygiene），不影响读取 commit / 文件内容的检查（backend compile / frontend build 等），后者用 `gh run rerun` 是安全的。

#### 关联语义

| 关键词 | 适用场景 |
|---|---|
| `closes / fixes / resolves #N` | 合并即完成，无需业务验收（技术类、CI 类、文档类） |
| `refs / relates to #N` | 合并后仍需业务 Admin 在 dev / 生产环境验收后手动关闭 |

**判断口诀**：合并后是否还需要用真实业务数据 / 流程在 dev 或生产验证一次？需要 → `refs`，不需要 → `closes`。

#### 优先级标签规则

PR 必须且只能带一个优先级标签：`P0` / `P1` / `P2` / `P3`（pr-hygiene 硬卡）。调用 `gh pr create` 时**必须**显式传 `--label P{0|1|2|3}`，不允许创建后再补。

#### 目标分支与改动类型

改动类型由 PR 标题前缀（`fix(...)` / `feature(...)` / `chore(...)` 等）决定，**不是单独的 GitHub Label**：

| 改动类型 | 目标分支 | 含义 |
|---|---|---|
| `feature` / `fix` / `chore` / `docs` / `refactor` | `develop` | 所有日常改动，统一走 develop |
| `breaking` | `develop` | 破坏性变更，需 dev 验收 + 客户知会 |
| `hotfix` | `main` | P0 紧急修复，合并后同步回 develop |

需要业务验收的 Issue，PR 合并后保持 OPEN，验收通过后由业务 Admin 手动关闭并补充验收记录。

### 项目归属（Project）

所有新建的 Issue 与 PR **必须加入 `PSA` 项目看板**（GitHub Projects，新建项默认 Status = `Todo`），用于统一进度跟踪；不允许游离在看板之外。

**执行约束**：
- 优先在创建时直接归属：`gh issue create ... --project "PSA"` / `gh pr create ... --project "PSA"`，不在创建后再补。
- `--project` 需要 token 具备 `project` scope。当前 `gh` 默认 token 只有 `gist / read:org / repo / workflow`，**缺 `project`**；首次使用前需一次性执行 `gh auth refresh -s project`（会打开浏览器授权）。
- 若暂时拿不到 `project` scope，则退化为：创建后在 Issue / PR 页面右侧 `Projects` 栏手动选择 `PSA`（Status 选 `Todo`），但必须补上，不可遗漏。

---

## 8. 执行质量标准

### 修改前确认

- 确认语法与上下文运行一致（语言、框架、构建方式、样式预处理器）后再写代码。
- 涉及交互改造前，确认输入 → 显示 → 提交链路一致性。
- 对需求中"必须满足的验收条件"，实现过程中持续对标，避免功能漏移。

### 审查意见处理

收到审查意见时，必须评估：
1. 与需求和验收标准是否一致。
2. 是否影响正确性、稳定性、可维护性。
3. 是否在当前改动范围内可安全落地。

采纳与不采纳均需给出明确理由；当前范围外的建议记录后续处理路径。

### 命令执行安全

- shell 中涉及多行正文、Markdown 或特殊字符时，优先使用临时文件 + `--body-file` 等稳定输入方式。
- 执行命令前检查副作用范围（本地 / 远程、当前目录 / 全局、是否可逆），避免误操作。

### 推送前本地验证

复杂逻辑变动（流程引擎 / 事务边界 / 状态机 / 并发 / 跨服务交互 / 数据迁移等）**「仅编译通过」不等于「验证通过」**：必须先在本地或 dev 完成运行时测试、确认行为符合预期，再决定是否 `push`。

- 未经运行时验证的复杂改动，可以本地 `commit` 存档，但**不得 `push`**（不触发 PR / CI / 部署）。
- 简单改动（文档、配置、无歧义的机械替换等）不受此限，按常规流程推进。
- 本约束是第 1 节"完成实质性修改后立即就近校验"的加强：就近校验解决"改对没有"，本约束确保"复杂逻辑在 push 前已被真正跑通"。


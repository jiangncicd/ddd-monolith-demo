# CI/CD 配置说明

本文档说明本工程在 GitHub 上的持续集成 / 持续交付配置，包括 workflow、分支保护规则（Rulesets）、合并策略与落地顺序。

---

## 1. 总览

| 组成 | 位置 / 载体 | 作用 |
|---|---|---|
| CI workflow | `.github/workflows/ci.yml` | push 到 main/develop、所有 PR 时，编译 + 测试 + 打包 |
| CD workflow | `.github/workflows/cd.yml` | push 到 main 时，打 jar 并作为构建产物存档 |
| 分支保护 | GitHub Rulesets（Settings → Rules → Rulesets） | 禁止直接 push main、强制 PR、CI 过了才能合 |

工程技术栈：**Maven + Java 1.8 + Spring Boot 2.7.18**。

---

## 2. 关键前提：CI 必须用 JDK 8

> ⚠️ **最容易踩的坑。**

本工程依赖 Spring Boot 2.7.18 自带的 Lombok 版本，该版本在高版本 JDK（如 JDK 26）下**注解处理器会静默失败**——不会报清晰错误，而是让全仓库出现大量“找不到 getter / builder”的编译错误。

因此：

- **CI 里必须显式安装 JDK 8**（本工程用 Zulu 8）。
- 本地构建同理，需将 `JAVA_HOME` 指向 JDK 8，例如：
  ```bash
  export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
  mvn -B verify
  ```

测试（`ApiTest` / `ArchitectureTest` 等）使用内存 H2 + Flyway，`RiskHttpAdapter` 在未配置 `risk.service.url` 时自动降级放行，**不依赖任何外部服务**，因此 CI 中直接 `mvn test` 即可，无需起 DB / Redis / MQ。

---

## 3. CI Workflow（`.github/workflows/ci.yml`）

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 8
        uses: actions/setup-java@v4
        with:
          distribution: zulu      # 与本地 Zulu 8 一致；Lombok 需 JDK 8，勿升级
          java-version: '8'
          cache: maven            # 自动缓存 ~/.m2，加速构建

      - name: Build & Test
        run: mvn -B verify        # verify = compile + test + package
```

要点：

- **触发时机**：PR 阶段做“合并前门禁”；push（含 PR 合并）到 main/develop 做“合并后验证”。
- `mvn -B`：batch 模式，无交互、日志干净。
- `cache: maven`：`setup-java` 自动缓存依赖，加速后续构建。
- **job 名 `build-and-test`** 即对外暴露的 status check 名，分支保护里要引用它（见第 5 节）。

### `on: push: [main]` 与“禁止直接 push main”是否冲突？

不冲突，分两层理解：

- **分支保护**挡的是“人手动 `git push` 到 main”。
- **`on: push: [main]`** 指“有 commit 落到 main 时触发”——PR 合并本质也是一次 push 事件，所以它的作用是“代码合进 main 后自动再验一次”，走的是合并这条合法路径。

---

## 4. CD Workflow（`.github/workflows/cd.yml`）

```yaml
name: CD

on:
  push:
    branches: [main]

jobs:
  package:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 8
        uses: actions/setup-java@v4
        with:
          distribution: zulu      # Lombok 需 JDK 8，勿升级
          java-version: '8'
          cache: maven

      - name: Package
        run: mvn -B package -DskipTests

      - name: Upload jar
        uses: actions/upload-artifact@v4
        with:
          name: app-jar
          path: target/*.jar
```

要点：

- 合并到 main 后，打出 jar 并作为 artifact 上传，可在 Actions 页面下载。
- 这是**最简 CD**，不涉及任何服务器凭据。真正部署（SSH 到 ECS / 构建并推送 Docker 镜像 / K8s 等）需在 `mvn package` 之后追加步骤。
- **凭据只放 GitHub Secrets，绝不写进 yml**（横切安全红线：凭据禁入代码 / 配置）。

---

## 5. 分支保护（GitHub Rulesets）

目标：**禁止直接 push main + 必须走 PR + CI 过了才能合**。

在 Settings → Rules → Rulesets 新建一条 ruleset。

### 5.1 需要打开的规则

| 规则 | 设置 | 作用 |
|---|---|---|
| **Require a pull request before merging** | 开 | 核心：禁止直接 push，所有改动走 PR |
| └ Required approvals | `1`（单人 demo 可 `0`） | 至少 1 人 approve |
| └ Allowed merge methods | 只勾 **Squash** | 对齐「统一 Squash and merge」（见 5.3） |
| **Require status checks to pass** | 开 | 核心：CI 绿了才能合 |
| └ 添加 check | `build-and-test` | 对应 `ci.yml` 的 job 名 |
| └ Require branches to be up to date before merging | 开 | 合并前必须基于最新 main |
| **Block force pushes** | 开 | 防止对 main 强推 |
| **Restrict deletions** | 开 | 防止 main 被删 |

### 5.2 建议保持关闭（按需再加）

- Restrict creations / Restrict updates —— “Require PR” 已管住正常流程，开了反而挡 PR 合并
- Require linear history —— 可选；用 Squash 时开着也兼容，想简单可先不开
- Require signed commits —— 需本地配 GPG/SSH 签名，增加摩擦，demo 阶段不开
- Require deployments to succeed —— 尚未配置 environments，开了无意义
- Require conversation resolution / Dismiss stale approvals —— 团队协作时按需开
- Code scanning / Code quality / Code coverage / Copilot review / Enterprise 限制项 —— demo 用不上

### 5.3 三个不在规则列表里、但必须确认的

漏了这三项，整条规则等于没生效：

1. **Enforcement status**（页面顶部）—— 必须设为 **Active**（不是 Disabled / Evaluate）。
2. **Target branches** —— 把 **`main`** 加进目标（Include default branch，或按名字 `main`）。
3. **Bypass list** —— 想让管理员也一起卡，就**保持 bypass 列表为空**；留了谁，谁就能绕过。

### 5.4 status check 在哪里添加

1. 先打开 **Require status checks to pass** 开关（打开前只显示 “No required checks”）；
2. 下方出现 **`+ Add checks`** 按钮，点击后输入框里填 `build-and-test`；
3. 顺手勾 **Require branches to be up to date before merging**。

> check 只有**跑过至少一次**后才会出现在自动补全里。新版 Rulesets 允许**手输名字**添加，但名字必须与 job key 一字不差，拼错会导致 PR 永远等一个不存在的 check、合不了。

---

## 6. 合并方式说明（为什么只勾 Squash）

GitHub 合并 PR 有三种方式，区别在于往 main 写入什么样的 commit：

| 方式 | 往 main 写入什么 | 结果 |
|---|---|---|
| Merge commit | 保留分支所有提交 + 生成 merge commit | 历史出现分叉，带进零碎 commit |
| **Squash and merge** | 多个 commit 压成 1 个再放到 main | 每个 PR = 一个干净 commit，线性历史 |
| Rebase and merge | 逐个把分支 commit 贴到 main 顶端 | 线性历史，但保留每个原始 commit |

**只勾 Squash** 是把「每个 PR 对应一个 commit、含 Issue 编号」这条规范在 GitHub 层面强制下来，避免 `wip` / `fix typo` 等零碎提交污染主干。合并时那个 commit 的 message 建议写成 `type(scope): 描述 (#IssueNumber)`。

---

## 7. 落地顺序（推荐）

1. 合入 `ci.yml` / `cd.yml`，让 CI 在一次 PR 上**真跑一次**；
2. 确认 status check 名就是 **`build-and-test`**；
3. 回到 Rulesets：加上该 check、把 **Enforcement 设为 Active**、目标加 **main**、bypass 留空；
4. （可选）对 `develop` 重复一套同样的保护。

> 顺序理由：先跑一次 CI，Rulesets 里就能从列表**直接选** `build-and-test`，避免手输拼错。

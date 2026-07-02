# Flyway 数据库迁移操作规范

> 适用：psa-backend 全体开发。**自 B1（#477）引入 Flyway 起，baseline 之后所有建表 / 改表 / 数据结构变更必须走本规范。**
> 配套：[数据表分类标准](数据表分类标准.md)（物理命名/前缀）· [B1 设计](../domain/02_项目核算域_accounting/expense/travel/2026-06-22-B1-Flyway接入与费用域首批迁移-设计.md)（方言对照/接入细节）· CLAUDE.md §2.1（DDL 红线）。

---

## 0. 一句话原则

**库结构的唯一真相源是 `db/migration/` 下的版本化脚本；任何绕开 Flyway 的手动改库都会造成环境漂移，禁止。**

---

## 1. 为什么（先理解再遵守）

- Flyway 把"建表改表"从"谁都能随手 SQL"变成"版本化、可复现、可审计、CI 守门"的迁移。
- 现有 yudao 存量表已被 **baseline 冻结为起点**，Flyway **不追溯纳管**它们；本规范只约束 **baseline 之后的新变更**。
- 库是 **SQL Server**（local/dev/prod 一致）。dev 与 prod 结构一致 → dev 部署验证即等于 prod 安全。

---

## 2. 命名规范（硬性）

```
V{yyyyMMddHHmmss}__{snake_case_描述}.sql
```

| 部分 | 规则 | 示例 |
|---|---|---|
| 前缀 | 大写 `V`（versioned 迁移；本项目**不用** repeatable `R` 脚本）| `V` |
| 版本号 | **14 位时间戳** `yyyyMMddHHmmss`（写脚本的时刻，全局唯一、天然防多人撞号 / 防乱序）| `20260622143000` |
| 分隔 | **双下划线** `__` | `__` |
| 描述 | 小写 snake_case，动宾短语，表达"这个迁移干了啥"，**不写中文 / 空格** | `add_travel_application_index` |
| 后缀 | `.sql` | |

完整示例：
```
V20260622143000__create_travel_audit_tables.sql
V20260623091500__add_invoice_verify_status_column.sql
V20260624160000__create_index_platform_order_consume_time.sql
```

**禁止**：`V1.0.0__`、`V1__`、序号递增版本号（多人并行必撞）、中文文件名、大写描述、空格。

---

## 3. 脚本落点（域自持）

- 迁移脚本放**对应业务域所在模块**的 `src/main/resources/db/migration/`。
  - 例：差旅/费用域 → `yudao-module-fst/yudao-module-fst-biz/src/main/resources/db/migration/`
- Flyway 配置 `locations: classpath:db/migration`，**自动扫描**该路径（含**递归子目录**）、跨模块经 classpath 汇聚——无需手动登记，脚本丢进去就被扫到。
- **「子目录可归类，但只有一条全局时间线」**：可为整洁把脚本分子目录（如 `db/migration/expense/`、`db/migration/manhour/`），但 Flyway **不看文件夹、只按版本号(时间戳)排成一条全局队列**执行，只有一张 `flyway_schema_history`。即**没有"每个文件夹各自的 1/2/3 序列"**——所有脚本混在一条线上按版本号排（类比：书分章节文件夹，但页码全书连续）。时间戳版本号保证全局唯一、有序、不撞。
- **一个域的表改动放该域的迁移**，不跨域混写；跨域不应有 FK 硬约束（用 ID + 快照引用）。
- **⚠️ 多服务共享同一库的约束**：PSA 的 fst / bpm / system / infra **共用同一个库**（dev = `ruoyi-vue-pro-dev`）。每个开了 Flyway 的服务有**自己的迁移脚本 + 自己的 `flyway_schema_history` 表**记"已跑哪些"。**目前仅 fst 开了 Flyway**（其余仍用 yudao `sql/` 种子），无冲突。**将来其他服务也要开 Flyway 时，必须给它配独立历史表**（`spring.flyway.table`，如 `flyway_schema_history_bpm`）——否则多服务共用一张历史表：B 服务启动读到 A 服务的迁移记录、自己却没那些脚本 → Flyway 报"已执行迁移找不到对应脚本" → **启动失败**。各服务只管各自的表（fst 管 `psa_*`、bpm 管 `bpm_*`，不重叠）。此为项目级决策，由 Tech Lead 江勇超统一定。

---

## 4. 标准操作流程（加表 / 改表都走它）

```
1. 在 develop 切 feature/fix 分支（见 CLAUDE.md §5 / psa-issue-pr）
2. 在本域 db/migration/ 新建 V{时间戳}__描述.sql，写本次 DDL
3. 本地用 Testcontainers SQL Server 集成测试跑通：migrate 成功 + 断言结构正确
   （本地无需装 SQL Server，测试用 docker 自动拉起 mcr.microsoft.com/mssql/server）
4. PR：正文「改动范围」列出 DDL 内容（CLAUDE.md §2.1）
5. CI（pr-gate）在干净 SQL Server 容器上重放全部迁移 → 必须绿
6. 合并 → develop→dev 部署，app 启动自动 migrate（真实库执行）
7. dev 验收通过 → develop→main → prod 部署自动 migrate
```

> **执行时机**：Flyway 挂在 **app 启动**，部署重启即自动应用待执行迁移。开发者**不手动连库执行**脚本。

---

## 5. 铁律与禁忌

| 🚫 禁止 | ✅ 正确做法 | 后果（不遵守会怎样） |
|---|---|---|
| 修改**已合并 / 已执行**的迁移脚本 | 永远**追加新的** `V{时间戳}` 脚本 | pr-gate 不可变性检查 → **CI 红、合并前拦**；万一漏过则 dev/prod 启动 checksum mismatch 失败 |
| 手动 `ALTER` / 直接连库改结构 / 走老 `sql/` 种子加表 | 一律写迁移脚本 | 环境漂移：dev 能跑 prod 炸，未来迁移随机崩 |
| 一个脚本塞多个不相干变更 | 一个迁移一个清晰目的 | 难审、难定位、回滚粒度差 |
| 用序号版本号（`V1__`/`V2__`）| 用时间戳版本号 | 多人并行撞号 / 乱序拒绝执行 |
| 在迁移里写易失败的大数据回填后无补偿 | 结构与数据变更分开；数据修订单独可重试迁移 | 启动期 migrate 失败 → app 起不来 |
| `UPDATE`/`DELETE` 审计表 | 审计表只 `INSERT`（`INSTEAD OF` 触发器拦截）| 触发器 THROW 报错 |

---

## 6. 方言规则（SQL Server only）

- 项目只跑 SQL Server，迁移**只写 SQL Server 方言**，不做多方言分目录。
- 引擎为 **SQL Server 2016（13.0）Standard Edition**：可用 `ISJSON` / `DATETIME2` / `NVARCHAR(MAX)`；**禁用 2017+ 语法（`STRING_AGG` / `TRIM` 等）与 Enterprise-only 特性**（分区 / 压缩 / 在线索引重建）。CI 容器虽是 2017（无 2016 Linux 镜像），已设 `COMPATIBILITY_LEVEL=130` 逼近，但写脚本仍以 2016/Standard 为准。
- 常见对照（完整见 [B1 设计 §5](../domain/02_项目核算域_accounting/expense/travel/2026-06-22-B1-Flyway接入与费用域首批迁移-设计.md)）：
  - 中文列用 **`NVARCHAR(n)`**（非 `VARCHAR`，否则乱码）；大文本/JSON 用 **`NVARCHAR(MAX)`**。
  - 布尔 **`BIT`**；时间 **`DATETIME2`**；金额 `DECIMAL(18,2)`。
  - 索引用表后独立 `CREATE [UNIQUE] INDEX`（无 MySQL 内联 `KEY`）。
  - 主键 `BIGINT NOT NULL`（app 雪花 ID，**不用** `IDENTITY`）。
  - 物理表名/前缀（`psa_` / `audit_` 等）遵循[数据表分类标准](数据表分类标准.md)。

### 6.1 Flyway 依赖版本约束（被 SQL Server 2016 钉死）

**Flyway 版本必须锁 `7.15.0`（覆盖 Spring Boot 2.7 默认的 8.5.13），不可随手升级。**

- **为什么**：Flyway **Community** 自 **V8（2021 Q3）起不再支持 SQL Server 2016**——V8 官方公告把 2016 连同 MySQL 5.7 / Postgres 9.x 等一并移入**付费的 Teams** 版。dev/prod 库正是 **SQL Server 2016**。用 8.x Community 启动时 `FlywayMigrationInitializer` 抛 `FlywayEditionUpgradeRequiredException` → Spring 上下文起不来 → **进程直接死**（infra/bpm 未接 Flyway 不受影响，仅 fst 挂）。**这不是可忽略的 warning，是硬异常、无开关可跳过**（license 强制闸）。
- **怎么锁**：`yudao-module-fst-biz/pom.xml` 给 `flyway-core` 显式 `<version>7.15.0</version>`；**不引 `flyway-sqlserver`**（那是 Flyway 8+ 才拆出的方言模块，7.x 的 SQL Server 支持在 `flyway-core` 内）。7.15.0 是最后一个 7.x、方法面最全，与 SB 2.7 的 `FlywayAutoConfiguration` 兼容风险最小（SB 3.0 已知与 7.15 不兼容；2.7 经 H2 autoconfig 兼容测试 `FlywayAutoConfigCompatTest` 验证装配无 `NoSuchMethodError`）。
- **升级红线**：任何想升 Flyway 的改动，**先查目标版本对 SQL Server 2016 Community 的支持矩阵**；2016 退役前不得升到 V8+。升级时才需考虑的三条出路：① 留在 7.x；② 买 Teams；③ 升 prod DB 到 2019+（业务决策，非工程随意定）。
- **本地验证边界**：Testcontainers 只能起 **2017**（微软无 2016 Linux 镜像），**edition 闸只在真 2016 上触发、本地 2017 验不出**。降级 / 升级 Flyway 的最终确认**必须在 dev（真 2016）部署观察启动日志**。本约束即来自 dev 环境验证的发现：8.5.13 在本地 2017 容器验证通过，但 dev 真实 SQL Server 2016 启动时才触发 edition 闸——**"本地 2017 绿"不等于"prod 2016 行"，凡涉 DB 版本敏感的依赖，本地验证只是必要非充分，须以 dev 真机为准。**

---

## 7. baseline 说明

- 引入 Flyway 时以**当时的库结构为 baseline（V0）**：Flyway 首次运行只建 `flyway_schema_history` + 写 V0 标记，**不碰任何存量表**。
- 存量 yudao 表**不补历史迁移脚本**、保持原样；只有 baseline 之后的新变更才有 `V{时间戳}` 脚本。
- 故 `db/migration/` 里看到的第一个脚本不是"从零建整个库"，而是"V0 之后的第一笔改动"。

---

## 8. 守门（CI / pr-gate）

**两道独立的闸，各管各的——别混为一谈**：

1. **Testcontainers 洁净库重放**：起 SQL Server 容器、空库从零 migrate 全部脚本 → 验"**方言对、能从零建成、本批内顺序对**"。
   ⚠️ 它每次起**空库、无历史 checksum 基线** → **抓不到对已合并脚本的篡改**（改了也照新内容重跑一遍、依然绿）。
2. **迁移卫生检查**（`scripts/ci/migration-hygiene.sh`，纯 git diff、不依赖 docker）：
   - **不可变性**：`db/migration` 下**已存在文件被改/删 → FAIL**。这才是"改已执行脚本被拦下"的真正落地，挡在**合并前**。
   - **单调性**：**新增迁移版本号 ≤ base 已有最大版本 → FAIL**。防交叉合并 out-of-order 部署失败。

- 真正的 Flyway `checksum mismatch` 只在 **dev/prod 启动时**（那里有历史基线）才爆——那已是合并之后、挡晚了。所以"防篡改"靠 **②的不可变性检查在 PR 阶段拦**，**不是**靠洁净重放。
- 单调性要**彻底关窗**还需分支保护开 **"require branches up to date before merging"**（Tech Lead 仓库设置）；否则后合并的 PR 不 rebase 仍有窗口。

> **⚠️ 写集成测试的硬约定（`*IT` 必须带 tag）**：父 pom 的 surefire 已把 `**/*IT.java` 纳入 include（否则 `migration-it` job 用 `-Dgroups=migration-it` 选不中、0-tests 假绿）。代价是——**任何 `*IT` 类若不带 `@Tag("migration-it")`，会在默认单测阶段执行**（本地 `mvn test` + pr-gate 默认 backend job）。**凡需 docker / Testcontainers 的集成测试，类名带 `IT` 后缀的同时必须打 `@Tag("migration-it")`**，否则会把 SQL Server 容器拖进默认流程（拖慢、且 self-hosted 默认 runner 无 docker 会直接失败）。

---

## 9. 回滚策略

- 社区版 Flyway **无自动 undo**。**不写 down 脚本**。
- 出错统一**前滚修复**：写一个新的补偿迁移（如 `V{时间戳}__fix_xxx.sql`）纠正，而非回退。
- 因此更要靠 Phase 化 + Testcontainers + dev 先行，把错误挡在 prod 前。

---

## 10. 常见场景速查

| 场景 | 怎么做 |
|---|---|
| 新增一张表 | 新 `V{ts}__create_xxx.sql`，`CREATE TABLE` + 独立 `CREATE INDEX` |
| 加一列 | 新 `V{ts}__add_xxx_column.sql`，`ALTER TABLE ... ADD ...`（可空或带 DEFAULT，避免锁表/失败）|
| 加索引 | 新 `V{ts}__create_index_xxx.sql` |
| 改列类型/约束 | 新 `V{ts}__alter_xxx.sql`；注意存量数据兼容 |
| 数据订正 | 新 `V{ts}__backfill_xxx.sql`，**幂等可重试**，与结构变更分开 |
| 发现已合并脚本写错了 | **不要改它**；写新迁移纠正 |

---

## 11. FAQ / 踩坑

- **checksum mismatch 报错？** 说明有人改了已执行脚本。正常情况 pr-gate 的**不可变性检查**会在合并前就拦红；若是历史遗留漂移，正确做法是还原该脚本 + 另写新迁移纠正；`flyway repair` 只在确知无误时由负责人执行，不要随手 repair。
- **两人同一天建迁移会撞吗？** 时间戳精确到秒，基本不**撞号**。但要小心**交叉合并的 out-of-order**：浩之写 `V…090000`、富之写 `V…100000`，若富之的 PR **先合并部署**（dev 已应用 100000），浩之的 PR 后合并时带来一个**版本号更小**的 pending 迁移 → `out-of-order=false` 下 dev 启动 **migrate 失败**。时间戳只保证"写序"，不保证"合并序"。守门：pr-gate **单调性检查**会让后合并者的 PR 变红 → rebase 后重取更大时间戳即可（配合分支保护"合并前 require up-to-date"彻底关窗）。
- **本地没装 SQL Server 能验证吗？** 能。Testcontainers 用 docker 自动拉起 SQL Server，无需手装。
- **能临时手动在 dev 库改个表救急吗？** 不能——会和 Flyway 历史脱节造成漂移。救急也走 hotfix 迁移脚本流程。
- **CI 用的 SQL Server 和 prod 一样吗？** 不完全：prod 是 **2016 Windows Standard**，CI/Testcontainers 是 **2017 Linux 容器**（微软无 2016 Linux 镜像）+ 设 `COMPATIBILITY_LEVEL=130` 逼近。最终真 2016 校验在 dev 部署（dev 同为 2016）。写 DDL 限 2016/Standard 特性即可。

---

*Flyway 迁移操作规范 v1.1 / 2026-06-23 / 随 B1(#477) 引入；v1.1 补 §6.1 版本约束（dev 验证发现 8.5.13 不支持 SQL Server 2016，降 7.15.0；#491）· 重大调整需 Tech Lead 江勇超确认*

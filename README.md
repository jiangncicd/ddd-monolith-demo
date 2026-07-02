# ddd-monolith-demo

单体架构下的 **DDD 领域分包** 示例：把小傅哥 `xfg-frame-ddd` 的**多 Maven module** 压成
**一个 module / 一个 jar**，模块边界降级为**顶层包**，领域分包思想完整保留，并包含
`application`（case）编排层与 ArchUnit 架构守卫。

- 技术栈：JDK 8 + Spring Boot 2.7.18 + Spring JDBC + 内嵌 H2（**开箱即跑，无需装 MySQL**）
- 一条 `POST /api/order/place` 打通：`trigger → application → domain ← infrastructure`

---

## 一、运行

> 本机默认 `java` 是 JDK 8，但 Homebrew 的 `mvn` 跑在高版本 JDK 上。
> 用 JDK 8 驱动 Maven（Spring Boot 2.7.x 官方支持 JDK 8）：

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home

# 跑测试（2 个业务用例 + 5 个架构守卫）
mvn -B test

# 启动（8080 被占用时换端口）
mvn spring-boot:run
# mvn spring-boot:run -Dspring-boot.run.arguments="--server.port=8899"
```

调用（成功 / 规则拒绝两种）：

```bash
# Alice(U0001, 25岁) 下单成功，总额 398.00
curl -s -X POST http://localhost:8080/api/order/place -H 'Content-Type: application/json' \
  -d '{"userId":"U0001","items":[{"productName":"键盘","quantity":1,"price":199.00},{"productName":"鼠标","quantity":2,"price":99.50}]}'
# => {"code":"0000",...,"data":{"success":true,"orderId":"ORD...","totalAmount":398.00,...}}

# Bob(U0002, 16岁) 被规则领域拒绝
curl -s -X POST http://localhost:8080/api/order/place -H 'Content-Type: application/json' \
  -d '{"userId":"U0002","items":[{"productName":"显示器","quantity":1,"price":1299.00}]}'
# => {"code":"0000",...,"data":{"success":false,"message":"年龄未满 18 岁，不允许下单"}}
```

H2 控制台：`http://localhost:8080/h2-console`（JDBC URL `jdbc:h2:mem:ddddemo`，用户 `sa`，空密码）。

---

## 二、多模块 → 单模块的映射

| 原多模块 | 本项目中的包 | 职责 |
|---|---|---|
| `xfg-frame-app` | 根包 + `config/` `aop/` | 启动入口、全局配置与切面 |
| `xfg-frame-types` | `types/` | 通用 `Response` / `Constants` |
| `xfg-frame-api` | （已删）| 纯单体无对外 RPC，DTO 收进 `trigger/http/dto` |
| `xfg-frame-trigger` | `trigger/` | 适配器：`http`（可扩展 rpc/mq/task）|
| `xfg-frame-case` | `application/` | **用例编排层**（`case` 是 Java 关键字，包名用 `application`）|
| `xfg-frame-domain` | `domain/` | **核心**：按领域分包 |
| `xfg-frame-infrastructure` | `infrastructure/` | `dao` + `po` + 仓储实现 |

---

## 三、包结构

```
com.example.app
├── Application.java                     启动入口
├── config/  ThreadPoolConfig            全局配置（@ConfigurationProperties）
├── aop/     AccessLogAop                trigger 层耗时切面
├── types/   Response, Constants, AppException   通用类型，被各层引用
│
├── trigger/                             触发器/适配器（http/rpc/mq/task 四件套，均只做协议转换）
│   ├── http/  OrderController + dto/PlaceOrderRequest + GlobalExceptionHandler(@RestControllerAdvice)
│   ├── rpc/   IOrderRpcService + OrderRpcService        (Dubbo 风格，复用用例)
│   ├── mq/    OrderPlaceConsumer + OrderPlaceMessage    (消息驱动，复用用例)
│   └── task/  OrderStatTask                             (@Scheduled，走查询用例读数)
│
├── application/                         ★ 用例编排层（原 case）
│   └── order/  OrderPlaceCase / IOrderPlaceUseCase      (命令用例)
│               OrderStatQuery / IOrderStatQuery         (查询用例，CQRS 味道)
│               PlaceOrderCommand, OrderResult, assembler/OrderAssembler
│
├── domain/                              ★ 核心：按业务领域分包
│   ├── order/   （充血 · 含聚合）
│   │   ├── model/aggregate/ OrderAggregate
│   │   ├── model/entity/    OrderItemEntity
│   │   ├── model/valobj/    Money, OrderStatus
│   │   ├── repository/      IOrderRepository        (只放接口)
│   │   └── service/         OrderService
│   ├── rule/    model/entity/{DecisionMatter,EngineResult} + model/valobj/RiskLevel
│   │            adapter/IRiskPort   (外部风控"端口")  + service/RuleService
│   └── user/    model/valobj/UserVO + repository/IUserRepository + service/UserService
│
└── infrastructure/                      仓储 & 外部适配器实现（依赖倒置落地）
    ├── dao/         UserDao, OrderDao   (JdbcTemplate)
    ├── po/          UserPO, OrderPO, OrderItemPO   (PO 只在本层)
    ├── repository/  UserRepository, OrderRepository   (implements domain 仓储接口)
    └── adapter/     RiskHttpAdapter (implements IRiskPort, 用 RestTemplate 调外部) + dto/
```

---

## 四、关键设计点

1. **依赖方向**：`trigger → application → domain ← infrastructure`。
   领域层只定义 `IXxxRepository` 接口，实现放 infrastructure —— **依赖倒置**，PO/DAO 被挡在 infra，
   领域模型保持纯粹。
2. **领域分包**：一个领域一个包，包内固定 `model(aggregate/entity/valobj) + repository + service`；
   一个领域模型 = 一个充血结构。
3. **application（case）层职责**：只做**跨领域编排** + **事务边界**（`@Transactional`），
   不写业务规则（规则在 `RuleService`、算钱在 `OrderAggregate`）。
4. **架构守卫**：单模块没有 Maven 的物理隔离，用 `ArchitectureTest`（ArchUnit）把依赖方向变成
   **会失败的测试**，防止 `domain` 反向依赖 `infrastructure`/`application`/`trigger`。
5. **全局异常处理**：`GlobalExceptionHandler`（`@RestControllerAdvice`）把 `AppException`（业务，HTTP 200）、
   参数异常（HTTP 400）、未知异常（HTTP 500）统一翻译成 `Response` 信封，让 `Constants.ResponseCode` 真正用起来。

---

## 五、调用外部接口放哪一层？

**实现放 `infrastructure`，接口（端口）放 `domain`——和仓储 `Repository` 一模一样的依赖倒置。**

- `domain/rule/adapter/IRiskPort`：端口，用领域语言表达（返回值对象 `RiskLevel`），不含 HTTP/SDK。
- `infrastructure/adapter/RiskHttpAdapter`：适配器，用 `RestTemplate` 真发 HTTP，并把外部
  `RiskRespDTO` **防腐翻译**成领域 `RiskLevel`。外部 DTO/技术细节锁死在本层。
- `domain/rule/service/RuleService` 只依赖 `IRiskPort` 接口。

> 区分方向：`trigger` = 别人触发我（inbound）；`infrastructure` = 我去连别人（outbound，DB + 外部接口都算）。
> 因此 ArchUnit 依旧全绿：`infrastructure → domain` 允许，`domain → infrastructure` 被禁，而端口在
> domain、实现在 infra，方向正好对。

配置 `risk.service.url` 即启用（见 `application.yml`）；留空则 `RiskHttpAdapter` **降级放行**（返回 LOW），
所以默认开箱即跑。测试见 `RiskHttpAdapterTest`（MockRestServiceServer 单测适配器）与
`RiskRejectOrderTest`（端到端：风控 HIGH → 拒单）。

---

## 六、换成真数据库 / MyBatis

- 改 `application.yml` 的 `spring.datasource` 指向 MySQL；
- `infrastructure/dao` 的 `JdbcTemplate` 换成 MyBatis `Mapper` + XML（`resources/mybatis/**`）；
- **领域层、application 层、trigger 层完全不用动** —— 这正是分层与依赖倒置的价值。
# ddd-monolith-demo

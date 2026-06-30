# 《React + Gin + PostgreSQL SaaS 平台开发规范》

## 使用说明

本规范面向未来可维护 5 到 10 年的企业级多租户 SaaS 平台，覆盖 CRM、ERP、Workflow、AI、开放平台、API 与插件体系。文档目标不是列举技术，而是建立一套可执行、可审计、可演进的工程标准。所有规范默认适用于 Monorepo 模式，前端采用 React 19 + TypeScript，后端采用 Go 1.24+ + Gin，数据库采用 PostgreSQL 17，缓存与异步体系采用 Redis + Asynq，对象存储采用 MinIO/S3 兼容接口。

本文中的关键字含义如下：

- `MUST`：必须遵守，违反需在架构评审中说明。
- `SHOULD`：强烈建议，除非有明确收益与替代方案。
- `MAY`：可选，适用于特定业务或阶段。

## 目录

1. 项目概述
2. 系统总体架构
3. Monorepo 规范
4. React 开发规范
5. Go 开发规范
6. 数据库设计规范
7. 多租户设计
8. 权限系统
9. 用户体系
10. REST API 规范
11. Redis 规范
12. 文件管理
13. 异步任务
14. AI 模块
15. 审计日志
16. Design System
17. 页面规范
18. Docker 规范
19. Kubernetes 规划
20. CI/CD
21. 日志监控
22. Git 规范
23. 测试规范
24. 安全规范
25. 性能优化
26. 开发规范
27. SaaS 最佳实践
28. 项目路线图

---

## 第一章 项目概述

### 项目目标

本平台的核心目标不是“把多个模块放在同一套系统里”，而是建立一个可长期经营的企业级数字化底座。平台必须支持多租户、组织架构、角色权限、业务流程、开放接口、插件扩展、AI 能力接入与数据审计，并且能够在业务规模、研发团队规模与部署规模扩大时保持结构稳定。架构层面要求“核心收敛、边界清晰、扩展友好、部署渐进、成本可控”。产品层面要求“标准能力平台化、租户差异配置化、复杂流程编排化、外部连接接口化、领域数据资产化”。

对于 5 到 10 年生命周期的平台，最重要的不是追求当下最潮的技术，而是降低中长期熵增。也就是说，系统设计必须优先考虑以下问题：如何让新人在两周内理解项目主结构；如何在三年后仍然能定位权限问题与数据污染问题；如何在五年后迁移部分模块到服务化架构而不重写核心模型；如何在十倍业务增长后仍能通过缓存、分库分表、消息队列或服务拆分继续扩容。

### 架构原则

#### 原则一：业务优先于技术炫技

技术选型必须服务于业务交付与可维护性。对于大多数企业级 SaaS，模块化单体往往比过早微服务更具性价比。统一仓库、统一构建、统一权限、统一模型、统一日志与统一发布流程，能显著降低早期复杂度与组织摩擦。

#### 原则二：边界先于功能

任何新功能在编码前必须先回答三个问题：它属于哪个领域上下文；它依赖哪些上游能力；它能否被其他模块复用。先定边界，再落实现，能够避免“流程写在页面里、权限散在接口里、规则埋在 SQL 里”的失控状态。

#### 原则三：约定优于自由

大型 SaaS 平台的失败往往不是因为做不到，而是因为每个团队都“有自己的写法”。因此，目录结构、命名风格、API 约定、错误码、日志字段、缓存 Key、事件命名、数据库约束，都必须形成强约定。自由只允许出现在有明确收益的扩展点。

#### 原则四：默认面向多租户与审计

所有核心业务表、缓存键、查询接口、导出任务、搜索索引，都默认带租户意识。所有影响业务状态、权限、财务、数据导入导出的行为，都默认可追溯。一个无法明确回答“是谁、在什么租户、什么时候、通过什么入口改了什么”的系统，不具备企业级可用性。

### 设计理念

本平台采用“模块化单体 + 分层架构 + DDD 边界 + 平台能力中心化”的组合设计。所谓模块化单体，不是把所有代码混在一起，而是在单进程、单仓库、单部署单元内，通过清晰模块边界与依赖约束构建接近服务化的可演进结构。这样做有四个收益：

1. 保持开发效率高，便于统一测试、发布与调试。
2. 保持跨模块事务与一致性设计简单。
3. 保持基础设施成本低，适合中早期平台。
4. 为未来演进到独立服务保留模块边界。

### 技术选型

#### 为什么选择 React

React 适合复杂 SaaS 前端，原因不在于“流行”，而在于它具备成熟生态与强可组合性。React 19 配合 TypeScript、TanStack Query、React Hook Form、Zod、shadcn/ui、Radix UI，能够构建稳定的表单、表格、权限、路由、异步状态与设计系统能力。对于长期项目而言，生态成熟度比语法新奇更重要。

推荐结论：

- 页面编排使用 React Router v7。
- 服务端状态使用 TanStack Query。
- 表单状态使用 React Hook Form + Zod。
- UI 基座使用 TailwindCSS 4 + shadcn/ui + Radix UI。
- 图表使用 ECharts，图标统一使用 Iconify。

反例：在大型管理后台中大量依赖“全局状态库装一切”，或者将接口请求逻辑写在组件渲染路径中，会导致视图与数据耦合、缓存失效逻辑混乱、测试困难。

#### 为什么选择 Gin

Gin 不是最“重”的框架，也不是最“新”的框架，但它非常适合企业级 API 中台：路由清晰、性能稳定、生态成熟、对中间件与标准库兼容性高。配合自定义分层结构、Validator、Zap、OpenAPI、sqlc，可以在不引入过重框架抽象的前提下建立工程纪律。

我们选择 Gin 的关键原因是可控性。对于 SaaS 平台，真正重要的不是框架帮你隐藏了多少，而是工程团队能否清楚理解请求生命周期、错误传播、上下文传递、认证鉴权、事务边界与日志链路。Gin 的抽象层级刚好适中。

#### 为什么选择 PostgreSQL

PostgreSQL 17 是企业级 SaaS 的优选数据库之一。其优势包括：

- 事务能力强，适合复杂业务一致性。
- 类型系统丰富，支持 `UUID`、`JSONB`、`ARRAY`、全文搜索、物化视图。
- 扩展能力强，适合未来引入 `pgvector`、逻辑复制、分区表。
- 生态成熟，适合审计、分析、报表与数据平台演进。

相较于将结构化与半结构化数据拆到多个数据库，PostgreSQL 能在较长时间内保持统一能力中心，降低运维与一致性复杂度。

#### 为什么选择 TailwindCSS 4

TailwindCSS 4 对 Design Token、主题定制、原子类组合与组件一致性非常友好，适合 Design System 驱动的中后台产品。它真正的价值不是“写类名快”，而是让样式决策回到系统层面：颜色、间距、半径、阴影、动效、暗黑模式都可以被平台化与工具化。

#### 为什么选择模块化单体

早期微服务常见问题是：业务边界还没稳定，组织就先被服务数量拖垮。模块化单体的目标是先建立清晰模块，再决定是否拆分部署。只要模块边界、接口契约、事件语义、数据归属先做好，将来拆分就会更自然；如果这些基础没有做好，微服务只会放大问题。

### 未来演进路线

平台技术演进建议分为三个阶段：

```mermaid
flowchart LR
    A[阶段1 模块化单体] --> B[阶段2 能力中心化]
    B --> C[阶段3 局部服务化]
    C --> D[阶段4 平台生态化]
```

- 阶段 1：统一仓库、统一鉴权、统一数据库、统一日志与监控。
- 阶段 2：沉淀组织、权限、审计、流程、消息、文件、AI 为平台基础能力。
- 阶段 3：对计算密集型或组织边界明确模块进行独立部署，如 AI、报表、Webhook、导入导出。
- 阶段 4：开放平台、插件市场、第三方集成与租户级配置生态。

### 推荐落地模板

```ts
// frontend feature contract
export interface ModuleCapability {
  code: string;
  routes: string[];
  permissions: string[];
  apis: string[];
  events?: string[];
}

export const crmCapability: ModuleCapability = {
  code: "crm",
  routes: ["/crm/customers", "/crm/opportunities"],
  permissions: ["crm.customer.read", "crm.customer.write"],
  apis: ["/api/v1/crm/customers", "/api/v1/crm/opportunities"],
};
```

```go
// backend module registration contract
type Module interface {
    Name() string
    MountRoutes(rg *gin.RouterGroup)
    RegisterJobs() error
    RegisterSubscribers() error
}
```

### 注意事项

- 不允许在项目初期为了“高级架构”而引入事件风暴式过度拆分。
- 不允许前端页面直接拼接权限语义，权限必须来自统一资源定义。
- 不允许绕过领域服务直接在 Handler 中写复杂业务。
- 不允许在数据库中保留无租户语义的核心业务表。

### 非功能性目标

一个能运行的系统，不等于一个能长期演进的系统。企业级 SaaS 平台必须在项目一开始就定义非功能性目标，否则团队会在功能交付过程中持续做出局部最优、全局失控的决策。推荐在项目立项与架构评审阶段明确以下基线：

- 可用性目标：核心业务 API 年度可用性不低于 `99.9%`。
- 性能目标：管理后台常规列表接口 `P95 < 300ms`，写操作 `P95 < 500ms`。
- 恢复目标：核心数据 `RPO <= 15min`，主要业务 `RTO <= 60min`。
- 安全目标：所有关键资源具备认证、鉴权、审计、限流与敏感信息脱敏。
- 可维护性目标：新成员两周内能独立完成一个标准业务模块。
- 可演进目标：任一平台能力模块可在不重写主数据模型的前提下独立抽离。

这些目标不是写在 PPT 上的承诺，而是必须映射到工程动作中。例如可用性对应高可用部署与健康检查；性能目标对应索引、缓存、慢查询治理；恢复目标对应备份与演练；可维护性目标对应目录规范与脚手架；可演进目标对应边界设计与事件语义。

### 平台成功标准

在企业项目中，“需求上线了”不是唯一成功标准。平台应使用多维度指标判断是否健康：

```mermaid
flowchart TD
    A[平台成功] --> B[业务可交付]
    A --> C[研发可维护]
    A --> D[运维可观测]
    A --> E[安全可审计]
    A --> F[架构可演进]
```

建议将以下问题纳入季度架构复盘：

1. 近三个月是否出现跨模块复制实现？
2. 是否有权限逻辑散落到页面、SQL、定时任务中？
3. 是否存在新增模块无法套用既有模板的情况？
4. 是否存在上线依赖个人经验而非自动化流程的问题？
5. 是否存在数据库、缓存、对象存储中租户语义不一致的问题？

### 架构决策记录机制

大型平台的长期失败，很多时候不是因为做错了某个技术选择，而是团队在一年后忘记了当初为什么这么选。因此推荐建立 ADR（Architecture Decision Record）机制。所有重大技术决策都应记录：

- 背景与问题
- 可选方案
- 最终决定
- 为什么不选其他方案
- 对后续系统的影响
- 何时需要重新评估

建议需要 ADR 的场景包括：

- 是否引入微服务
- 是否采用 `sqlc` 还是 `GORM`
- 是否引入 `pgvector`
- 是否将 AI 模块单独部署
- 是否对某领域采用事件驱动

推荐模板：

```md
### ADR-001 模块化单体作为 V1 默认架构

- Status: Accepted
- Date: 2026-06-30
- Context: 平台处于 0 到 1 阶段，业务边界尚在收敛。
- Decision: 采用模块化单体，要求严格模块边界与统一基础设施。
- Consequences:
  - 优点：交付快、部署简单、事务一致性强。
  - 风险：若边界治理失败，后期拆分成本高。
  - Follow-up：每季度评估 AI、Webhook、报表模块独立部署可行性。
```

### 业务能力分层

推荐将整个平台能力拆分为三层，不同层的演进节奏、稳定性要求与复用目标不同：

```mermaid
flowchart LR
    A[平台底座能力] --> B[领域共享能力]
    B --> C[业务模块能力]
```

- 平台底座能力：身份、租户、权限、审计、文件、消息、配置、监控。
- 领域共享能力：客户选择器、流程审批组件、组织树服务、数据范围解析。
- 业务模块能力：CRM、ERP、Workflow、AI 场景化能力。

治理原则：

1. 平台底座能力必须稳定优先，变更需要架构评审。
2. 领域共享能力必须经过至少两个模块复用后再抽象。
3. 业务模块能力默认只服务本领域，不应过早提升到共享层。

### 推荐项目立项清单

在正式开始编码之前，架构负责人必须组织完成以下清单：

- 确认一级模块列表与模块负责人。
- 确认租户模型、工作区模型、组织模型是否收敛。
- 确认身份体系与第三方登录优先级。
- 确认审计范围与日志保留策略。
- 确认接口规范、错误码规范、响应规范。
- 确认前端 Design Token、组件基座与交互规范。
- 确认数据库命名、迁移、索引、主键方案。
- 确认本地开发、测试环境、预发与生产环境的一致性策略。

### 常见架构误区

#### 误区一：把“可扩展”理解为“预埋所有复杂度”

真正可扩展的系统不是把 MQ、微服务、分布式事务、服务网格全部一次性引入，而是当前结构足够简单，同时未来拆分时边界不被破坏。

#### 误区二：把“配置化”理解为“所有东西都做成 JSON 配置”

配置化适用于可枚举、可验证、可审计、可回滚的变化。复杂规则如果没有模型与校验，只会形成更难维护的“可视化硬编码”。

#### 误区三：把“平台化”理解为“抽一个公共包”

平台化意味着统一语义、统一流程、统一治理与统一生命周期，而不仅是把几个函数放进 `shared` 目录。

### 推荐结论

第一章的最终落地要求可以归纳为一句话：在任何编码开始之前，团队必须先统一“平台的边界、演进方向、工程纪律和非功能目标”，否则后续规范只能沦为文档陈列。

---

## 第二章 系统总体架构

### 系统架构图

```mermaid
flowchart TB
    U[Browser / App] --> FE[React Web]
    FE --> BFF[API Gateway / Gin HTTP Layer]
    BFF --> APP[Application Layer]
    APP --> DOM[Domain Layer]
    APP --> REPO[Repository Layer]
    REPO --> PG[(PostgreSQL)]
    APP --> REDIS[(Redis)]
    APP --> MINIO[(MinIO)]
    APP --> ASYNQ[Asynq Workers]
    APP --> AI[AI Provider Adapter]
    APP --> OAUTH[OAuth/OIDC Connectors]
    APP --> WEBHOOK[Webhook Dispatcher]
```

该架构坚持单向依赖：接口层调用应用层，应用层协调领域层与仓储层，基础设施通过接口适配领域需求。任何横切能力，如日志、链路追踪、认证、鉴权、审计、配置、限流，统一通过中间件或基础设施组件管理，不允许在业务代码里散落重复实现。

### 模块划分

推荐按照“平台基础模块 + 业务域模块 + 集成模块 + 运维支撑模块”划分：

```mermaid
flowchart LR
    A[Platform Core] --> A1[Identity]
    A --> A2[Tenant]
    A --> A3[Permission]
    A --> A4[Audit]
    A --> A5[File]
    A --> A6[Workflow]
    B[Business Domains] --> B1[CRM]
    B --> B2[ERP]
    B --> B3[Project]
    C[Integration] --> C1[OpenAPI]
    C --> C2[Webhook]
    C --> C3[Plugin]
    C --> C4[AI]
```

### 模块职责

- `identity`：用户认证、会话、单点登录、Token 生命周期。
- `tenant`：租户、工作区、组织关系、套餐与容量策略。
- `permission`：RBAC/ABAC、资源定义、数据策略。
- `audit`：登录日志、操作日志、数据变更摘要、审计查询。
- `file`：上传、下载、预签名、缩略图、病毒扫描扩展。
- `workflow`：流程定义、任务节点、审批动作、回调事件。
- `openapi`：第三方应用、凭证、签名、配额与回调。
- `plugin`：扩展点、插件注册、配置生命周期。
- `ai`：模型接入、Prompt 管理、用量统计与知识检索。

### DDD 边界

领域边界的核心不是“有没有聚合根”这个形式问题，而是业务一致性是否在同一生命周期内。推荐的上下文边界如下：

- 身份上下文：用户、认证凭证、外部身份映射。
- 租户上下文：租户、工作区、订阅、配额。
- 组织上下文：组织、部门、岗位、成员关系。
- 权限上下文：角色、策略、授权、资源。
- CRM 上下文：客户、联系人、商机、跟进记录。
- Workflow 上下文：流程模板、节点实例、审批记录。
- AI 上下文：模型配置、Prompt 模板、对话会话、Embedding 索引。

### 上下文划分规则

1. 一个实体只能有一个主归属上下文。
2. 跨上下文访问必须经过应用层协调，不能直接引用对方内部表结构。
3. 数据冗余必须明确为“投影”或“快照”，并记录来源与刷新策略。
4. 事件名称必须表达业务事实，而不是技术动作。

### 模块通信

模块内优先使用函数调用与事务边界；模块间优先使用应用服务编排；跨边界异步通知使用领域事件或任务队列。不要为了“解耦”而对所有调用都上消息队列，消息的引入必须有明确收益：削峰、重试、解耦耗时任务、跨部署单元。

```mermaid
sequenceDiagram
    participant UI as React UI
    participant API as Gin Handler
    participant APP as Application Service
    participant DOM as Domain Service
    participant DB as PostgreSQL
    participant JOB as Asynq

    UI->>API: 提交创建客户请求
    API->>APP: CreateCustomer(command)
    APP->>DOM: 校验租户、配额、唯一性
    DOM->>DB: 持久化客户
    DB-->>DOM: 返回客户ID
    APP->>JOB: 投递客户欢迎任务
    APP-->>API: 返回标准响应
    API-->>UI: 201 Created
```

### 依赖方向

依赖方向必须严格控制为：

`Controller -> Application -> Domain -> Repository Interface`

`Infrastructure` 仅实现下层接口，不被上层业务细节反向依赖。绝不允许 `domain` 依赖 `gin`、`gorm`、`redis client`、`zap logger` 等具体实现。

### 分层架构

#### Controller

负责 HTTP 协议适配、参数绑定、认证上下文解析、响应格式统一。禁止承载业务规则、数据库事务、资源权限决策。

#### Application

负责用例编排、事务控制、跨领域协调、权限调用、审计埋点、事件发布。Application 是系统行为的入口，不是简单的 Service 薄封装。

#### Domain

负责核心业务规则、一致性约束、实体行为、领域服务与领域事件。Domain 要保持稳定、纯净、与框架解耦。

#### Repository

负责持久化抽象与查询语义，不负责拼接业务流程。查询仓储与命令仓储可以拆分，复杂报表查询允许独立 Query Service。

#### Infrastructure

负责数据库、缓存、对象存储、消息、三方 SDK、邮件、短信、AI Provider、Webhook Client 等适配实现。

### 推荐目录内依赖规则

```go
// 正例：应用服务依赖仓储接口与领域服务
type CreateOrderService struct {
    txManager     TxManager
    orderRepo     domain.OrderRepository
    policyChecker domain.PolicyChecker
}
```

```go
// 反例：Handler 直接操作数据库并混合权限与业务
func CreateOrder(c *gin.Context) {
    // bad: 直接查 DB、直接写审计、直接写缓存、直接判权限
}
```

### 上下文映射方法

当业务模块持续增长时，仅靠“模块名列表”无法保证边界长期清晰。建议为每个上下文建立最小映射卡片，至少包含：

- 上下文名称
- 核心实体
- 输入命令
- 输出事件
- 依赖上游
- 被谁消费
- 数据归属

示例：

```md
### Context: CRM

- Core Entities: Customer, Contact, Opportunity
- Commands: CreateCustomer, AssignOwner, ArchiveCustomer
- Events: CustomerCreated, CustomerAssigned, CustomerArchived
- Upstream Dependencies: Tenant, Identity, Permission
- Downstream Consumers: Workflow, Audit, OpenAPI
- Data Ownership: crm schema
```

这样做的价值在于：任何新需求来时，先判断它是扩展既有上下文，还是新建上下文，而不是直接往现有模块里塞。

### 模块依赖判定规则

为了避免模块间关系逐渐演化为网状依赖，建议使用如下判定规则：

1. 若依赖只为了读对方少量信息，优先读取投影或只读查询接口。
2. 若依赖需要使用对方业务规则，必须通过应用服务协调。
3. 若依赖意味着共享事务边界，说明上下文切分可能过细。
4. 若两个模块频繁双向调用，优先重审边界而非继续加适配层。

### 模块所有权与团队协作

系统总体架构不仅是代码结构，也是组织结构。建议每个一级模块明确：

- 业务负责人
- 技术负责人
- 代码 Owner
- 数据 Owner
- 变更评审人

模块所有权不明确时，常见后果包括：数据库表被多个团队随意改、接口契约无人维护、灰度发布缺少责任人、线上问题排查时没人能完整解释模块行为。

### 横切能力治理

横切能力必须平台化，不允许每个模块重复造轮子。以下能力只能有统一入口：

- 日志
- 错误处理
- 鉴权
- Trace
- 审计
- 配置
- 缓存 Key 构造
- 任务投递

推荐统一能力接入图：

```mermaid
flowchart TB
    A[HTTP Request] --> B[Middleware Chain]
    B --> C[Application Service]
    C --> D[Platform Services]
    D --> E[Audit]
    D --> F[Logger]
    D --> G[Tracer]
    D --> H[Cache]
```

### 查询模型与命令模型分离

在复杂 SaaS 系统中，列表、报表、看板常常需要与事务模型不同的查询结构。推荐在架构层承认这一现实：

- 命令模型：服务一致性、规则执行与写入。
- 查询模型：服务高效读取、聚合视图与导出。

这不必然意味着完整 CQRS，但至少应避免把所有复杂查询塞进实体仓储中，造成领域模型被查询细节污染。

### 推荐模块验收清单

任何新增模块在合入主干前，至少要通过以下检查：

- 是否声明了模块边界与职责。
- 是否确定了资源权限与审计动作。
- 是否定义了错误码范围。
- 是否明确了租户字段与数据归属。
- 是否声明了 API 路由前缀与命名空间。
- 是否具备基础监控指标与日志字段。

### 常见反例补充

- 在 `domain` 层直接引入 Redis 客户端处理缓存失效。
- 在 `repository` 中做权限判断和审计写入。
- 为了复用而把所有跨模块逻辑放到 `common` 包。
- 用“公共工具函数”绕开应用服务边界。

---

## 第三章 Monorepo 规范

### 目录结构

推荐采用前后端一体 Monorepo，统一依赖治理、脚本入口、代码规范与发布流水线。

```tree
sass/
├─ apps/
│  ├─ admin-web/
│  ├─ portal-web/
│  └─ docs-site/
├─ server/
│  ├─ cmd/
│  ├─ internal/
│  ├─ migrations/
│  ├─ openapi/
│  └─ tests/
├─ packages/
│  ├─ ui/
│  ├─ tokens/
│  ├─ eslint-config/
│  ├─ tsconfig/
│  ├─ api-sdk/
│  ├─ shared-types/
│  └─ utils/
├─ scripts/
├─ deploy/
│  ├─ docker/
│  ├─ compose/
│  ├─ k8s/
│  └─ helm/
├─ docs/
├─ .github/
├─ package.json
├─ pnpm-workspace.yaml
└─ Makefile
```

### 每个目录职责

#### `apps`

承载最终可部署前端应用。每个应用必须具备独立路由、布局、业务模块与运行配置。应用层不应重复实现基础组件、基础 hooks 或通用类型。

#### `server`

承载 Go 服务端。推荐所有后端代码统一放在 `server` 下，避免根目录分散。`server/cmd` 存放入口，`server/internal` 存放业务实现，`server/migrations` 存放数据库迁移，`server/openapi` 存放接口定义与生成产物。

#### `packages`

承载可复用包。必须满足“跨应用复用”这一条件才能进入 `packages`。禁止把只服务单个页面的工具函数抽到共享包，避免伪抽象。

#### `scripts`

承载可自动化脚本，包括本地初始化、代码生成、校验、构建、版本号更新、发布辅助脚本。脚本必须幂等、可重复执行、失败即退出。

#### `deploy`

承载容器与部署资源。开发环境 Compose、生产 Dockerfile、Kubernetes 清单、Helm Chart 必须统一管理，避免散落到应用子目录。

### 命名规范

- 目录名使用 `kebab-case`，如 `admin-web`、`shared-types`。
- Go 包名使用短小小写单词，不使用下划线。
- React 组件文件使用 `PascalCase.tsx`。
- Hook 文件使用 `useXxx.ts`。
- 测试文件使用 `*.test.ts`、`*_test.go`。
- 生成代码统一放在 `generated/` 或明确的 `gen/` 目录。

### Monorepo 工程约束

1. 跨包依赖必须显式声明，不允许隐式引用源码路径。
2. 共享包必须有 `README`、导出边界与版本策略。
3. UI 包不得依赖业务包，业务包可依赖 UI 包暴露的基础组件。
4. API SDK 必须由 OpenAPI 生成或通过统一客户端封装导出。

### 推荐脚本入口

```json
{
  "scripts": {
    "dev": "pnpm -r --parallel dev",
    "build": "pnpm -r build",
    "lint": "pnpm -r lint",
    "test": "pnpm -r test",
    "typecheck": "pnpm -r typecheck",
    "generate": "pnpm -r generate"
  }
}
```

### 反例

- 在 `apps/admin-web` 中直接引用 `server/openapi` 的原始文件。
- 把“租户切换逻辑”放进 `packages/ui`。
- 不同应用维护不同 ESLint、Prettier、TSConfig 配置。
- 脚本依赖开发者本机私有路径或手工步骤。

### 包分层建议

Monorepo 中最容易失控的不是目录多，而是依赖方向失控。建议前端包与应用之间形成以下层级：

```mermaid
flowchart LR
    A[apps/*] --> B[packages/api-sdk]
    A --> C[packages/ui]
    A --> D[packages/shared-types]
    C --> E[packages/tokens]
    A --> F[packages/utils]
```

约束规则：

1. `packages/ui` 只能依赖 `tokens`、基础工具与无业务语义类型。
2. `packages/api-sdk` 只负责客户端契约，不依赖 UI。
3. `shared-types` 仅承载跨端共享结构，不承载行为逻辑。
4. `utils` 不得演化为“什么都往里放”的垃圾目录。

### 工作区治理

推荐使用 `pnpm workspace` 管理依赖，并配套以下规则：

- 所有包必须显式声明 `name`。
- 所有内部依赖统一使用 workspace 协议。
- 不允许不同应用持有相同依赖的多个大版本。
- 根目录维护统一 Node、pnpm、TypeScript 基线版本。

示例：

```yaml
packages:
  - apps/*
  - packages/*
```

```json
{
  "dependencies": {
    "@sass/ui": "workspace:*",
    "@sass/shared-types": "workspace:*"
  }
}
```

### 代码生成规范

Monorepo 中所有生成代码都必须具备以下特征：

- 来源可追溯
- 可以重复生成
- 禁止手工编辑
- 有清晰落点目录

适合生成的内容包括：

- OpenAPI SDK
- Zod Schema
- 图标索引
- 路由清单
- 数据库访问层类型定义

不适合生成的内容包括：

- 频繁需要人工微调的业务组件
- 高度场景化页面逻辑
- 复杂领域服务

### 根目录文件职责

推荐明确定义根目录关键文件职责：

- `package.json`：统一脚本入口与基础元信息。
- `pnpm-workspace.yaml`：声明工作区范围。
- `Makefile`：跨语言统一命令别名。
- `.editorconfig`：跨编辑器统一基础格式。
- `.nvmrc` 或 `.node-version`：锁定 Node 基线。
- `.github/workflows/*`：CI/CD 自动化定义。

### 分支与环境脚本治理

脚本应避免“环境越多，脚本越乱”。推荐统一为能力型脚本，而不是环境型脚本：

- `dev`
- `build`
- `test`
- `lint`
- `generate`
- `deploy`

如果确需环境区分，使用参数或环境变量驱动，而不是复制出多个几乎相同的脚本。

### 推荐目录扩展示例

```tree
packages/
├─ ui/
│  ├─ src/
│  ├─ stories/
│  └─ package.json
├─ api-sdk/
│  ├─ src/generated/
│  ├─ src/client/
│  └─ package.json
├─ shared-types/
│  ├─ src/
│  └─ package.json
└─ tokens/
   ├─ src/
   ├─ style-dictionary/
   └─ package.json
```

### Monorepo 反模式补充

- 为了“共享”而将业务页面复制到 `packages`。
- 一个包没有公开边界，应用可以任意深层导入内部实现。
- 构建速度变慢后通过“先不检查”绕过 lint、typecheck。
- 将仅服务单个租户的定制逻辑直接放入共享包。

---

## 第四章 React 开发规范

### 目录规范

推荐按“应用壳层、模块域、共享层”组织前端代码。

```tree
apps/admin-web/src/
├─ app/
│  ├─ router/
│  ├─ providers/
│  ├─ layouts/
│  └─ bootstrap/
├─ modules/
│  ├─ crm/
│  │  ├─ pages/
│  │  ├─ components/
│  │  ├─ hooks/
│  │  ├─ api/
│  │  ├─ schemas/
│  │  └─ permissions/
│  └─ iam/
├─ shared/
│  ├─ components/
│  ├─ hooks/
│  ├─ lib/
│  ├─ query/
│  ├─ auth/
│  └─ i18n/
├─ styles/
└─ main.tsx
```

### 组件规范

组件必须遵循“表现与行为分离、输入输出稳定、可测试、可组合”的原则。企业级后台的核心问题不是组件多，而是组件语义混乱。必须区分：

- 基础组件：按钮、输入框、卡片、弹窗等。
- 领域组件：客户选择器、租户切换器、角色授权矩阵。
- 页面组件：列表页、详情页、编辑页骨架。
- 组合组件：PageHeader、SearchBar、DataTableToolbar。

#### 组件设计规则

1. 一个组件只解决一个层级的问题。
2. 基础组件不引入业务概念，如不出现 `CustomerButton` 这种命名。
3. props 命名要表达业务语义，不使用含糊缩写。
4. 组件默认支持加载、空态、错误、禁用态。

```tsx
type AsyncButtonProps = {
  loading?: boolean;
  disabled?: boolean;
  onClick?: () => Promise<void> | void;
  children: React.ReactNode;
};

export function AsyncButton({
  loading,
  disabled,
  onClick,
  children,
}: AsyncButtonProps) {
  return (
    <button
      className="inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-medium"
      disabled={loading || disabled}
      onClick={() => void onClick?.()}
    >
      {loading ? "处理中..." : children}
    </button>
  );
}
```

### Hooks 规范

Hooks 按职责拆分为：

- 状态 Hooks：本地交互状态。
- 数据 Hooks：接口查询与变更。
- 领域 Hooks：封装复杂业务流程。
- 环境 Hooks：主题、国际化、权限、媒体查询。

禁止在 Hook 中直接操作 DOM 之外的全局状态副作用而不暴露清晰接口。Hook 名称必须以 `use` 开头，并以能力命名，如 `useCustomerListQuery`、`useTenantSwitcher`。

### Context 规范

Context 只用于低频变更、跨层共享且具备全局语义的状态，例如：

- 当前租户
- 当前用户摘要
- 国际化语言
- 主题模式
- 权限快照

不要将高频变更列表数据放入 Context。对于服务端状态使用 Query，对于复杂本地业务状态使用 Zustand 或页面级 reducer。

### TanStack Query 规范

服务端状态必须统一使用 Query 管理，禁止在组件中使用 `useEffect + useState` 手工维护请求生命周期。Query Key 必须结构化，并包含租户信息、资源名、查询条件。

```ts
export const customerKeys = {
  all: (tenantId: string) => ["tenant", tenantId, "crm", "customers"] as const,
  list: (tenantId: string, params: Record<string, unknown>) =>
    [...customerKeys.all(tenantId), "list", params] as const,
  detail: (tenantId: string, id: string) =>
    [...customerKeys.all(tenantId), "detail", id] as const,
};
```

```ts
export function useCustomerListQuery(params: CustomerListQuery) {
  const tenantId = useTenantId();
  return useQuery({
    queryKey: customerKeys.list(tenantId, params),
    queryFn: () => customerApi.list({ tenantId, ...params }),
    staleTime: 30_000,
    gcTime: 5 * 60_000,
  });
}
```

### API 管理

所有 API 访问必须通过统一客户端层封装，包括：

- 基础 URL
- 认证头
- 多租户头
- 幂等请求头
- 错误处理
- 响应解包
- Trace ID 透传

反例：在页面组件中直接写 `fetch("/api/...")`，既不利于统一错误处理，也不利于测试与重构。

### 状态管理

#### Zustand

Zustand 仅用于以下场景：

- 页面级复杂草稿状态
- 布局状态，如侧边栏展开
- 向导流程状态
- 与 Query 不同生命周期的临时业务状态

禁止把接口缓存、表单状态、权限矩阵全部塞进 Zustand。

```ts
type CustomerFilterState = {
  keyword: string;
  setKeyword: (keyword: string) => void;
};

export const useCustomerFilterStore = create<CustomerFilterState>((set) => ({
  keyword: "",
  setKeyword: (keyword) => set({ keyword }),
}));
```

### 权限控制

前端权限只负责用户体验控制，不负责最终安全裁决。前端可控制菜单、按钮、字段可见性、页面路由访问，但后端必须重复校验。

```tsx
export function Can({
  permission,
  children,
}: {
  permission: string;
  children: React.ReactNode;
}) {
  const hasPermission = useHasPermission(permission);
  return hasPermission ? <>{children}</> : null;
}
```

### 国际化

国际化必须采用“语义 Key + 模块命名空间”结构，不允许直接将中文写死在业务逻辑判断里。

```ts
export const messages = {
  "crm.customer.list.title": "客户列表",
  "crm.customer.create.success": "客户创建成功",
};
```

### 暗黑模式

暗黑模式必须通过 Design Token 驱动，不允许组件内部硬编码明暗颜色。主题切换应仅改变变量映射，不改变组件结构。

### Design Token

Token 分为：

- 全局 Token：颜色、字号、半径、阴影、间距。
- 语义 Token：成功、警告、危险、边框、背景、前景。
- 组件 Token：按钮高度、输入框边框、对话框阴影。

### TailwindCSS 4 / shadcn/ui / Radix

三者职责如下：

- TailwindCSS 4：样式表达与 Token 消费层。
- shadcn/ui：可复制可定制的组件基座。
- Radix：无障碍与交互原语。

### 组件封装原则

1. 先组合，再抽象。
2. 先解决一致性，再追求泛化。
3. 不为单一场景设计“万能组件”。
4. 所有封装必须保留原生 HTML 语义与无障碍能力。

### 反例

```tsx
// bad: 页面里混合请求、校验、权限、样式与映射
useEffect(() => {
  fetch("/api/v1/customers").then(...)
}, [])
```

推荐做法是：Schema 校验、API 层、Query Hook、页面容器与展示组件分离。

### 路由规范

React Router v7 在企业级系统中的职责不仅是页面跳转，还包括布局编排、鉴权分流、错误边界与懒加载边界。推荐采用“应用壳层路由 + 模块子路由”结构：

```tsx
export const router = createBrowserRouter([
  {
    path: "/",
    element: <AppLayout />,
    errorElement: <RouteErrorBoundary />,
    children: [
      ...crmRoutes,
      ...iamRoutes,
    ],
  },
  {
    path: "/login",
    element: <LoginPage />,
  },
]);
```

规范要求：

1. 路由定义只声明路径、页面与守卫关系，不写业务逻辑。
2. 模块路由必须按模块导出，不在单个总文件中堆积数百行。
3. 页面级错误必须有路由错误边界承接。
4. 懒加载边界优先放在模块级，而非单个小组件级。

### 页面容器与展示组件分离

推荐每个核心页面至少拆分两层：

- `Page Container`：负责路由参数、权限、查询参数、请求编排。
- `Page View`：负责展示、交互与局部状态。

```tsx
export function CustomerListPage() {
  const params = useCustomerListParams();
  const query = useCustomerListQuery(params);

  return (
    <CustomerListView
      data={query.data?.items ?? []}
      loading={query.isLoading}
      onRefresh={() => void query.refetch()}
    />
  );
}
```

这种拆分的收益是：页面测试、骨架复用、空态统一、导出交互与权限逻辑更容易维护。

### 表单规范

企业级后台最容易出问题的不是复杂图表，而是复杂表单。推荐规则如下：

1. 表单状态统一使用 `React Hook Form`。
2. 输入校验统一使用 `Zod`。
3. 默认值必须通过工厂函数生成，避免页面内散落字面量。
4. 服务端返回字段错误时，要能映射回具体字段。
5. 提交过程必须处理防重复、乐观状态与错误反馈。

```ts
const customerSchema = z.object({
  name: z.string().min(1, "客户名称不能为空").max(200),
  ownerId: z.string().uuid().optional(),
  status: z.enum(["active", "inactive"]),
});

type CustomerFormValues = z.infer<typeof customerSchema>;
```

```tsx
const form = useForm<CustomerFormValues>({
  resolver: zodResolver(customerSchema),
  defaultValues: {
    name: "",
    ownerId: undefined,
    status: "active",
  },
});
```

### DataTable 规范

TanStack Table 适合中后台复杂表格，但必须通过平台封装统一体验。推荐沉淀一个 `DataTable` 组合模式，统一：

- 列定义
- 空态
- 骨架屏
- 排序状态
- 选中状态
- 工具栏插槽
- 行操作插槽

```tsx
type CustomerRow = {
  id: string;
  name: string;
  ownerName: string;
  status: "active" | "inactive";
};

export const customerColumns: ColumnDef<CustomerRow>[] = [
  { accessorKey: "name", header: "客户名称" },
  { accessorKey: "ownerName", header: "负责人" },
  { accessorKey: "status", header: "状态" },
];
```

### Query 与 Mutation 协同规范

Query 与 Mutation 的一致性策略必须统一，否则不同模块会出现完全不同的刷新方式。推荐规则：

- 创建成功后优先失效列表 Query。
- 编辑成功后同时更新详情 Query 与列表 Query。
- 删除成功后执行列表失效或本地乐观移除。
- 高风险操作不做乐观更新，先以后端结果为准。

```ts
export function useCreateCustomerMutation() {
  const queryClient = useQueryClient();
  const tenantId = useTenantId();

  return useMutation({
    mutationFn: customerApi.create,
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: customerKeys.all(tenantId),
      });
    },
  });
}
```

### 错误处理规范

前端错误必须按层处理：

- 字段级错误：表单项内展示。
- 页面级错误：PageAlert、EmptyErrorState。
- 路由级错误：ErrorBoundary。
- 全局级错误：Toast、全局异常上报。

不要把所有错误都弹 Toast，更不要将后端原始错误直接显示给用户。

### 无障碍与可用性规范

企业后台也必须具备基础可访问性要求：

- 交互控件具备可聚焦能力。
- Dialog/Drawer 管理焦点。
- 输入控件关联标签与错误描述。
- 表格批量选择支持键盘操作。
- 颜色不是唯一状态表达方式。

### 样式治理规范

使用 TailwindCSS 4 时，推荐遵循以下顺序：

1. 优先使用设计系统组件。
2. 其次使用语义化封装组件。
3. 最后才在页面内写少量原子类。

禁止页面中出现大段重复类串；若某段类名重复出现 3 次以上，应考虑提炼为组件或样式变体。

### React 代码组织建议

```tree
modules/crm/customers/
├─ api/
│  ├─ customer.api.ts
│  └─ customer.keys.ts
├─ components/
│  ├─ CustomerForm.tsx
│  ├─ CustomerTable.tsx
│  └─ CustomerStatusBadge.tsx
├─ hooks/
│  ├─ useCustomerListQuery.ts
│  ├─ useCreateCustomerMutation.ts
│  └─ useCustomerFilters.ts
├─ pages/
│  ├─ CustomerListPage.tsx
│  └─ CustomerDetailPage.tsx
├─ schemas/
│  └─ customer.schema.ts
└─ types/
   └─ customer.types.ts
```

### React 反模式补充

- 一个页面文件同时包含路由、请求、表单、表格列定义和权限判断。
- Hook 既请求数据又直接改 DOM 或发全局广播。
- 把后端 DTO 直接当组件 Props 到处透传。
- 为了图省事在 `Context` 中存放高频列表数据。

---

## 第五章 Go 开发规范

### Gin 项目结构

```tree
server/
├─ cmd/
│  └─ api/
│     └─ main.go
├─ internal/
│  ├─ bootstrap/
│  ├─ config/
│  ├─ middleware/
│  ├─ modules/
│  │  ├─ iam/
│  │  ├─ tenant/
│  │  ├─ crm/
│  │  └─ workflow/
│  ├─ pkg/
│  └─ platform/
├─ migrations/
├─ openapi/
└─ tests/
```

### 目录说明

- `cmd`：程序入口，仅做启动装配。
- `bootstrap`：初始化配置、日志、数据库、缓存、HTTP 服务。
- `middleware`：认证、鉴权、日志、追踪、限流、恢复等中间件。
- `modules`：领域模块。
- `platform`：跨模块平台能力，如审计、文件、异步任务、AI 适配。
- `pkg`：少量可跨模块复用且不含业务语义的工具包。

### Middleware

中间件必须保持横切关注点特性，不得将核心业务写入中间件。推荐中间件链顺序：

1. `Recovery`
2. `RequestID`
3. `Tracing`
4. `AccessLog`
5. `Cors`
6. `TenantResolver`
7. `Auth`
8. `PermissionGuard`
9. `RateLimit`

### Handler

Handler 负责协议层适配：

- 绑定请求参数
- 调用应用服务
- 将领域错误映射为 HTTP 错误
- 输出统一响应结构

```go
func (h *CustomerHandler) Create(c *gin.Context) {
    var req CreateCustomerRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Fail(c, errs.InvalidArgument.WithCause(err))
        return
    }

    result, err := h.app.Create(c.Request.Context(), req.ToCommand())
    if err != nil {
        response.FromError(c, err)
        return
    }

    response.Created(c, result)
}
```

### Service

本规范中 `Service` 默认指 `Application Service` 或 `Domain Service`。应用服务负责编排，领域服务负责规则。名称必须体现意图，如 `CreateCustomerService`、`AssignRoleService`，避免泛化成 `CommonService`。

### Repository

优先使用 `sqlc` 生成查询代码，复杂动态查询可结合 Query Builder。只有在强依赖对象图操作或遗留系统兼容场景下才考虑 `GORM`，且不得在核心领域中滥用自动关联。

### DTO / VO / Entity / Model / Mapper

- DTO：接口层输入输出对象。
- VO：稳定返回视图对象。
- Entity：领域实体，带业务行为。
- Model：数据库模型或查询映射对象。
- Mapper：负责 DTO/Entity/Model 转换。

推荐保持这些对象边界清晰，避免一个结构体走天下。

### Response

响应必须统一结构：

```json
{
  "code": "OK",
  "message": "success",
  "data": {},
  "meta": {
    "requestId": "req_xxx"
  }
}
```

### Error

错误必须具备：

- 稳定错误码
- 面向前端或调用方的消息
- 面向日志的详细原因
- 可追踪上下文

```go
type AppError struct {
    Code      string
    Message   string
    Cause     error
    Extra     map[string]any
    HTTPStatus int
}
```

### Logger

统一使用 `Zap`，并强制输出结构化字段：

- `request_id`
- `trace_id`
- `tenant_id`
- `user_id`
- `module`
- `action`
- `latency_ms`

### Context

禁止滥用 `context.WithValue` 传递大量业务对象。仅允许放置与请求链相关的小型上下文，例如请求 ID、租户 ID、用户 ID、追踪信息。

### Validation

所有外部输入必须校验。原则是：

- 协议层校验格式与必填。
- 应用层校验命令合法性。
- 领域层校验业务一致性。

### Config

统一使用 `Viper` 加载配置，但不得让配置读取散落在业务代码中。业务模块只依赖类型化配置对象。

### 启动流程

```mermaid
flowchart TD
    A[Load Config] --> B[Init Logger]
    B --> C[Init Database]
    C --> D[Init Redis]
    D --> E[Init Storage]
    E --> F[Register Modules]
    F --> G[Build Router]
    G --> H[Start HTTP Server]
    F --> I[Start Asynq Workers]
```

### 生命周期

应用必须支持优雅关闭：停止接收新请求、等待在途请求结束、停止 worker、刷新日志、关闭数据库连接。退出必须可控，不允许靠强杀进程解决一致性问题。

### 模块目录推荐模板

后端模块如果没有统一骨架，三个月后通常就会出现“每个模块一套写法”的问题。推荐每个领域模块采用统一内部结构：

```tree
server/internal/modules/crm/
├─ application/
│  ├─ commands/
│  ├─ queries/
│  └─ services/
├─ domain/
│  ├─ entities/
│  ├─ events/
│  ├─ repositories/
│  ├─ services/
│  └─ valueobjects/
├─ infrastructure/
│  ├─ persistence/
│  ├─ query/
│  ├─ external/
│  └─ cache/
├─ interfaces/
│  └─ http/
│     ├─ dto/
│     ├─ handlers/
│     └─ routes/
└─ module.go
```

约束原则：

1. `interfaces` 只处理协议适配，不得包含业务状态机。
2. `application` 只编排用例，不持久化框架细节。
3. `domain` 不依赖具体数据库与 Web 框架。
4. `infrastructure` 仅实现接口，不反向定义领域规则。

### Application Service 设计规范

Application Service 是后端工程质量的分水岭。很多项目所谓“Service 层失控”，本质上是没有区分编排与规则。应用服务必须承担以下职责：

- 开启和提交事务。
- 调用领域服务或实体行为。
- 组装外部依赖，如仓储、审计、任务。
- 发布领域事件或任务。
- 保证跨模块调用顺序。

不应承担的职责：

- 解析 HTTP 参数。
- 拼接 SQL。
- 直接操作缓存客户端细节。
- 编写与领域无关的字符串处理逻辑。

```go
type CreateCustomerAppService struct {
    tx        TxManager
    repo      domain.CustomerRepository
    checker   domain.CustomerPolicyChecker
    audit     platform.AuditService
    publisher platform.EventPublisher
}

func (s *CreateCustomerAppService) Execute(ctx context.Context, cmd CreateCustomerCommand) (*CustomerVO, error) {
    var result *domain.Customer

    err := s.tx.WithTx(ctx, func(txCtx context.Context) error {
        if err := s.checker.CanCreate(txCtx, cmd.OperatorID, cmd.TenantID); err != nil {
            return err
        }

        customer, err := domain.NewCustomer(cmd.TenantID, cmd.Name, cmd.OwnerID)
        if err != nil {
            return err
        }

        if err := s.repo.Create(txCtx, customer); err != nil {
            return err
        }

        result = customer
        return nil
    })
    if err != nil {
        return nil, err
    }

    _ = s.audit.Log(ctx, "crm", "customer.create", result.ID())
    _ = s.publisher.Publish(ctx, domain.CustomerCreatedEvent{CustomerID: result.ID()})
    return ToCustomerVO(result), nil
}
```

### 领域实体与值对象规范

若领域实体只是一个数据库结构体，那么领域层就形同虚设。实体必须封装关键业务行为，值对象必须封装不可变语义。推荐标准：

- 实体负责生命周期与状态变化。
- 值对象负责合法性与等价性。
- 不变量在构造时建立，在行为变更时持续维护。

```go
type CustomerStatus string

const (
    CustomerStatusActive   CustomerStatus = "active"
    CustomerStatusArchived CustomerStatus = "archived"
)

type Customer struct {
    id       string
    tenantID string
    name     string
    status   CustomerStatus
}

func NewCustomer(tenantID, name, ownerID string) (*Customer, error) {
    if strings.TrimSpace(name) == "" {
        return nil, errs.InvalidArgument.WithMessage("customer name is required")
    }
    return &Customer{
        id:       uuid.Must(uuid.NewV7()).String(),
        tenantID: tenantID,
        name:     name,
        status:   CustomerStatusActive,
    }, nil
}

func (c *Customer) Archive() error {
    if c.status == CustomerStatusArchived {
        return errs.InvalidState.WithMessage("customer already archived")
    }
    c.status = CustomerStatusArchived
    return nil
}
```

### Repository 设计边界

仓储的职责是用领域语言表达持久化能力，而不是承载任意查询拼装。推荐将仓储分成两类：

- 命令仓储：面向写入、一致性与聚合加载。
- 查询仓储：面向列表、搜索、报表与投影视图。

示例接口：

```go
type CustomerRepository interface {
    Create(ctx context.Context, customer *Customer) error
    GetByID(ctx context.Context, tenantID, customerID string) (*Customer, error)
    ExistsByName(ctx context.Context, tenantID, name string) (bool, error)
}

type CustomerQueryRepository interface {
    List(ctx context.Context, tenantID string, filter CustomerListFilter) ([]CustomerListItem, error)
}
```

### 事务管理规范

事务必须由应用服务显式管理，不允许仓储在内部偷偷开启事务，这会导致跨仓储一致性无法保障。推荐规范如下：

1. 每个命令型用例只能有一个主事务入口。
2. 事务内禁止调用外部 HTTP、发邮件、调 AI。
3. 若事务后需要执行异步动作，采用 outbox 或提交后发布。
4. 事务函数必须可回滚、可重试、可推导。

```go
type TxManager interface {
    WithTx(ctx context.Context, fn func(txCtx context.Context) error) error
}
```

### 中间件实施细则

中间件不止有顺序，还必须有统一行为边界：

- `Recovery`：捕获 panic，记录结构化异常，不泄露栈给客户端。
- `RequestID`：生成请求唯一 ID，并注入响应头。
- `Tracing`：创建 span，透传 trace 信息。
- `AccessLog`：记录接口访问与耗时。
- `TenantResolver`：从认证结果与头信息中解析可信租户。
- `Auth`：解析 token 或 session。
- `PermissionGuard`：按路由资源编码执行粗粒度鉴权。
- `RateLimit`：按用户、租户、IP 或应用限流。

### 错误码分层策略

错误码必须能反映系统层次，而不是一串无意义数字。建议采用稳定字符串编码：

- `COMMON_INVALID_ARGUMENT`
- `AUTH_UNAUTHORIZED`
- `AUTH_TOKEN_EXPIRED`
- `TENANT_NOT_FOUND`
- `TENANT_MEMBERSHIP_REQUIRED`
- `PERMISSION_DENIED`
- `CRM_CUSTOMER_DUPLICATED`
- `WORKFLOW_INSTANCE_CLOSED`

优点是日志检索、前端匹配、文档展示和 OpenAPI 描述更清晰。

### Handler 编写清单

每个 Handler 在提交前必须检查：

- 是否只做参数绑定与响应转换。
- 是否避免直接调用仓储。
- 是否没有写业务分支。
- 是否正确透传 `context.Context`。
- 是否把领域错误映射为统一响应。
- 是否记录必要审计入口。

### 配置治理规范

配置必须具备层级、默认值、类型安全与环境隔离。推荐做法：

- 入口统一加载配置并校验。
- 配置结构体按模块拆分。
- 敏感配置通过环境变量或 Secret 注入。
- 业务代码只依赖显式配置对象。

```go
type Config struct {
    HTTP struct {
        Port         int           `mapstructure:"port"`
        ReadTimeout  time.Duration `mapstructure:"read_timeout"`
        WriteTimeout time.Duration `mapstructure:"write_timeout"`
    } `mapstructure:"http"`
    Database struct {
        DSN string `mapstructure:"dsn"`
    } `mapstructure:"database"`
}
```

### 启动装配原则

启动过程应遵循“先基础设施，后平台能力，再业务模块，最后服务监听”的顺序。推荐：

1. 加载并校验配置。
2. 初始化 logger、metrics、trace。
3. 初始化 PostgreSQL、Redis、存储、任务系统。
4. 初始化平台服务，如身份、权限、审计。
5. 注册业务模块。
6. 组装 HTTP Router。
7. 启动 API 与 Worker。

### Go 反模式补充

- 在 `handler` 中使用匿名结构体承载复杂业务输入，导致类型无法复用。
- 为了省事把数据库模型直接当返回对象。
- 用 `map[string]any` 传递领域命令。
- 为了“灵活”在应用层到处传 `interface{}`。

### 反例

- `handler -> repository` 直接调用。
- 把数据库事务包在 Gin 中间件里。
- 使用 `panic` 作为常规错误流程。
- 在 `init()` 中偷偷初始化数据库或配置。

---

## 第六章 数据库设计规范

### PostgreSQL 设计原则

数据库设计首先服务于“正确性、可理解性、可审计性”，其次才是灵活性。表结构必须能回答三个问题：数据归谁所有、如何保证唯一性、如何追踪变化来源。对企业 SaaS 而言，推荐一开始就构建清晰命名、统一主键、时间字段、租户字段、状态字段与审计字段。

### Schema 规范

推荐使用逻辑 Schema 划分而非按团队乱建：

- `platform`：租户、用户、权限、审计、文件等平台表
- `crm`：客户、联系人、商机等
- `workflow`：流程定义、任务实例、审批日志
- `ai`：模型配置、对话、知识库、向量索引元数据
- `integration`：应用、密钥、Webhook、回调日志

### 命名规范

- 表名使用复数或统一约定的业务集合名，如 `users`、`tenant_members`。
- 主键统一为 `id`。
- 外键统一使用 `<entity>_id`。
- 时间字段统一为 `created_at`、`updated_at`、`deleted_at`。
- 操作人字段统一为 `created_by`、`updated_by`。

### UUID

核心业务表主键统一使用 `UUID v7` 或兼容的时间有序 UUID。原因是：

- 便于分布式生成。
- 避免自增 ID 暴露业务规模。
- 更利于未来服务拆分与数据合并。

### JSONB / Array

`JSONB` 适合存储半结构化扩展配置、快照与第三方原始回包，但不应替代核心关系建模。`ARRAY` 适合固定维度标签或轻量集合，不适合高频复杂过滤的业务关系。

### Index / GIN / 全文搜索 / 物化视图

- BTree：默认索引。
- GIN：用于 `JSONB`、全文检索、数组包含。
- Trigram：用于模糊搜索。
- Materialized View：用于复杂报表或成本高昂的聚合查询。

### Migration

迁移必须版本化、可回滚、可审查，不允许手工改线上表结构。每个 migration 必须包含：

- 变更目的
- 向前迁移
- 向后回滚（如可行）
- 数据迁移说明
- 风险说明

### sqlc

推荐把 `sqlc` 作为主查询层，原因是类型安全、贴近 SQL、性能可控、便于 code review。

```sql
-- name: ListCustomers :many
SELECT id, tenant_id, name, status, owner_id, created_at
FROM crm.customers
WHERE tenant_id = sqlc.arg(tenant_id)
  AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT sqlc.arg(limit)
OFFSET sqlc.arg(offset);
```

```go
customers, err := q.ListCustomers(ctx, db.ListCustomersParams{
    TenantID: tenantID,
    Limit:    int32(limit),
    Offset:   int32(offset),
})
```

### 事务规范

1. 一个应用服务一个显式事务边界。
2. 事务内只做必要数据库操作，不调用外部网络服务。
3. 事务提交成功后再发异步任务或领域事件。
4. 长事务必须拆分，避免锁扩大。

### SQL 规范

- 明确列名，禁止 `SELECT *`。
- 写入前先设计唯一约束，禁止完全依赖应用层防重。
- 列表查询必须考虑索引命中与分页稳定性。
- 逻辑删除表的唯一索引要考虑 `deleted_at`。

### 推荐基础审计字段

```sql
CREATE TABLE crm.customers (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    name VARCHAR(200) NOT NULL,
    status VARCHAR(32) NOT NULL,
    owner_id UUID,
    extra JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    updated_by UUID
);
```

### 推荐 ER 图

```mermaid
erDiagram
    TENANTS ||--o{ USERS : owns
    TENANTS ||--o{ WORKSPACES : contains
    WORKSPACES ||--o{ DEPARTMENTS : has
    USERS ||--o{ USER_ROLES : assigned
    ROLES ||--o{ USER_ROLES : grants
    TENANTS ||--o{ CUSTOMERS : owns
    USERS ||--o{ CUSTOMERS : manages
```

### 数据库对象边界

数据库设计必须坚持“表归属明确、跨表关系受控、约束优先于约定”。建议每张表在设计时都明确：

- 所属模块
- 业务主语
- 写入来源
- 读取场景
- 是否参与审计
- 是否逻辑删除
- 是否参与归档

若这些问题回答不清，说明表设计很可能还不成熟。

### 时间字段与时区规范

所有时间必须统一使用 `TIMESTAMPTZ`，服务端统一以 UTC 存储，展示层按租户或用户时区格式化。禁止：

- 一部分表使用本地时间，一部分表使用 UTC。
- 把字符串时间直接存数据库。
- 让数据库默认时区依赖服务器所在地区。

### 逻辑删除规范

核心业务表优先采用逻辑删除，但必须配套以下规则：

1. 所有默认查询必须显式排除 `deleted_at IS NOT NULL`。
2. 唯一索引设计必须考虑逻辑删除后的重建问题。
3. 被逻辑删除的数据是否允许恢复必须有明确规则。
4. 涉及审计、财务、流程的表禁止直接物理删除。

推荐唯一索引写法：

```sql
CREATE UNIQUE INDEX uq_customers_tenant_name_active
ON crm.customers (tenant_id, lower(name))
WHERE deleted_at IS NULL;
```

### 分页设计规范

数据库层必须配合接口层分页语义。对于后台通用列表，可使用页码分页；对于大表、高并发或时间序列场景，应使用游标分页。建议：

- 页码分页仅用于可控数据量管理列表。
- 深分页不要使用大偏移量 `OFFSET`。
- 游标字段必须稳定、可排序、具备索引。

```sql
-- 推荐：基于 created_at + id 的稳定游标
SELECT id, tenant_id, name, created_at
FROM crm.customers
WHERE tenant_id = $1
  AND deleted_at IS NULL
  AND (created_at, id) < ($2, $3)
ORDER BY created_at DESC, id DESC
LIMIT $4;
```

### JSONB 使用边界

`JSONB` 很有用，但必须克制。推荐使用场景：

- 扩展配置
- 外部系统原始回包
- 审计差异摘要
- AI 原始元信息

不推荐使用场景：

- 核心筛选字段
- 高频排序字段
- 核心关系建模
- 需要强约束的一致性字段

### 索引评审清单

每新增一个索引，都必须回答：

1. 它服务哪个查询？
2. 这个查询有多少频率？
3. 是否已有复合索引能覆盖？
4. 对写入性能影响如何？
5. 是否应该使用部分索引、表达式索引或 GIN？

### 迁移实施规范

数据库迁移不仅是 DDL 文件，还包含发布顺序。推荐采用“三阶段变更法”：

1. 向前兼容：先加新列、新索引、新表，不影响旧逻辑。
2. 灰度切换：应用层同时兼容旧新结构。
3. 清理收口：确认稳定后移除旧字段或旧逻辑。

对于大表结构变更，必须评估：

- 是否锁表
- 是否需要分批回填
- 是否需要异步脚本
- 是否可在低峰执行

### 读写分离与分析负载

V1 阶段通常不建议为了“高级架构”过早引入复杂读写分离，但需要预留演进位。原则是：

- 在线事务优先走主库或强一致读路径。
- 报表、导出、全文搜索可逐步迁移到只读副本或物化视图。
- 不允许将分析型重查询直接压在核心写库高峰时段运行。

### 数据归档策略

企业 SaaS 平台的数据量问题往往不是瞬间爆炸，而是三年后历史数据拖慢所有查询。因此需要尽早定义归档策略：

- 审计日志按月分区。
- 导入导出任务结果保留 30 到 90 天。
- 已归档业务数据与活跃数据查询路径区分。
- 冷数据统计不影响主业务库事务性能。

### SQL 评审反模式补充

- 以“先上线再加索引”为默认做法。
- SQL 条件里缺少 `tenant_id`。
- 在仓储层根据前端传入字符串直接拼排序字段。
- 通过 `SELECT *` 偷懒，导致列增加后传输成本失控。

### 反例

- 业务主表无唯一约束，仅靠接口层判断重复。
- 在 `JSONB` 里塞完整业务实体导致无法索引。
- 用随机脚本手工执行线上 DDL。
- 直接依赖数据库级联删除处理复杂审计关系。

---

## 第七章 多租户设计

### 基本概念

多租户是本平台最核心的结构前提。所有业务设计必须先回答“租户级别、工作区级别还是组织级别”。推荐统一模型：

- `Tenant`：计费与资源隔离单位。
- `Workspace`：租户下业务协作空间。
- `Organization`：组织树根节点。
- `Department`：组织子单元。
- `Role`：角色定义。
- `Permission`：原子权限。
- `Policy`：数据访问策略。

### 关系模型

```mermaid
erDiagram
    TENANT ||--o{ WORKSPACE : contains
    TENANT ||--o{ ORGANIZATION : owns
    ORGANIZATION ||--o{ DEPARTMENT : includes
    TENANT ||--o{ ROLE : defines
    ROLE ||--o{ ROLE_PERMISSION : grants
    USER ||--o{ TENANT_MEMBER : joins
    TENANT ||--o{ TENANT_MEMBER : has
    TENANT_MEMBER ||--o{ MEMBER_ROLE : assigned
```

### 数据隔离策略

推荐默认采用“共享库共享表 + 强租户列隔离”模式，配合以下约束：

1. 所有核心业务表必须包含 `tenant_id`。
2. 仓储查询必须显式带 `tenant_id` 条件。
3. 缓存 Key 必须带租户前缀。
4. 对象存储路径必须带租户命名空间。
5. 审计日志必须记录租户。

当未来单租户体量超大时，可渐进演进到：

- 共享库独立 Schema
- 独立数据库
- 独立计算实例

### Workspace 设计

`Workspace` 是用户在同一租户内切换业务上下文的主要单位。它适合承载：

- 项目空间
- 业务线空间
- 地区分区
- 事业部空间

但 `Workspace` 不是权限系统本身，不应替代角色与策略。

### 数据权限

企业 SaaS 的真正复杂点不在菜单，而在数据范围。数据权限建议采用“角色授予 + 策略覆盖”的双层模型：

- 角色决定你能做什么。
- 策略决定你能看到哪些数据。

例如：销售总监与销售代表都具备 `crm.customer.read`，但前者可看部门全部客户，后者只能看自己负责客户。

```mermaid
flowchart TD
    A[User Request] --> B[Resolve Tenant]
    B --> C[Resolve Roles]
    C --> D[Resolve Policies]
    D --> E[Build Data Scope]
    E --> F[Append SQL Conditions]
```

### 多租户上下文传播

前端必须在请求头或路由上下文中带出租户与工作区，后端必须在认证后重建可信上下文，不得直接信任前端传入所有值。

```go
type TenantContext struct {
    TenantID    string
    WorkspaceID string
    UserID      string
}
```

### 推荐策略

- 认证系统支持“一个用户可加入多个租户”。
- 同一邮箱可以映射多个租户成员身份。
- 资源配额在租户层控制，业务范围在工作区和组织层控制。
- 租户停用后，数据进入只读冻结期，不立即硬删除。

### 租户生命周期设计

多租户平台的复杂度，很多并不来自运行态，而来自生命周期管理。推荐明确租户状态机：

- `pending`：待初始化
- `active`：正常使用
- `suspended`：欠费或风控暂停
- `readonly`：冻结，只允许导出与审计读取
- `deleted`：逻辑删除，等待最终清理

```mermaid
flowchart LR
    A[pending] --> B[active]
    B --> C[suspended]
    C --> B
    B --> D[readonly]
    D --> E[deleted]
```

任何租户状态切换都必须落审计，并影响认证、写入、导出、Webhook、异步任务行为。

### 成员模型设计

推荐将“用户”和“成员”分离。`User` 表达自然人账号，`TenantMember` 表达其在租户中的身份。这样可以清晰支持：

- 一个用户加入多个租户
- 同一用户在不同租户拥有不同角色
- 邀请制入驻
- 成员冻结但用户账号不冻结

推荐成员关系模型：

```mermaid
erDiagram
    USERS ||--o{ TENANT_MEMBERS : has
    TENANTS ||--o{ TENANT_MEMBERS : contains
    TENANT_MEMBERS ||--o{ MEMBER_WORKSPACES : belongs
    TENANT_MEMBERS ||--o{ MEMBER_ROLES : assigned
```

### 租户配额与套餐

多租户不仅是数据隔离，还包括资源治理。推荐在租户层维护以下配额：

- 用户数上限
- 存储容量
- API 调用额度
- AI Token 额度
- Webhook 订阅数量
- 工作流执行次数

配额检查发生位置建议：

- 创建成员、上传文件、创建应用等同步路径在应用服务内即时检查。
- AI、导出等高成本任务在投递前和执行前双重检查。

### Workspace 与组织的边界

很多平台容易把 `Workspace` 与 `Department` 混用。建议明确：

- `Workspace`：协作上下文，偏业务工作空间。
- `Department`：组织结构，偏管理关系。

一个用户可以属于多个 Workspace，也可以在组织树中只属于一个主要部门。不要用 Workspace 替代组织架构，也不要让部门承担所有业务协作空间含义。

### 租户上下文可信链

多租户请求处理必须建立可信链，而不是盲目信任前端头信息。推荐顺序：

1. 认证系统先识别用户身份。
2. 根据用户查询其租户成员关系。
3. 校验请求中的 `tenant_id` 是否属于该用户。
4. 校验 `workspace_id` 是否在该租户内且用户有访问权。
5. 构建服务端可信 `TenantContext`。

```mermaid
sequenceDiagram
    participant FE as Frontend
    participant MW as Tenant Resolver
    participant IAM as IAM Service
    participant APP as App Service

    FE->>MW: Request + token + tenant_id
    MW->>IAM: verify user and membership
    IAM-->>MW: member profile + workspace access
    MW->>APP: inject trusted tenant context
```

### 数据隔离实施检查项

每个业务模块上线前，必须逐项确认：

- 表结构是否包含 `tenant_id`
- 仓储查询是否包含 `tenant_id`
- 缓存键是否包含 `tenant_id`
- 对象路径是否包含 `tenant_id`
- 审计日志是否记录 `tenant_id`
- 导入导出任务是否透传 `tenant_id`

### 单租户定制边界

企业 SaaS 会逐渐出现大客户定制诉求。推荐优先级如下：

1. 配置化差异
2. 权限与流程差异
3. 插件扩展差异
4. 最后才考虑代码分支差异

不要轻易接受“为一个租户改一套分支代码”的模式，否则平台会迅速失去统一演进能力。

### 多租户反模式补充

- 后端通过请求头直接信任 `tenant_id`，不校验成员关系。
- 同一张业务表有些查询加租户条件，有些查询忘记加。
- 导出和异步任务没有透传租户上下文，导致串数据。
- 用“超级管理员”账户长期在生产环境跨租户处理日常业务。

### 反例

- 用 `org_id` 替代 `tenant_id`，导致计费与隔离边界混乱。
- 把租户信息只放 JWT，不做服务端校验与成员关系验证。
- 在超级管理员角色中绕过所有租户条件，造成误读全局数据。

---

## 第八章 权限系统

### 权限设计目标

权限系统必须满足四类场景：菜单可见、操作可用、接口可调、数据可见。单纯用 RBAC 无法覆盖复杂企业场景，因此推荐“RBAC 为主、ABAC 为辅、数据策略单列”的混合模式。权限系统的目标不是让配置界面看起来复杂，而是在规则不断增加时仍保持可解释性。

### RBAC

RBAC 适合表达稳定的岗位职责。例如：系统管理员、销售经理、财务专员、审批人。角色与权限的关系建议采用资源化命名：

- `crm.customer.read`
- `crm.customer.write`
- `workflow.instance.approve`
- `platform.user.invite`

### ABAC

ABAC 适合表达属性驱动的细粒度规则，如：

- 仅允许编辑自己创建的数据。
- 仅允许审批与自己部门相关的流程。
- 仅允许工作时间内访问特定敏感接口。

ABAC 不宜泛滥。建议只在 RBAC 不足时引入，并通过清晰策略表达式或规则 DSL 实现。

### 菜单权限

菜单权限应由资源声明驱动，而不是在路由文件里散落 if 判断。推荐每个模块维护自己的菜单资源定义：

```ts
export const crmMenus = [
  {
    key: "crm.customers",
    path: "/crm/customers",
    permission: "crm.customer.read",
    label: "客户管理",
  },
];
```

### 按钮权限

按钮权限必须与后端接口权限资源对齐，禁止出现“前端按钮代码叫 `customer:create`，后端接口写 `crm.write`”这种不一致设计。

### 接口权限

后端接口权限是最终裁决点。接口鉴权流程建议为：

```mermaid
sequenceDiagram
    participant C as Client
    participant M as Auth Middleware
    participant P as Permission Service
    participant H as Handler

    C->>M: HTTP Request + JWT
    M->>P: 解析用户、租户、角色、策略
    P-->>M: 权限结果与数据范围
    M->>H: 注入访问上下文
    H-->>C: 返回结果
```

### 数据权限

数据权限建议预定义以下范围：

- `SELF`
- `DEPARTMENT`
- `DEPARTMENT_AND_CHILDREN`
- `WORKSPACE`
- `TENANT`
- `CUSTOM`

应用层在构造查询条件时统一附加数据范围，不允许每个仓储各写一套逻辑。

```go
type DataScope struct {
    Level         string
    DepartmentIDs []string
    UserIDs       []string
}
```

### 权限缓存

权限解析可以缓存，但缓存的原则是“缓存结果，不缓存最终安全”。建议缓存：

- 用户角色集
- 角色权限集
- 用户数据策略摘要

不建议缓存：

- 高动态临时授权
- 单次审批动作结果
- 需要强一致的封禁状态

### 推荐模型

```mermaid
flowchart LR
    U[User] --> UR[UserRole]
    UR --> R[Role]
    R --> RP[RolePermission]
    RP --> P[Permission]
    U --> POL[Policy]
    POL --> DS[Data Scope]
```

### 最佳实践

1. 权限资源由平台统一注册，禁止手写字符串满天飞。
2. 角色模板与租户自定义角色分离。
3. 权限变更后应支持主动失效缓存。
4. 敏感操作必须同时校验权限与业务状态。

### 权限资源注册中心

权限设计要长期稳定，首先必须解决“资源从哪里来”。推荐建立统一资源注册中心，所有模块在启动时注册自己的权限资源、菜单资源与操作资源。

```go
type PermissionResource struct {
    Code        string
    Module      string
    Name        string
    Description string
    Action      string
}

type PermissionRegistry interface {
    Register(resources ...PermissionResource) error
    ListByModule(module string) []PermissionResource
}
```

示例：

```go
registry.Register(
    PermissionResource{Code: "crm.customer.read", Module: "crm", Name: "查看客户", Action: "read"},
    PermissionResource{Code: "crm.customer.write", Module: "crm", Name: "编辑客户", Action: "write"},
    PermissionResource{Code: "crm.customer.export", Module: "crm", Name: "导出客户", Action: "export"},
)
```

这样做可以确保权限文档、菜单配置、接口守卫、角色授权页面都来自同一语义源。

### 角色模型分层

角色不应只有一张表和一个名字。推荐至少分为三层：

- 平台预设角色模板
- 租户自定义角色
- 成员最终生效角色集

其中：

- 平台模板用于新租户初始化。
- 租户角色用于覆盖本租户个性化授权。
- 生效角色集用于运行时快速解析与缓存。

### 鉴权执行链

后端鉴权建议分两层进行：

1. 路由级粗粒度权限校验。
2. 应用服务级业务动作与数据范围校验。

```mermaid
flowchart TD
    A[HTTP Request] --> B[Auth Middleware]
    B --> C[Route Permission Guard]
    C --> D[Application Service]
    D --> E[Policy Check]
    E --> F[Repository with Data Scope]
```

仅在中间件中做一次鉴权是不够的，因为很多细粒度规则依赖业务上下文，如对象状态、所属部门、创建人、审批节点。

### ABAC 规则表达建议

ABAC 如果没有统一表达方式，很快就会沦为 if/else 地狱。推荐每个策略至少由以下维度组成：

- 主体：谁发起
- 资源：访问什么对象
- 动作：要做什么
- 条件：在什么约束下
- 效果：允许或拒绝

```go
type PolicyRule struct {
    SubjectType string
    Resource    string
    Action      string
    Condition   string
    Effect      string
}
```

条件表达式可以先从受控 DSL 开始，而不是直接允许任意脚本执行。

### 数据权限落地方式

数据权限不应只停留在角色界面。推荐将其沉淀为统一查询附加器：

```go
type ScopeAppender interface {
    AppendCustomerScope(baseSQL string, scope DataScope) (string, []any)
}
```

或者在 Query Builder 中统一附加作用域，而不是每个仓储各自判断。关键目标是“同一类资源的范围规则只实现一遍”。

### 菜单权限与接口权限解耦

菜单权限与接口权限必须相关，但不应直接等同。原因是：

- 一个菜单可能对应多个只读接口。
- 一个按钮可能对应多个校验严格的动作接口。
- 接口有时服务多个前端入口。

因此推荐：

- 菜单资源负责可见性。
- 页面操作资源负责交互可用性。
- 接口资源负责最终执行授权。

三者共享统一资源命名体系，但不强制一一映射为同一条记录。

### 权限缓存失效策略

权限缓存最怕“授权改了但不生效”。建议以下事件触发缓存失效：

- 成员角色变更
- 角色权限变更
- 策略规则变更
- 成员禁用或移出租户
- 工作区访问范围变更

失效范围建议尽可能精确到 `tenant + user`，避免全量广播造成缓存风暴。

### 敏感操作二次校验

以下操作即使前端已经判断可见，也建议后端在执行前再次强化校验：

- 成员删除
- 角色授权变更
- 批量导出
- 敏感字段查看
- 工作流审批通过/驳回
- 开放平台密钥重置

可以附加：

- 二次密码确认
- 短信或邮件确认
- 最近登录验证
- 风险设备校验

### 权限系统测试重点

权限模块必须重点测试以下场景：

- 同一用户多租户切换后权限不串租户
- 角色修改后缓存及时失效
- 前端隐藏按钮但后端仍拒绝直接调用
- 数据权限在列表、详情、导出三条路径保持一致
- 超级管理员能力受租户边界控制

### 权限反模式补充

- 页面里到处硬编码权限字符串。
- 新增接口未登记资源编码就直接上线。
- 数据权限在 SQL 层临时拼条件，没人知道完整规则。
- 权限判断只看角色名，不看资源和动作。

### 反例

- 仅前端控制按钮，不做后端接口校验。
- 一个字符串同时表达菜单、按钮和数据权限。
- 通过“是否管理员”这个布尔值覆盖所有规则。

---

## 第九章 用户体系

### 目标与边界

用户体系不仅包含登录，还包含身份映射、租户成员关系、会话管理、单点登录、邀请入驻、账号冻结、设备与安全风控。必须把“用户账号”与“租户成员身份”拆开。一个用户可以服务多个租户，一个租户成员也可能对应不同工作区角色。

### 登录

推荐支持以下登录方式：

- 账号密码
- 邮箱验证码
- 手机验证码
- OAuth2 / OIDC
- 企业微信
- 飞书
- 钉钉
- GitHub
- Google

### JWT

JWT 适合承载短期访问令牌，但不要把所有授权信息都塞进去。JWT 中建议只放：

- `sub`
- `session_id`
- `tenant_hint`
- `exp`
- `iat`

角色、权限、数据策略建议服务端解析，避免因 token 过大或权限变更不同步造成风险。

### Refresh Token

Refresh Token 必须具备以下特性：

1. 长生命周期但可吊销。
2. 与会话和设备绑定。
3. 支持旋转更新。
4. 支持主动注销全设备或单设备。

```go
type Session struct {
    ID           string
    UserID       string
    DeviceID     string
    RefreshToken string
    ExpiresAt    time.Time
    RevokedAt    *time.Time
}
```

### OAuth2 / OIDC

第三方登录统一通过身份连接器抽象，避免每个 Provider 写一套业务接入逻辑。

```go
type IdentityProvider interface {
    Name() string
    BuildAuthURL(state string) string
    ExchangeToken(ctx context.Context, code string) (*IdentityToken, error)
    FetchProfile(ctx context.Context, accessToken string) (*ExternalProfile, error)
}
```

### 企业微信 / 飞书 / 钉钉

企业级登录接入重点不是拿到用户信息，而是建立企业成员与平台租户成员的映射。必须明确：

- 企业唯一标识如何映射到租户。
- 外部联系人是否允许登录。
- 成员离职后如何自动失效。
- 部门同步与角色映射如何处理。

### GitHub / Google

适合开发者平台、外部合作伙伴平台或国际化场景。对于面向企业内部员工的产品，仍应优先支持企业身份源。

### 推荐登录流程

```mermaid
sequenceDiagram
    participant U as User
    participant FE as Frontend
    participant API as Auth API
    participant IDP as Identity Provider
    participant DB as PostgreSQL
    participant REDIS as Redis

    U->>FE: 点击第三方登录
    FE->>API: 请求授权跳转地址
    API->>IDP: 构造 OAuth/OIDC 请求
    IDP-->>U: 登录授权页
    U->>IDP: 完成授权
    IDP->>API: 回调 code
    API->>IDP: 换取 token 与用户资料
    API->>DB: 建立用户与身份映射
    API->>REDIS: 写入会话
    API-->>FE: 返回 access token / refresh token
```

### 最佳实践

- 用户表与租户成员表分离。
- 所有登录都落审计日志。
- 密码只允许使用强哈希算法，如 Argon2id 或 bcrypt。
- 对异常登录、频繁失败、异地设备要有风控策略。

### 用户与成员模型

用户体系最常见的建模错误，是把“登录账号”“组织成员”“租户角色”“设备会话”混在同一张表里。推荐拆分为四类对象：

- `users`：自然人账号，承载身份主数据。
- `user_identities`：第三方身份映射，如企业微信 openid、GitHub id。
- `tenant_members`：用户在租户中的成员身份。
- `sessions`：登录会话与设备状态。

```mermaid
erDiagram
    USERS ||--o{ USER_IDENTITIES : has
    USERS ||--o{ TENANT_MEMBERS : joins
    USERS ||--o{ SESSIONS : owns
    TENANTS ||--o{ TENANT_MEMBERS : contains
```

这样拆分的收益是：单个用户可以加入多个租户，一个用户可以绑定多个身份源，一个成员被禁用不等于用户账号被删除，一个设备被踢下线不影响其他设备。

### 账号状态与成员状态

推荐分别维护：

- 用户账号状态：`active`、`locked`、`deleted`
- 租户成员状态：`active`、`invited`、`disabled`、`removed`

规则示例：

1. 用户账号被 `locked` 时，所有租户都无法登录。
2. 租户成员被 `disabled` 时，只影响当前租户访问。
3. 邀请中的成员只能完成激活流程，不能直接进入业务系统。

### 登录策略矩阵

不同登录方式在安全性、便捷性、适用业务上不同，建议平台建立统一策略矩阵：

| 登录方式 | 适用场景 | 风险点 | 推荐级别 |
| --- | --- | --- | --- |
| 账号密码 | 内部基础登录 | 弱密码、撞库 | 必备 |
| 邮箱验证码 | 外部协作 | 邮箱被控 | 推荐 |
| 手机验证码 | 高频快速登录 | 短信成本、SIM 风险 | 可选 |
| 企业微信/飞书/钉钉 | 企业组织接入 | 身份映射复杂 | 强推荐 |
| GitHub/Google | 开发者或国际化 | 组织映射弱 | 场景化 |

### 邀请与激活流程

推荐成员邀请采用“邀请记录 + 一次性激活令牌”模型，而不是直接预创建账号密码。流程建议：

```mermaid
sequenceDiagram
    participant A as Admin
    participant API as IAM API
    participant DB as PostgreSQL
    participant M as Mail/SMS
    participant U as Invitee

    A->>API: 邀请成员
    API->>DB: 创建 invited 状态成员
    API->>DB: 写入 activation token
    API->>M: 发送邀请链接
    U->>API: 使用链接完成激活
    API->>DB: 绑定用户与成员关系
    API-->>U: 激活成功
```

治理规则：

- 邀请链接必须有 TTL。
- 激活令牌一次性使用。
- 被移除成员再次邀请时，要有历史记录。
- 邀请邮件或短信模板必须带租户识别信息。

### Session 与设备治理

会话不仅是 token 存储问题，还涉及风控与账号控制。推荐每个会话至少记录：

- `session_id`
- `user_id`
- `tenant_hint`
- `device_id`
- `device_name`
- `ip`
- `user_agent`
- `issued_at`
- `expires_at`
- `last_seen_at`
- `revoked_at`

推荐设备控制能力：

- 查看当前活跃设备
- 注销单设备
- 注销其他设备
- 最近登录位置提示
- 风险设备二次验证

### Token 签发与轮换规范

Access Token 与 Refresh Token 必须分工明确：

- Access Token：短期、轻量、面向接口访问。
- Refresh Token：长期、可撤销、面向会话续签。

推荐规则：

1. Access Token 默认 15 到 60 分钟。
2. Refresh Token 默认 7 到 30 天。
3. 每次刷新刷新令牌时执行旋转。
4. 旧 Refresh Token 在旋转后立即失效。
5. 所有 Refresh Token 都必须可服务端吊销。

### 风险控制与登录安全

用户体系必须内建基础风控，而不是等出问题后补。推荐至少支持：

- 连续失败登录限流
- 异地登录提醒
- 新设备登录提醒
- 异常 IP 黑名单
- 高风险操作二次验证

对于后台系统，至少要做到“短时间密码暴力尝试锁定”和“敏感租户管理员异地登录告警”。

### 密码策略

密码策略推荐：

- 最小长度 12
- 禁止常见弱密码
- 支持密码泄露词库校验
- 重置密码后强制旧会话失效
- 密码修改落审计日志

示例：

```go
func HashPassword(password string) (string, error) {
    return argon2id.CreateHash(password, argon2id.DefaultParams)
}
```

### 身份绑定与解绑规范

第三方身份绑定必须可审计、可撤销、可冲突检测。必须考虑：

- 一个企业身份是否只能绑定一个平台用户
- 已有本地账号如何与第三方身份合并
- 解绑第三方身份后是否仍保留其他登录方式
- 解绑是否需要二次校验

### 用户体系测试重点

建议优先覆盖以下测试：

- 用户跨租户登录后成员身份正确切换
- 成员被禁用后旧 token 不再可访问
- Refresh Token 旋转后旧 token 立即失效
- 邀请激活链接过期与重复使用
- 第三方身份绑定冲突处理

### 用户体系反模式补充

- 直接把租户角色写入 JWT 长期缓存。
- 用户登出只清前端 token，不吊销服务端 session。
- 同一第三方身份可绑定多个用户而无冲突规则。
- 不保留登录审计与设备信息，导致账号风险无法追查。

### 反例

- 把角色信息直接固定在用户表字段中。
- 不区分用户冻结与成员禁用。
- refresh token 永不旋转、永不失效。

---

## 第十章 REST API 规范

### 设计原则

API 设计的目标是稳定、可理解、可演进、可生成 SDK、可被第三方长期集成。接口不能只为了当前页面服务，而应当是平台契约的一部分。

### URL 规范

- 统一前缀：`/api/v1`
- 资源化命名，使用名词而非动词
- 集合与单体明确区分
- 子资源表达关系，而非动词操作

示例：

- `GET /api/v1/crm/customers`
- `POST /api/v1/crm/customers`
- `GET /api/v1/crm/customers/{customerId}`
- `POST /api/v1/workflow/instances/{id}/approve`

说明：对于审批、发布、归档这类动作型操作，允许使用动作后缀，但必须是少数例外，且动作语义必须明确。

### Version

版本号放在 URL 中，主版本变更代表不兼容更新。兼容性新增字段不需要升版本。废弃字段必须经历“标记废弃 -> 文档公告 -> 灰度兼容 -> 正式移除”流程。

### Request / Response

请求体必须有明确 Schema；响应体必须统一包装并附带元信息。分页、排序、过滤必须采用统一参数语义。

```json
{
  "code": "OK",
  "message": "success",
  "data": {
    "items": [],
    "page": {
      "page": 1,
      "pageSize": 20,
      "total": 120
    }
  },
  "meta": {
    "requestId": "req_123"
  }
}
```

### 分页

列表接口默认支持页码分页，超大数据集建议升级为游标分页。管理后台常规列表可用：

- `page`
- `pageSize`
- `sort`
- `order`

高频滚动流或时间序列可用：

- `cursor`
- `limit`

### 排序 / 过滤

排序字段必须白名单控制，禁止前端任意传列名。过滤参数命名建议：

- `keyword`
- `status`
- `ownerId`
- `createdAtFrom`
- `createdAtTo`

### 错误码

错误码必须稳定可检索，推荐分层：

- `AUTH_*`
- `PERMISSION_*`
- `TENANT_*`
- `VALIDATION_*`
- `CRM_*`
- `WORKFLOW_*`
- `INTERNAL_*`

### OpenAPI / Swagger

OpenAPI 是契约源，不是事后补文档。接口定义必须随代码一起演进，并用于：

- 文档展示
- SDK 生成
- 测试契约校验
- Mock 数据生成

### 推荐代码示例

```yaml
paths:
  /api/v1/crm/customers:
    get:
      summary: List customers
      tags: [CRM]
      parameters:
        - in: query
          name: page
          schema:
            type: integer
        - in: query
          name: pageSize
          schema:
            type: integer
      responses:
        "200":
          description: OK
```

### 方法语义规范

HTTP 方法不是装饰，而是契约。推荐语义如下：

- `GET`：只读，无副作用。
- `POST`：创建资源或触发无法天然幂等的动作。
- `PUT`：整体替换资源。
- `PATCH`：局部更新资源。
- `DELETE`：删除或归档资源。

注意事项：

- 不允许用 `GET` 执行有副作用动作。
- 不允许所有更新一律使用 `POST /updateXxx`。
- 不允许删除接口通过 `GET /delete` 触发。

### 幂等性规范

对于创建订单、发起审批、导入任务、Webhook 重放、支付回调等重要写操作，API 必须支持幂等控制。推荐通过请求头实现：

- `Idempotency-Key`

服务端处理原则：

1. 同一租户、同一资源、同一幂等键在 TTL 内只生效一次。
2. 首次成功结果可缓存并复用。
3. 首次处理中时，重复请求返回处理中状态。
4. 幂等键必须带 TTL 与业务作用域。

```http
POST /api/v1/workflow/instances/approve
Idempotency-Key: idem_approve_20260630_xxx
```

### 请求头规范

建议统一定义以下头信息：

- `Authorization`
- `X-Tenant-Id`
- `X-Workspace-Id`
- `X-Request-Id`
- `X-Trace-Id`
- `Idempotency-Key`
- `Accept-Language`

后端处理原则：

- `X-Tenant-Id` 与 `X-Workspace-Id` 只作提示，最终以服务端校验后的上下文为准。
- `X-Request-Id` 若客户端未传，由服务端生成。
- `X-Trace-Id` 与链路系统打通，便于前后端联调。

### 字段命名与兼容性规范

API 字段命名建议统一使用 `camelCase`，保持前后端易于对接。兼容性规则如下：

1. 新增字段必须保持向后兼容。
2. 已发布字段不得随意改名。
3. 弃用字段必须在文档中标记 `deprecated`。
4. 字段语义变化视同破坏性变更。

### 列表响应规范

所有列表型接口必须返回稳定分页结构，不允许有的模块返回数组，有的模块返回对象。推荐结构：

```json
{
  "code": "OK",
  "message": "success",
  "data": {
    "items": [],
    "page": {
      "page": 1,
      "pageSize": 20,
      "total": 0,
      "hasMore": false
    }
  }
}
```

### 错误响应规范

错误响应必须便于用户提示、前端分流与日志定位。推荐增加 `details` 字段承载字段级错误或调试上下文摘要：

```json
{
  "code": "VALIDATION_FAILED",
  "message": "request validation failed",
  "details": {
    "name": "required",
    "pageSize": "must be less than 100"
  },
  "meta": {
    "requestId": "req_123"
  }
}
```

### 批量接口规范

批量接口应显式表达是“全成功”还是“部分成功”。推荐：

- 小规模同步批量：返回逐项结果
- 大规模批量：转异步任务

```json
{
  "code": "OK",
  "data": {
    "successCount": 8,
    "failureCount": 2,
    "failures": [
      { "id": "c1", "code": "PERMISSION_DENIED" }
    ]
  }
}
```

### 文件上传与下载接口规范

文件接口不应直接上传大文件到业务 API。推荐两段式：

1. 申请上传策略或预签名地址。
2. 上传完成后确认回写元数据。

下载也应区分：

- 元数据查询接口
- 临时下载 URL 获取接口

### OpenAPI 作为契约源的治理

OpenAPI 定义应进入代码审查范围。每次接口变更必须同步检查：

- 路径与方法是否合理
- 请求体是否可验证
- 返回结构是否兼容
- 错误码是否补全文档
- SDK 生成是否通过

### API 评审清单

接口在合并前至少要回答：

- 是否符合资源化命名
- 是否有统一错误码
- 是否定义了权限资源
- 是否包含租户语义
- 是否定义分页、过滤、排序白名单
- 是否需要幂等性
- 是否补齐 OpenAPI

### API 反模式补充

- 接口只为当前页面临时拼装，未来无法复用。
- 同一资源列表有三套不同分页结构。
- 错误码与 HTTP 状态码语义混乱。
- 一个接口同时承担查询、校验、保存三个动作。

### 反例

- 用 `POST /queryCustomerList` 风格替代资源化接口。
- 响应结构每个模块各自定义。
- 错误码依赖中文字符串判断。
- 前后端不共享同一份接口契约。

---

## 第十一章 Redis 规范

### 设计目标

Redis 不是“性能不够时随手加一下”的万能工具，而是平台级缓存、会话、限流、验证码、短期令牌、分布式锁与任务辅助存储。使用 Redis 的前提是明确数据生命周期、一致性要求与失效策略。

### 缓存

缓存优先用于读取热点、低频变更、可容忍短暂不一致的数据。例如：

- 权限快照
- 配置项
- 字典数据
- Dashboard 聚合结果
- 租户套餐摘要

### Session

会话建议服务端持久化于 Redis，支持：

- 主动注销
- 多设备控制
- 风险登录封禁
- Refresh Token 校验

### 验证码

验证码 Key 必须短 TTL、一次性使用、带场景隔离。不要把验证码明文长期存在数据库中。

### Token

短效访问令牌可以无状态验证，长效 Refresh Token 或一次性签名令牌建议在 Redis 中维护状态，支持吊销与幂等。

### Rate Limit

限流维度建议支持：

- IP
- 用户 ID
- 租户 ID
- 接口资源
- 第三方应用 ID

### Key 命名

统一命名结构：

`<env>:<app>:<module>:<tenant>:<resource>:<identifier>`

示例：

- `prod:sass:auth:tenant_01:session:sid_xxx`
- `prod:sass:iam:tenant_01:perm:user_01`
- `prod:sass:crm:tenant_01:customer:list:hash_xxx`

### TTL

TTL 必须按业务语义区分：

- 验证码：5 分钟
- 幂等键：24 小时
- 权限缓存：5 至 15 分钟
- Dashboard 聚合：1 至 10 分钟
- 会话：跟随 session 生命周期

### 最佳实践

```go
func BuildRedisKey(parts ...string) string {
    return strings.Join(parts, ":")
}
```

### Redis 使用分类

为了避免 Redis 逐渐变成难以治理的“杂物间”，推荐将用途分类管理：

- `cache`：读缓存
- `session`：会话
- `token`：刷新令牌、一次性令牌
- `limit`：限流
- `lock`：分布式锁
- `queue-meta`：异步任务辅助状态

每一类都应有独立前缀、TTL 策略和监控指标。

### 缓存设计原则

缓存设计必须先回答三件事：

1. 缓存的数据是什么
2. 何时失效
3. 失效后如何回源

推荐缓存模式：

- Cache Aside：绝大多数读缓存默认模式
- Write Through：极少数强控制场景
- Write Behind：默认不推荐，复杂度高

### 缓存一致性策略

缓存不是一致性来源，数据库才是。建议采用：

1. 先更新数据库
2. 再删除缓存
3. 必要时短延迟二次删除

对于权限、字典、套餐等缓存，还应支持主动广播失效。禁止：

- 先删缓存再写数据库
- 修改数据库后忘记清缓存
- 依赖超长 TTL“等它自己过期”

### 热点 Key 与雪崩防护

推荐实现以下策略：

- TTL 加随机抖动，防止集中过期
- 热点数据本地短缓存 + Redis 双层缓存
- 缓存击穿场景对单 Key 做互斥回源
- 必要时做空值缓存防穿透

### 分布式锁规范

Redis 锁仅适合短时间、可容忍偶发竞争的互斥场景，如：

- 防止重复创建
- 限制相同导出任务重复提交
- 控制短期串行操作

不适合：

- 代替数据库事务
- 长时间任务全程锁住
- 作为关键资金或核心一致性唯一保障

推荐锁 Key：

- `prod:sass:lock:tenant_01:export:customer_20260630`

### Session 存储规范

Redis 中的 session 建议只存服务端会话摘要，而不是整个用户上下文大对象。推荐字段：

- `userId`
- `sessionId`
- `deviceId`
- `tenantHint`
- `expiresAt`
- `revoked`

权限、成员、部门等高变数据不建议长期固化进 session 缓存。

### 限流实施建议

限流要根据目标不同采用不同维度：

- 登录接口：按 IP + 账号
- 导出接口：按用户 + 租户
- AI 接口：按租户 + 模型
- Webhook 回调：按应用 + 路径

可以采用滑动窗口或令牌桶，关键是限流结果要可观测，不能只在代码里静默拒绝。

### Redis 监控指标

建议至少监控：

- 内存使用率
- 命中率
- 过期键数量
- 热点 Key 访问分布
- 慢命令
- 连接数
- 被驱逐键数量

### Redis 运维边界

任何新引入的 Redis 用途都应登记：

- Key 前缀
- 数据结构
- TTL
- 失效策略
- 所属模块
- 是否含租户语义

没有登记的 Key，后期几乎无法治理与清理。

### Redis 反模式补充

- 用一个 Hash 存整个租户所有复杂状态。
- 没有 TTL 的临时任务状态长期堆积。
- 使用 `KEYS *` 做生产排查。
- 把大对象 JSON 直接塞入热点缓存而不做裁剪。

### 反例

- 使用裸字符串 Key，无环境前缀。
- 永不过期缓存占满内存。
- 把 Redis 当主数据库保存关键业务事实。

---

## 第十二章 文件管理

### 目标

文件能力必须平台化，统一处理上传、下载、预签名、对象路径、元数据、缩略图、权限与合规审计。业务模块不得直接操作对象存储 SDK。

### MinIO / OSS / COS / S3

建议定义统一对象存储接口，对接 MinIO、阿里云 OSS、腾讯云 COS、AWS S3。平台内部只感知 `StorageProvider` 抽象。

```go
type StorageProvider interface {
    PutObject(ctx context.Context, input PutObjectInput) (*PutObjectResult, error)
    GetPresignedUploadURL(ctx context.Context, input PresignInput) (string, error)
    GetPresignedDownloadURL(ctx context.Context, input PresignInput) (string, error)
    DeleteObject(ctx context.Context, objectKey string) error
}
```

### 上传

上传流程推荐：

1. 前端申请上传凭证。
2. 后端校验租户、目录、文件类型与大小。
3. 后端生成预签名上传地址。
4. 前端直传对象存储。
5. 上传完成后回调确认，写入文件元数据表。

### 下载

下载必须考虑权限控制、时效限制、敏感文件水印与审计记录。敏感文件禁止暴露永久公开 URL。

### 预签名

预签名 URL 的使用原则：

- 只用于临时上传/下载。
- TTL 尽可能短。
- 路径必须绑定租户和目录策略。
- 服务端必须保留操作审计。

### 缩略图

图片、PDF 首图、视频封面等应通过异步任务生成，不在同步请求中处理。

### 推荐数据表

```mermaid
erDiagram
    FILES {
        uuid id
        uuid tenant_id
        string bucket
        string object_key
        string file_name
        string mime_type
        bigint size
        string hash
        timestamptz created_at
    }
    FILE_VARIANTS {
        uuid id
        uuid file_id
        string variant_type
        string object_key
    }
    FILES ||--o{ FILE_VARIANTS : has
```

### 文件对象模型

文件平台不应只是一张 `files` 表。推荐最少拆成以下概念：

- 文件元数据：文件主记录
- 文件变体：缩略图、水印图、转码结果
- 文件引用：文件被哪个业务对象引用
- 文件审计：上传、下载、删除、分享记录

这样做能解决三个典型问题：

1. 同一文件被多个业务对象复用时，不需要复制对象。
2. 文件删除时可以先检查是否仍有引用。
3. 敏感文件下载与分享可单独审计。

### 对象路径规范

对象路径必须具备可读性、租户隔离和业务归类。推荐结构：

`/<tenant-id>/<module>/<yyyy>/<mm>/<dd>/<file-id>/<original-name>`

示例：

- `/tenant_01/crm/2026/06/30/file_123/report.xlsx`
- `/tenant_01/audit/2026/06/30/file_456/snapshot.json`

规则：

- 路径中必须包含 `tenant_id`
- 路径中不得直接使用用户原始文件名作为唯一标识
- 文件展示名与对象键分离

### 上传安全检查

上传不只是大小和后缀校验，推荐分层检查：

1. 前端基础限制：大小、扩展名、数量
2. 后端签发前校验：MIME 白名单、目录权限、配额
3. 上传完成后校验：内容嗅探、哈希、病毒扫描
4. 异步处理：缩略图、转码、OCR、PDF 首图

高风险文件类型应支持隔离区或人工审核策略。

### 文件生命周期

文件平台应明确生命周期状态，而不是上传成功后长期悬空：

- `pending_upload`
- `uploaded`
- `scanning`
- `available`
- `quarantined`
- `deleted`

```mermaid
flowchart LR
    A[pending_upload] --> B[uploaded]
    B --> C[scanning]
    C --> D[available]
    C --> E[quarantined]
    D --> F[deleted]
```

### 文件引用关系

业务模块不得通过字符串路径裸引用文件，推荐统一使用文件引用表：

```sql
CREATE TABLE platform.file_references (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    file_id UUID NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id UUID NOT NULL,
    field_name VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

这样能够支持：

- 删除前引用检查
- 清理孤儿文件
- 查询某业务对象的全部附件
- 审计文件与业务对象的关系

### 下载与分享控制

下载必须区分内部下载、公开分享、外部临时分享三种场景。建议：

- 内部下载：权限校验 + 短时预签名
- 外部分享：独立分享 token + 过期时间 + 次数限制
- 敏感下载：额外审计 + 水印 + 二次校验

### 文件去重与哈希

大文件平台通常会遇到重复上传问题。可选支持基于内容哈希的去重，但要注意：

- 去重是存储优化，不等于业务引用复用逻辑
- 不同租户间是否允许跨租户物理去重，需要审慎评估合规风险
- 哈希碰撞虽小概率，但业务层仍要以文件元数据为主

### 文件清理与归档

必须定义清理规则：

- 未完成上传的临时对象保留时长
- 导出文件默认保留时长
- 被删除文件何时物理清理
- 隔离区文件如何复核与销毁

建议至少提供一个定时清理任务扫描：

- 孤儿文件
- 过期预签名记录
- 已删除但未清理的对象
- 长期未引用的导出产物

### 文件平台接口建议

文件平台对外建议统一提供：

- 申请上传凭证
- 确认上传完成
- 获取文件详情
- 获取下载凭证
- 删除文件
- 绑定业务引用
- 解除业务引用

### 文件平台反模式补充

- 业务代码直接写 S3/MinIO SDK。
- 路径中没有租户信息，后期无法治理。
- 文件上传成功即视为可用，不做扫描与异步处理。
- 导出文件无引用关系、无过期策略、无审计记录。

### 反例

- 前端直接将文件上传到固定公开桶。
- 通过文件后缀而非 MIME 与内容检测判断类型。
- 将导出文件长期保留且无回收机制。

---

## 第十三章 异步任务

### Asynq 设计原则

异步任务用于削峰、解耦和耗时操作下沉。所有异步任务必须具备幂等性、可重试性、可观测性与可回溯性。任务系统不是“把同步错误藏起来”的垃圾桶。

### 任务类型

- 邮件
- 短信
- Webhook
- 导入
- 导出
- Excel
- PDF
- AI 任务

### 任务载荷设计

任务载荷只放必要标识与快照，不放超大对象。优先存 ID，再在 worker 中回查最新状态；若要求严格一致的历史输出，可附带快照版本。

```go
type ExportCustomersPayload struct {
    TenantID   string
    OperatorID string
    TaskID     string
    Filter     map[string]any
}
```

### 投递规范

- 所有任务必须有 `task_type`。
- 必须有租户信息。
- 必须定义最大重试次数与超时时间。
- 必须记录任务来源模块与操作人。

### Worker 规范

Worker 必须做到：

1. 幂等执行。
2. 可记录执行日志。
3. 失败分类重试。
4. 支持死信或人工介入。

```go
func (h *ExportCustomersHandler) ProcessTask(ctx context.Context, t *asynq.Task) error {
    var payload ExportCustomersPayload
    if err := json.Unmarshal(t.Payload(), &payload); err != nil {
        return fmt.Errorf("unmarshal payload: %w", err)
    }

    if err := h.service.Run(ctx, payload); err != nil {
        return fmt.Errorf("run export: %w", err)
    }
    return nil
}
```

### Webhook

Webhook 发送建议异步执行，并支持签名、重试、退避、幂等键与投递日志查询。

### 导入 / 导出 / Excel / PDF

导入导出必须遵循：

- 文件格式校验
- 模板版本管理
- 大任务异步化
- 结果可下载
- 失败明细可追踪

### AI 任务

AI 任务包括摘要、分类、抽取、Embedding、RAG 索引等。它们应与普通业务任务隔离队列，避免互相抢资源。

### 流程图

```mermaid
flowchart TD
    A[Submit Task] --> B[Persist Task Record]
    B --> C[Push Asynq Queue]
    C --> D[Worker Consume]
    D --> E{Success?}
    E -->|Yes| F[Update Result]
    E -->|No| G[Retry / Dead Letter]
```

### 任务状态机

异步任务的关键不是“有没有队列”，而是状态是否可追踪。推荐每个任务都具备稳定状态机：

- `pending`
- `queued`
- `running`
- `succeeded`
- `failed`
- `retrying`
- `dead`
- `cancelled`

```mermaid
flowchart LR
    A[pending] --> B[queued]
    B --> C[running]
    C --> D[succeeded]
    C --> E[failed]
    E --> F[retrying]
    F --> B
    E --> G[dead]
    B --> H[cancelled]
```

状态机的意义在于：运营、客服、研发可以对“任务到底发生了什么”达成统一认知，而不是只看到一条模糊的失败日志。

### 任务记录模型

建议任务队列之外，平台还维护一张业务任务表，用于跨模块查询与审计：

```sql
CREATE TABLE platform.async_tasks (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    task_type VARCHAR(100) NOT NULL,
    queue_name VARCHAR(100) NOT NULL,
    status VARCHAR(32) NOT NULL,
    payload JSONB NOT NULL,
    retry_count INT NOT NULL DEFAULT 0,
    max_retry INT NOT NULL DEFAULT 10,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

任务表负责：

- 提供跨队列统一查询
- 记录业务来源与操作人
- 支持管理后台查看执行历史
- 为重试、取消、人工介入提供依据

### 队列分层与优先级

建议不要把所有任务都塞进一个默认队列。至少按以下维度分层：

- `critical`：通知回调、计费相关、关键审计补偿
- `default`：普通异步任务
- `bulk`：导入导出、报表、批量同步
- `ai`：Embedding、RAG 索引、批量推理

设计原则：

1. 面向用户实时反馈的任务优先级高于批处理。
2. 高成本 AI 任务必须与普通业务任务隔离。
3. 队列并发数与重试策略按队列级配置。

### 幂等与去重策略

异步任务天然会重试，因此幂等性是底线。推荐做法：

- 任务入队前生成业务幂等键
- Worker 执行前检查幂等记录或业务状态
- 输出结果具备幂等落库能力
- 外部回调或发送类任务带业务唯一请求号

```go
type IdempotentTask interface {
    IdempotencyKey() string
}
```

适用场景：

- 导出同一份报表避免重复生成
- 同一审批回调避免重复通知
- 同一文件转码任务避免重复执行

### 重试策略与错误分类

所有任务错误都重试是低级错误。建议至少区分：

- `Transient`：临时性错误，可重试，如网络抖动
- `Business`：业务错误，不应重试，如参数非法
- `Dependency`：外部依赖故障，可指数退避重试
- `Fatal`：程序性或不可恢复错误，进入死信

```go
type RetryableError struct {
    Cause error
}

func (e RetryableError) Error() string { return e.Cause.Error() }
```

### Outbox 与最终一致性

对于“数据库写入成功后必须投递任务”的场景，建议采用 outbox 模式或等价机制，而不是在事务中直接发队列。原则是：

1. 事务内写业务数据与 outbox 记录。
2. 提交后由独立 dispatcher 投递消息。
3. dispatcher 失败可重试，不影响主事务。

适用场景：

- 订单创建后发送通知
- 客户创建后触发欢迎流程
- 文件上传成功后触发异步扫描

### Worker 资源治理

Worker 不是无限扩容的垃圾桶。必须控制：

- 并发数
- 超时时间
- 内存上限
- 重试次数
- 单租户任务风暴隔离

大租户批量导入、批量 AI 任务必须有租户级配额与并发限制，避免单租户拖垮全局系统。

### 任务可观测性

每个任务执行日志至少包含：

- `task_id`
- `task_type`
- `queue`
- `tenant_id`
- `operator_id`
- `attempt`
- `latency_ms`
- `result`

建议额外暴露指标：

- 队列堆积长度
- 任务平均耗时
- 成功率 / 失败率
- 死信数量
- 重试次数分布

### 导入导出治理规范

导入导出是企业 SaaS 中最容易引发事故的异步任务类型。必须具备：

- 模板版本号
- 文件类型校验
- 列级错误明细
- 分批处理与断点可追踪
- 导出文件过期回收

推荐导入流程：

1. 上传源文件
2. 创建导入任务
3. 预解析并校验模板
4. 分批入库
5. 生成结果报告

### 异步任务反模式补充

- 同一业务动作既同步执行又异步补一遍，导致重复副作用。
- Worker 中直接访问前端传入未经校验的原始 payload。
- 不记录任务创建人和租户，后续无法追责。
- 把死信任务当正常失败忽略，不提供人工干预入口。

### 反例

- 异步任务内再发无边界的异步任务。
- Worker 里缺少租户上下文与审计信息。
- 导出任务结果不清理，长期堆积对象存储。

---

## 第十四章 AI 模块

### 模块定位

AI 模块在企业 SaaS 中不应只是“加一个聊天框”，而应成为可管理、可审计、可计费、可替换的能力中心。平台需要统一处理 Provider、模型参数、Prompt 模板、会话记录、Embedding、RAG、向量索引、Token 统计与限额。

### Provider

通过 Provider 抽象屏蔽不同大模型差异：

```go
type AIProvider interface {
    Name() string
    Chat(ctx context.Context, req ChatRequest) (*ChatResponse, error)
    Embedding(ctx context.Context, req EmbeddingRequest) (*EmbeddingResponse, error)
    CountTokens(ctx context.Context, input []Message) (int, error)
}
```

### Prompt

Prompt 必须模板化、版本化、可审计。建议结构：

- 模板编码
- 场景名称
- 系统提示词
- 变量定义
- 版本号
- 启用状态
- 安全策略

### Chat

对话系统必须区分：

- 用户会话
- 模型请求
- 工具调用
- 上下文裁剪
- 安全过滤

### Embedding / RAG / Vector / pgvector

推荐使用 PostgreSQL + `pgvector` 作为早期统一向量存储方案，以降低运维复杂度。RAG 体系建议拆分：

- 文档采集
- 文档切片
- 向量化
- 检索
- 重排
- 提示组装
- 模型生成

```mermaid
flowchart LR
    A[Documents] --> B[Chunking]
    B --> C[Embedding]
    C --> D[(pgvector)]
    Q[Query] --> E[Retrieve]
    D --> E
    E --> F[Rerank]
    F --> G[Prompt Assembly]
    G --> H[LLM Response]
```

### 模型管理

模型管理要支持：

- 多 Provider
- 多模型版本
- 租户级启用策略
- 成本与限流配置
- 回退策略

### Token 统计

所有 AI 请求必须统计：

- 输入 Token
- 输出 Token
- Provider
- 模型名称
- 耗时
- 成本估算
- 发起租户与用户

### 最佳实践

- AI 结果默认不可信，必须允许人工确认。
- 敏感数据进入模型前必须脱敏。
- Prompt、模型、知识库都要版本化。
- 长任务与实时聊天队列分离。

### AI 能力分层

AI 模块建议拆为四层，避免“聊天接口里什么都做”：

```mermaid
flowchart TD
    A[Provider Adapters] --> B[Model Runtime]
    B --> C[Prompt / Tool / RAG Orchestration]
    C --> D[Business AI Applications]
```

- `Provider Adapters`：适配 OpenAI、Azure、阿里、火山等模型提供方
- `Model Runtime`：统一超时、重试、限流、成本计算
- `Prompt / Tool / RAG Orchestration`：编排提示词、工具调用、知识检索
- `Business AI Applications`：摘要、问答、分类、抽取、助手

### 模型路由与回退

同一类能力建议支持模型路由，而不是写死单模型。至少考虑：

- 首选模型
- 备选模型
- 降级策略
- 成本上限
- 超时回退

示例：

```go
type ModelRoute struct {
    Scene         string
    PrimaryModel  string
    FallbackModel string
    Timeout       time.Duration
    MaxCost       decimal.Decimal
}
```

### Prompt 模板治理

Prompt 是业务资产，必须像代码一样管理。推荐每个 Prompt 至少包含：

- `code`
- `scene`
- `version`
- `system_prompt`
- `variables_schema`
- `output_schema`
- `risk_level`
- `owner`

并要求：

1. Prompt 改动进入 code review。
2. 输出结构化场景必须有 Schema 校验。
3. 关键 Prompt 变更要记录效果指标。

### 工具调用与函数编排

对企业 SaaS 来说，AI 真正有价值的不是闲聊，而是调用平台工具能力。建议工具调用统一抽象：

```go
type AITool interface {
    Name() string
    Description() string
    InputSchema() any
    Execute(ctx context.Context, input json.RawMessage) (any, error)
}
```

原则：

- 工具调用必须受权限控制
- 工具输入输出必须可审计
- 工具执行超时必须受控
- 工具结果不允许绕过正常业务校验

### 知识库治理

RAG 的真正难点不在向量库，而在知识治理。必须明确：

- 文档来源是否合法
- 文档版本是否可追踪
- 切片策略是否稳定
- 过期知识如何清理
- 权限如何影响可检索范围

推荐知识库对象至少包含：

- 知识源
- 文档版本
- 切片记录
- 向量索引记录
- 权限标签

### AI 安全与合规

AI 模块必须关注以下风险：

- 敏感信息泄露
- Prompt Injection
- 越权工具调用
- 幻觉内容误用
- 成本失控

推荐控制措施：

1. 输入脱敏与敏感标签识别
2. 工具调用白名单
3. 输出结构校验
4. 高风险场景人工确认
5. 模型请求与响应留痕

### Token 与成本治理

Token 统计不能只是做账，还要进入资源治理。建议支持：

- 租户配额
- 用户级限额
- 模型级限流
- 场景成本分析
- 超预算熔断或降级

```mermaid
flowchart LR
    A[Request] --> B[Quota Check]
    B --> C[Model Execute]
    C --> D[Token Count]
    D --> E[Cost Record]
    E --> F[Budget Analysis]
```

### AI 响应结构化规范

对于分类、抽取、评分、字段填充等企业场景，输出必须结构化。推荐使用 JSON Schema 或 Zod/Go struct 校验，而不是让下游解析自然语言。

```go
type SummaryResult struct {
    Title   string   `json:"title"`
    Summary string   `json:"summary"`
    Tags    []string `json:"tags"`
}
```

### 会话与上下文窗口治理

聊天能力必须明确：

- 会话最大轮数
- 上下文裁剪策略
- 是否允许携带历史附件
- 是否允许跨租户知识混查

默认规则：

- 上下文只允许同一租户内数据
- 附件类上下文必须走权限校验
- 会话历史具备过期与归档策略

### AI 模块测试重点

建议重点覆盖：

- Provider 切换与回退是否正常
- Prompt 模板变量缺失时的失败处理
- 工具调用越权是否被拦截
- 知识库权限是否按租户/成员生效
- Token 统计与费用归集是否准确

### AI 反模式补充

- 为了快上线，在业务代码中直接调用第三方模型 SDK。
- 不对输出做结构校验，直接写入业务数据库。
- 多租户知识库不做权限隔离。
- 没有预算控制，导致测试环境滥用高成本模型。

### 反例

- 业务代码直接写死某个模型 SDK。
- 不统计 Token 成本，导致预算失控。
- 将原始敏感附件不做处理直接送往外部模型。

---

## 第十五章 审计日志

### 设计目标

审计日志的核心目标是追踪“谁，在什么租户，通过什么入口，对什么对象，做了什么操作，结果如何”。企业级 SaaS 中，审计不是附属功能，而是安全、合规、运维、客户成功与问题追责的共同底座。

### 日志分类

- 登录日志
- 操作日志
- 异常日志
- SQL 日志
- API 日志

### 登录日志

记录登录方式、设备、IP、地区、结果、风险原因。异常登录需要具备告警与封禁能力。

### 操作日志

重点覆盖：

- 创建、更新、删除
- 审批、发布、归档
- 导入、导出、下载敏感文件
- 权限变更、成员变更、角色变更

操作日志记录的不是完整 SQL diff，而是业务可理解的变化摘要。

### 异常日志

异常日志要同时保留技术细节与业务上下文。建议分级：

- `WARN`：可恢复异常
- `ERROR`：请求失败
- `FATAL`：系统不可用

### SQL 日志

SQL 日志必须用于排查，不应用于替代审计。生产环境建议记录慢 SQL、错误 SQL、事务异常与关键表写入摘要，不建议全量明文打印敏感值。

### API 日志

记录方法、路径、状态码、耗时、租户、用户、请求 ID、Trace ID。对于敏感接口只记录摘要，不记录完整敏感请求体。

### 推荐数据模型

```mermaid
erDiagram
    AUDIT_LOGS {
        uuid id
        uuid tenant_id
        uuid operator_id
        string module
        string action
        string target_type
        string target_id
        jsonb changes
        string source
        timestamptz created_at
    }
```

### 最佳实践

- 审计日志单独索引与分区。
- 支持按租户、模块、操作人、对象快速检索。
- 对关键操作提供“前后快照摘要”。
- 审计日志不可被普通管理员篡改。

### 审计事件模型

建议统一定义审计事件，而不是各模块随意写文本日志。推荐字段：

- `event_id`
- `tenant_id`
- `operator_id`
- `module`
- `action`
- `target_type`
- `target_id`
- `result`
- `source_type`
- `source_id`
- `request_id`
- `trace_id`
- `snapshot_before`
- `snapshot_after`
- `created_at`

这样能保证跨模块的检索、报表和合规导出保持一致。

### 审计来源分类

建议区分不同来源：

- `web`
- `api`
- `system`
- `worker`
- `integration`
- `plugin`

来源不同，代表责任链不同。比如 `worker` 来源说明动作不是直接由用户点击产生，而是由异步补偿或系统行为触发。

### 审计采集时机

审计应尽量记录“业务结果”，而不是仅记录请求发生。建议：

- 登录成功/失败后记录登录审计
- 核心写操作在事务成功后写业务审计
- 高风险失败行为单独记录失败审计
- 导出、下载、查看敏感信息记录访问审计

### 审计留存与归档

审计日志通常增长极快，必须从一开始就规划留存：

- 在线热数据：近 90 天
- 温数据：近 1 年，可检索
- 冷归档：长期压缩存储，仅按需恢复

归档后仍要保证：

- 可以按租户导出
- 可以按时间范围检索
- 可以支持监管要求的保留期限

### 快照与差异摘要

不建议所有操作都记录全量对象快照，这会显著增加体积和敏感数据暴露风险。推荐：

- 普通操作记录字段级差异摘要
- 高风险操作记录脱敏前后快照
- 敏感字段只记录“已变更”，不记录原值

示例：

```json
{
  "changes": [
    { "field": "status", "before": "pending", "after": "approved" },
    { "field": "ownerId", "before": "u_01", "after": "u_09" }
  ]
}
```

### 审计检索设计

后台审计检索至少应支持：

- 时间范围
- 租户
- 模块
- 操作人
- 动作类型
- 目标对象
- 结果状态
- 来源类型

对于平台管理员，还应支持跨租户监管视图，但必须有更高权限与更严格审计。

### 审计与隐私平衡

审计系统的目标是可追溯，而不是无限制收集。必须避免：

- 记录明文密码
- 记录完整 Access Token / Refresh Token
- 记录身份证号、银行卡号等高敏信息明文
- 记录完整原始文件内容

推荐只保留摘要、掩码或哈希。

### 审计写入策略

为避免业务阻塞，审计可以采用同步主流程 + 异步扩展写法：

- 核心成功失败结果使用同步轻量写入或本地 outbox
- 大快照、全文记录、归档同步可异步补充

关键原则是：不能因为审计系统短暂异常就让所有业务完全不可用，但也不能完全丢失关键行为记录。

### 审计反模式补充

- 把审计日志等同于应用文本日志。
- 只审计成功操作，不审计失败高风险行为。
- 各模块自定义 action 命名，无法统一统计。
- 日志可被普通管理员删除或修改。

### 反例

- 仅记录“操作成功”四个字，无对象与字段变化。
- 日志没有租户与操作人上下文。
- 把完整密码、Token、身份证号写入日志。

---

## 第十六章 Design System

### 设计原则

Design System 是为了建立跨团队一致性，而不是制造视觉教条。它必须同时服务设计、研发、测试、产品与品牌。企业级 SaaS 的设计系统重点不是营销感，而是“信息密度、操作确定性、层级清晰、反馈及时、长时间使用舒适、暗黑模式稳定”。

### 颜色规范

颜色必须分为原始色板与语义色板。不要直接在组件里写 `blue-500` 代表主按钮。推荐语义层：

- `--color-bg`
- `--color-fg`
- `--color-primary`
- `--color-success`
- `--color-warning`
- `--color-danger`
- `--color-border`
- `--color-muted`

### 字体规范

- 正文：14px / 16px
- 说明文字：12px / 14px
- 标题：18px / 20px / 24px
- 数据指标：28px / 32px

必须统一行高和字重，不允许一个页面混用多套文本体系。

### Spacing / Radius / Shadow / Glass / Motion

- Spacing 使用 4 的倍数体系。
- Radius 控制为 6 / 8 / 12 / 16 四档。
- Shadow 分为低、中、高三个层级。
- Glass 效果只用于浮层、命令面板等少量场景。
- Motion 保持克制，优先反馈操作结果，而非炫技动画。

### Token 示例

```css
:root {
  --color-bg: oklch(0.99 0 0);
  --color-fg: oklch(0.22 0 0);
  --color-primary: oklch(0.58 0.19 258);
  --radius-sm: 6px;
  --radius-md: 8px;
  --space-2: 8px;
  --space-3: 12px;
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.08);
}
```

### 组件规范

以下组件必须形成标准实现：

- Button
- Input
- Select
- Dialog
- Drawer
- Table
- Card
- Empty
- Skeleton
- PageHeader
- Toolbar
- SearchBar

### Button

按钮必须具备：

- 主次层级
- 危险态
- 加载态
- 禁用态
- 图标前后插槽

### Input / Select

输入类组件必须支持：

- 标签
- 帮助文本
- 校验错误
- 前后缀
- 禁用只读
- 无障碍描述

### Dialog / Drawer

对话组件必须管理好焦点、ESC、遮罩点击、滚动锁定与移动端适配。复杂表单优先 Drawer，强确认或危险操作优先 Dialog。

### Table

表格是企业 SaaS 使用频次最高的复合组件。标准表格需支持：

- 固定列
- 排序
- 过滤
- 批量选择
- 行操作
- 空态
- 骨架屏
- 列配置

### 组件关系图

```mermaid
flowchart TD
    T[Design Tokens] --> C[Core Components]
    C --> P[Patterns]
    P --> S[Pages]
```

### Design Token 分层

Design Token 必须分层，否则系统会迅速退化为“一堆颜色变量”。推荐三层：

- 基础 Token：原始色板、字号、间距、半径、阴影
- 语义 Token：主色、成功、危险、背景、边框、文本
- 组件 Token：Button 高度、Input 边框色、Dialog 内边距

```mermaid
flowchart LR
    A[Primitive Tokens] --> B[Semantic Tokens]
    B --> C[Component Tokens]
    C --> D[Components]
```

这样做的价值是：品牌换色或暗黑模式切换时，优先修改 Token 映射，而不是全量修改组件。

### Token 发布链路

推荐把 Token 视为可发布资产，而不是零散 CSS 变量。标准链路应包括：

1. 设计稿维护 Token 源
2. Token 转换脚本生成 CSS / TS / JSON
3. UI 包消费 Token
4. 应用层只消费组件或语义变量

适合落地产物：

- `packages/tokens/dist/tokens.css`
- `packages/tokens/dist/tokens.ts`
- `packages/tokens/dist/tokens.json`

### 主题与品牌扩展

企业 SaaS 未来大概率会遇到品牌定制需求，因此主题体系必须支持：

- 默认主题
- 暗黑主题
- 高对比主题
- 租户品牌主题

原则：

- 主题切换只改变变量映射
- 组件结构与类名保持稳定
- 租户品牌主题不能破坏核心可用性和对比度

### 组件等级划分

建议将 Design System 组件划分为四级：

- `Primitives`：如 Button、Input、Badge
- `Composites`：如 SearchBar、Toolbar、DataTable
- `Patterns`：如 ListPageLayout、FormSection、EmptyState
- `Templates`：如 Dashboard 模板、详情页模板

只有这样，系统才不会陷入“什么都想做成基础组件”的伪抽象。

### 组件 API 设计原则

组件 API 必须稳定、简洁、语义明确。推荐规则：

1. Props 命名表达语义，而不是实现细节。
2. Variant 数量受控，避免无边界膨胀。
3. 插槽优先于过多布尔开关。
4. 保留原生属性透传能力。

反例是一个 Button 组件有十几个布尔值决定大小、颜色、边框、阴影、是否图标、是否块级，最终无人敢改。

### 表格与表单模式沉淀

企业后台重复度最高的不是单个按钮，而是列表和表单模式。建议 Design System 层沉淀：

- 标准列表页面骨架
- 标准筛选栏
- 标准分页器
- 标准批量操作区
- 标准表单分区
- 标准字段错误展示

这样不同模块做出来的列表页和编辑页才能具有一致操作成本。

### 无障碍设计要求

Design System 必须承担无障碍基线，而不是把责任留给业务页面。至少要求：

- 焦点可见
- 键盘可操作
- 表单标签与错误信息关联
- Dialog / Drawer 焦点锁定
- 图标按钮具备文本描述

### 文档与示例治理

每个核心组件都应具备：

- 使用场景说明
- Props 文档
- Variant 展示
- Do / Don't 示例
- 可访问性说明

推荐结合 Storybook 或文档站点管理，但文档必须跟随组件版本更新，而不是单独漂移。

### 设计与研发协作机制

Design System 的失败往往不是技术问题，而是协作问题。建议建立：

- 组件变更评审机制
- Token 变更通知机制
- 设计稿与代码双向校验流程
- 组件废弃与迁移清单

### Design System 版本治理

组件库必须有版本策略：

- 破坏性变更进入大版本
- 新增 variant 或能力进入小版本
- 修复样式与行为问题进入补丁版本

同时建议为组件提供废弃标记与迁移指南，而不是直接删除旧接口。

### Design System 反模式补充

- 每个项目组复制一份组件再自行改。
- 组件没有文档，只能靠看源码猜用法。
- 设计稿与代码命名完全不一致。
- Token 直接在页面里被局部覆盖成不可维护状态。

### 反例

- 同一系统中出现三套按钮风格。
- 不同页面的表格头高、行高、筛选栏行为完全不同。
- 暗黑模式通过组件内 `if dark` 硬编码颜色。

---

## 第十七章 页面规范

### 页面体系

页面是用户感知系统质量最直接的部分。企业 SaaS 页面规范必须保障：信息结构稳定、任务链清晰、反馈一致、学习成本低、跨模块体验统一。推荐抽象页面模式：

- Dashboard
- 列表页
- 详情页
- 编辑页
- 弹窗
- 抽屉
- 登录页
- 工作台

### Dashboard

Dashboard 不是把所有数据塞满首页，而是服务关键决策。每个 Dashboard 卡片必须回答：服务谁、更新频率、点击后去哪里、异常时如何解释。

### 列表页

列表页标准结构建议：

```mermaid
flowchart TD
    A[PageHeader] --> B[SearchBar]
    B --> C[Toolbar]
    C --> D[Table]
    D --> E[Pagination]
```

规范要求：

- 顶部固定页面标题与主操作。
- 筛选区域不超过两层。
- 批量操作明确作用范围。
- 空态要给出下一步引导。

### 详情页

详情页应围绕对象中心组织：

- 概览信息
- 关键指标
- 属性面板
- 相关记录
- 操作历史

### 编辑页

编辑页必须明确区分创建与编辑。复杂编辑流程建议拆为分区或步骤，而不是一个超长滚动表单。

### 弹窗 / 抽屉

弹窗适合短表单、确认与提示；抽屉适合上下文不想离场的中等复杂编辑；跨实体复杂流程应使用独立页面。

### 登录页

登录页必须支持：

- 账号登录与企业登录切换
- 多租户入口说明
- 错误提示
- 安全策略说明

### 工作台

工作台是按角色组织的任务入口，重点展示“待办、关注、异常、常用操作、快速入口”，不应等同于 Dashboard。

### 推荐页面骨架

```tsx
export function StandardListPage() {
  return (
    <div className="flex flex-col gap-4">
      <PageHeader title="客户管理" />
      <SearchBar />
      <Toolbar />
      <CustomerTable />
    </div>
  );
}
```

### 页面状态规范

企业级页面质量，核心不在静态布局，而在状态切换是否稳定。所有核心页面必须统一处理以下状态：

- `loading`
- `empty`
- `error`
- `forbidden`
- `partial-ready`
- `submitting`

推荐规则：

1. 列表页首次加载与筛选刷新态区分。
2. 详情页缺少权限与数据不存在必须分开展示。
3. 表单提交中禁止重复提交，并提供明确进度反馈。
4. 局部模块失败不能拖垮整页展示时，采用分区降级。

### 页面模板分层

建议页面模式进一步抽象为模板层，而不是每个模块各写一套页面壳。推荐：

- `ListPageTemplate`
- `DetailPageTemplate`
- `EditPageTemplate`
- `WorkspacePageTemplate`
- `AuthPageTemplate`

```mermaid
flowchart TD
    A[Page Template] --> B[Module Page]
    B --> C[Section Blocks]
    C --> D[Domain Components]
```

模板层应提供统一的：

- 页面头部
- 主操作区
- 面包屑
- 侧边摘要
- 底部操作栏
- 空态和错误态容器

### Dashboard 设计细则

Dashboard 不应只是“指标卡堆叠”。每个 Dashboard 页面必须定义：

- 服务角色
- 关键决策动作
- 数据更新时间
- 卡片点击后的落地页
- 异常指标的解释文案

推荐卡片类型：

- 指标卡
- 趋势卡
- 待办卡
- 风险卡
- 快捷入口卡

不允许一个 Dashboard 同时承担“看数、待办、配置入口、详情分析”全部角色而没有主线。

### 列表页交互规范

列表页是后台系统最高频页面，必须建立统一交互纪律：

1. 筛选栏优先展示最常用条件，其余收纳到高级筛选。
2. 当前筛选结果必须可见且可清空。
3. 批量操作必须明确勾选数量与影响范围。
4. 行操作数量不超过 3 个，更多使用下拉菜单。
5. 列表刷新、排序、分页、筛选后的 URL 状态可回放。

### 详情页结构规范

详情页建议采用“概览 + 主内容 + 辅助信息”结构：

```mermaid
flowchart LR
    A[Summary Header] --> B[Main Content]
    A --> C[Side Panel]
    B --> D[Timeline / Related Records]
```

其中：

- `Summary Header`：名称、状态、主操作
- `Main Content`：核心业务字段、子资源、变更操作
- `Side Panel`：负责人、标签、创建时间、审计摘要

### 编辑页保存策略

编辑页保存方式必须统一，不允许一个系统中同时出现大量互斥体验。推荐支持：

- 手动保存
- 自动草稿保存
- 离开确认
- 字段级校验
- 提交后跳转策略

适用原则：

- 简单表单优先手动保存
- 长表单或复杂向导支持自动草稿
- 多步骤流程提供步骤进度与草稿恢复

### 弹窗与抽屉使用边界

建议严格控制弹窗与抽屉的适用范围：

- 1 到 5 个字段短表单：`Dialog`
- 保持上下文的中等复杂编辑：`Drawer`
- 涉及附件、复杂分区或长流程：独立页面

绝不允许把完整详情页或大型配置中心强行塞入弹窗。

### 页面级权限与可见性规则

页面层至少要区分三类可见性：

- 是否可访问该路由
- 是否可查看某块区域
- 是否可执行某项操作

页面应当在进入时尽早判定路由权限，但字段、卡片和按钮权限可在区域级处理。需要避免整页闪烁后再被权限拒绝的差体验。

### URL 与页面状态同步

后台页面应尽量支持状态可分享、可回放。以下信息推荐与 URL 同步：

- 列表筛选条件
- 分页参数
- 排序参数
- 当前 Tab
- 详情页子面板

不建议与 URL 同步：

- 临时表单草稿
- 大对象复杂状态
- 敏感字段明文

### 页面骨架与性能体验

页面体验不应只靠全局 loading 遮罩。推荐：

- 首屏用 Skeleton
- 局部刷新用局部 loading
- 表格刷新保留旧数据 + 顶部进度
- 提交态使用按钮级 loading

### 页面规范反模式补充

- 所有页面都长得不同，用户每进一个模块都要重新学习。
- 筛选区、工具栏、表格、分页没有统一顺序。
- 详情页只展示字段，不展示时间线、关联记录和操作入口。
- 登录页没有明确租户、身份源和异常提示。

### 反例

- 列表页没有筛选摘要，用户不知道当前结果为何如此。
- 所有编辑都塞进弹窗，导致表单过长。
- 详情页没有关键历史与关联关系入口。

---

## 第十八章 Docker 规范

### Dockerfile

镜像构建必须稳定、最小化、可复现。推荐多阶段构建，前端与后端分别构建，再进入运行时镜像。

```dockerfile
FROM node:22-alpine AS web-builder
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm --filter admin-web build

FROM golang:1.24-alpine AS server-builder
WORKDIR /src
COPY . .
RUN go build -o /out/api ./server/cmd/api

FROM alpine:3.20
WORKDIR /app
COPY --from=server-builder /out/api /app/api
COPY --from=web-builder /app/apps/admin-web/dist /app/public
CMD ["/app/api"]
```

### Compose

本地开发使用 Compose 编排：

- PostgreSQL
- Redis
- MinIO
- API
- Worker

### 环境变量

环境变量必须分类：

- 基础运行配置
- 数据库配置
- Redis 配置
- 对象存储配置
- OAuth 配置
- AI Provider 配置

禁止把默认值散落在代码与部署脚本中。

### 网络

容器网络需区分内部服务与对外暴露服务。数据库与缓存不应默认暴露公网端口。

### Volumes

持久化目录必须明确：数据库数据、MinIO 数据、日志导出、临时文件。禁止将敏感文件写入容器临时层导致重启丢失。

### 镜像分层与缓存策略

Docker 构建不只是把程序装进去，而是要为速度、安全与可重复构建服务。推荐：

1. 依赖安装层与源码拷贝层分离。
2. 前端与后端独立 builder 阶段。
3. 运行时镜像尽量只包含可执行产物与必要资源。
4. 固定基础镜像版本，不使用漂移标签。

这样可以显著提高 CI 缓存命中率，并降低镜像体积与攻击面。

### 运行时镜像原则

运行时镜像应遵循：

- 非 root 运行
- 只包含运行必要文件
- 关闭无关调试工具
- 明确入口命令
- 健康检查可外部执行

如果需要 shell 调试，应通过专用排障镜像或临时手段处理，而不是把调试工具永久留在生产镜像中。

### `.dockerignore` 规范

建议明确忽略：

- `node_modules`
- `.git`
- `dist`
- `coverage`
- `tmp`
- 本地 IDE 文件

这是最容易被忽视但收益极高的镜像优化点，可明显减少构建上下文大小。

### Compose 服务编排规范

Compose 不只是启动几个容器，更应表达本地开发依赖关系。推荐至少定义：

- `postgres`
- `redis`
- `minio`
- `api`
- `worker`
- `mailhog` 或等价本地通知模拟器

可选：

- `otel-collector`
- `grafana`
- `prometheus`

### Compose 环境分层

建议至少维护：

- `compose.base.yml`
- `compose.dev.yml`
- `compose.observability.yml`

原则：

- 基础依赖在 `base`
- 开发覆盖在 `dev`
- 可观测性增强在独立 overlay

避免一个超长 Compose 文件混合所有环境差异。

### 环境变量治理

环境变量必须遵循命名与来源规范。建议：

- 全大写蛇形命名
- 模块分组前缀清晰
- 提供 `.env.example`
- 对缺失关键变量启动即失败

示例：

```env
APP_ENV=development
HTTP_PORT=8080
POSTGRES_DSN=postgres://user:pass@postgres:5432/sass?sslmode=disable
REDIS_ADDR=redis:6379
MINIO_ENDPOINT=minio:9000
```

### 健康检查与启动顺序

Compose 场景下也不应完全依赖 `depends_on` 幻觉。建议：

- 服务自带重试连接机制
- 数据库迁移在应用启动前显式执行
- 健康检查用于观测，不替代业务层重试

### 容器日志与文件边界

容器内应尽量写标准输出日志，避免本地文件日志难以收集。只有导出产物、临时处理中间文件等才使用挂载卷，并且要有清理策略。

### Docker 反模式补充

- 把构建密钥硬编码到镜像中。
- 生产镜像使用开发模式启动参数。
- 一个镜像同时兼顾构建、测试、运行、排障所有职责。
- Compose 中所有服务共享同一环境变量文件且无边界。

### 反例

- 单阶段镜像中包含源码、构建工具与调试文件。
- Compose 中使用 `latest` 标签。
- 通过容器启动命令拼接大量配置而不做配置中心管理。

---

## 第十九章 Kubernetes 规划

### 演进前提

Kubernetes 不应在项目一开始就引入全部复杂性，但架构设计必须为其保留接口。进入 K8s 阶段通常意味着：多环境、弹性伸缩、灰度发布、运维自动化与多实例高可用成为刚需。

### Deployment / Service / Ingress

推荐拆分：

- `api-deployment`
- `worker-deployment`
- `web-service`
- `api-service`
- `ingress`

### ConfigMap / Secret

非敏感配置放 `ConfigMap`，敏感配置放 `Secret`。禁止把数据库密码、OAuth Secret、JWT Secret 写死在镜像或 Git 仓库。

### HPA

伸缩优先考虑：

- API：CPU、内存、QPS、延迟
- Worker：队列长度、任务延迟、CPU

### 参考架构

```mermaid
flowchart TD
    IN[Ingress] --> WEB[Web Service]
    IN --> API[API Service]
    API --> POD1[API Pods]
    API --> POD2[Worker Pods]
    POD1 --> PG[(PostgreSQL)]
    POD1 --> REDIS[(Redis)]
    POD2 --> REDIS
    POD1 --> MINIO[(MinIO/S3)]
```

### 最佳实践

- 就绪探针与存活探针分离。
- Worker 与 API 资源配额分开。
- 灰度发布优先由 Ingress 或 Rollout 工具控制。
- 配置变更要可审计可回滚。

### 工作负载拆分原则

Kubernetes 规划的核心不是“把容器跑起来”，而是按职责拆分工作负载。推荐至少拆成：

- Web 静态资源服务
- API 服务
- Worker 服务
- 定时任务服务
- 管理或迁移 Job

这样做的收益：

- 资源隔离更清晰
- 发布节奏更灵活
- 故障影响面更可控

### Deployment 设计建议

每个 Deployment 至少应明确：

- `replicas`
- `resources.requests`
- `resources.limits`
- `livenessProbe`
- `readinessProbe`
- `topologySpreadConstraints`
- `podDisruptionBudget`

如果没有这些基线，集群在高峰、升级或节点抖动时很容易出现隐性故障。

### Job / CronJob 规划

以下任务不应混在 API Pod 中：

- 数据迁移
- 历史清理
- 定时报表
- 审计归档
- 文件垃圾回收

应当使用 `Job` 或 `CronJob` 独立运行，并单独配置重试、超时和告警。

### 发布策略

建议在 K8s 阶段默认支持以下发布能力：

- Rolling Update
- 蓝绿发布
- 金丝雀发布
- 回滚到最近稳定版本

不同工作负载策略可不同：

- Web：更适合 CDN + 快速回滚
- API：适合 Rolling 或 Canary
- Worker：适合分批替换，避免中途丢任务

### 配置与 Secret 注入规范

推荐：

- 业务配置优先环境变量注入
- 复杂模板配置通过挂载配置文件
- Secret 使用独立命名空间或密钥管理系统
- Secret 变更需可审计

禁止：

- 在 Helm values 中明文提交生产密钥
- 多环境复用同一 Secret 值

### 伸缩策略补充

HPA 指标不应只看 CPU。更合理的是：

- API：CPU + 内存 + P95 延迟 + 错误率
- Worker：CPU + 队列积压 + 任务等待时长
- AI：并发数 + 超时率 + 成本阈值

### 命名空间与资源隔离

建议按环境至少拆分命名空间：

- `dev`
- `staging`
- `prod`

必要时进一步拆平台与业务。目的不是形式，而是：

- 权限隔离
- 配额隔离
- 变更边界清晰

### 可观测与运维接口

进入 K8s 阶段后，必须把以下能力作为默认项：

- Pod 日志可检索
- 发布记录可追踪
- 健康探针可观测
- 指标自动采集
- 失败 Pod 易于排查

### Kubernetes 反模式补充

- API、Worker、Cron 都塞进一个 Deployment。
- 没有 PDB，节点维护时业务大面积中断。
- 只配置 liveness probe，没有 readiness probe。
- 使用默认资源无限制，导致抢占和驱逐不可控。

### 反例

- 所有服务共用一个 Deployment。
- 把定时任务、Worker、API 混在同一 Pod。
- 不设置资源请求和限制。

---

## 第二十章 CI/CD

### GitHub Actions

GitHub Actions 用于实现提交校验、构建制品、镜像发布、部署流水线。流水线必须尽量声明式、可复用、可缓存。

### 自动测试

每次 PR 至少执行：

- 前端 lint
- 前端 typecheck
- 前端单元测试
- 后端 lint
- 后端单元测试
- OpenAPI 契约检查

### 自动部署

部署流程建议：

1. 合并到主干触发构建。
2. 生成版本号和镜像标签。
3. 推送镜像仓库。
4. 部署到测试环境。
5. 验证通过后手动或自动发布到生产。

### 版本管理

推荐使用语义化版本：

- `MAJOR`：破坏性变化
- `MINOR`：兼容性功能新增
- `PATCH`：兼容性修复

### 示例工作流

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint && pnpm typecheck && pnpm test
      - run: go test ./...
```

### 最佳实践

- 把生成产物、版本号、镜像标签与 Git SHA 关联。
- 部署前后执行数据库迁移检查。
- 主干必须始终可发布。
- 失败流水线不能靠人工“忽略”长期放任。

### 流水线分层

CI/CD 不应是一条巨大且难以维护的 YAML。建议按职责拆分：

- `ci-lint`
- `ci-test`
- `ci-build`
- `cd-staging`
- `cd-production`

原则：

- 校验与部署分离
- 构建产物一次生成，多环境复用
- 生产部署必须有显式门禁

### PR 门禁规范

每个 PR 至少应通过：

- 代码风格检查
- 类型检查
- 单元测试
- 后端测试
- OpenAPI/Schema 变化校验
- 关键目录所有者评审

对于基础设施、权限、租户、数据库迁移等高风险目录，建议启用 CODEOWNERS 强制评审。

### 构建产物治理

构建产物必须具有唯一性和可追溯性。推荐镜像标签策略：

- `app:1.3.0`
- `app:git-<sha>`
- `app:build-<pipeline-id>`

部署单元应明确记录：

- Git SHA
- 构建时间
- 构建流水线编号
- 数据库迁移版本

### 数据库迁移与发布顺序

CI/CD 中数据库迁移不能“顺便跑一下”。推荐顺序：

1. 校验 migration 文件合法性
2. 在测试环境预演迁移
3. 部署兼容代码
4. 执行正式迁移
5. 发布依赖新结构的逻辑

必要时采用 expand / contract 双阶段迁移，不允许破坏性 DDL 与新代码一次性强耦合上线。

### 环境策略

建议至少维护：

- 本地开发环境
- 集成测试环境
- 预发环境
- 生产环境

规则：

- 预发尽量接近生产
- 不允许把测试数据与生产配置混用
- 环境差异必须配置化，而不是脚本硬编码

### 回滚策略

每次发布都必须事先定义回滚方式，而不是线上出事再想。推荐：

- 前端静态资源：快速回滚到上一个版本
- API 镜像：通过镜像标签回滚
- 数据库变更：优先前向兼容，避免依赖回滚 DDL

### 发布审批与变更窗口

对于生产环境，建议按风险等级定义审批策略：

- 普通前端展示修复：自动或轻审批
- 后端业务逻辑变更：需要负责人审批
- 权限、租户、数据库迁移：双人审批

必要时定义冻结窗口，如财务结算日、大促期、月末高峰等。

### 测试金字塔接入流水线

流水线中的测试应按速度与价值分层：

1. 快速静态检查
2. 单元测试
3. 集成测试
4. 契约测试
5. 冒烟测试
6. 关键 E2E

不是所有测试都要在每次提交跑到极致，但必须保证关键主链路在进入生产前被验证。

### 制品安全与供应链治理

随着平台长期演进，供应链安全会越来越重要。建议逐步加入：

- 依赖漏洞扫描
- 镜像漏洞扫描
- License 合规检查
- 构建来源可追踪

### CI/CD 反模式补充

- 流水线一旦失败就临时关闭检查。
- 不同环境重复构建不同产物，导致“测试通过的不是生产上线的版本”。
- 把环境配置写死在工作流文件里。
- 线上回滚只能靠手工 SSH 登录改容器。

### 反例

- 线上构建依赖开发者手工执行命令。
- 发布不绑定版本号与提交记录。
- 不区分测试环境与生产环境配置。

---

## 第二十一章 日志监控

### 可观测性目标

可观测性的目标不是“有很多图表”，而是让团队能快速回答：哪里坏了、影响谁、从何时开始、问题在前端还是后端还是数据库、是否与某次发布有关。建议统一采用日志、指标、链路三位一体方案。

### Zap

结构化日志统一使用 Zap。前后端都应透传 `request_id` 或 `trace_id`，便于跨层关联。

### OpenTelemetry

所有关键入口必须打通 Trace：

- HTTP 请求
- 数据库查询
- Redis 调用
- 外部 HTTP 调用
- Asynq 任务执行
- AI Provider 请求

### Prometheus / Grafana / Loki

- Prometheus：采集指标
- Grafana：可视化与告警
- Loki：日志聚合
- Tempo/Jaeger：Trace 查询

### Trace / Metrics

关键指标建议包括：

- HTTP QPS、P95、P99、错误率
- SQL 慢查询数量
- Redis 命中率
- 队列堆积长度
- 文件上传失败率
- AI 请求耗时与 Token 成本

### 参考监控流

```mermaid
flowchart LR
    APP[Apps] --> OTel[OpenTelemetry]
    OTel --> PROM[Prometheus]
    OTel --> LOKI[Loki]
    OTel --> TRACE[Tempo/Jaeger]
    PROM --> GRAF[Grafana]
    LOKI --> GRAF
    TRACE --> GRAF
```

### 最佳实践

- 错误日志必须带可检索字段。
- 告警必须可行动，避免无意义噪声。
- 监控面板按业务域与平台域分层。
- 发布变更要写入注释事件，方便排障关联。

### 监控分层模型

可观测性必须按“症状、原因、上下文”分层，而不是一股脑堆指标。建议拆分为：

- 指标：用于判断系统是否异常
- 日志：用于查看异常细节
- Trace：用于串联调用链
- Event：用于记录发布、配置变更、扩容、回滚等关键事件

```mermaid
flowchart TD
    A[Metrics] --> D[Incident Analysis]
    B[Logs] --> D
    C[Trace] --> D
    E[Deploy Events] --> D
```

只有四者结合，团队才能在故障发生时快速回答“是不是这次发布导致的、影响哪个租户、瓶颈在前端还是 SQL 还是外部依赖”。

### 指标体系设计

建议从一开始就定义统一指标前缀与标签体系。至少包含：

- `service`
- `module`
- `env`
- `tenant_tier`
- `status_code`
- `method`
- `route`

注意：

- 不要把高基数用户 ID、请求 ID 直接作为指标标签
- 租户维度若数量极大，应使用分层标签而非逐租户暴露高基数时间序列

### 告警分级

建议把告警分为四级：

- `P1`：生产不可用、核心主链路中断
- `P2`：主要功能受损、多个租户明显受影响
- `P3`：局部功能异常、可降级运行
- `P4`：趋势性风险、容量或慢性问题

原则：

1. 每条告警都必须有责任人和处理动作
2. 不可行动的告警应删除或降级
3. 告警要能抑制雪崩式重复通知

### SLI / SLO 建议

建议为核心能力定义基础服务级别目标：

- API 可用性
- 登录成功率
- 核心列表接口 P95
- 导出任务成功率
- AI 请求超时率
- Webhook 投递成功率

SLO 不是摆设，它应驱动容量规划、优化优先级与发布节奏。

### 日志字段规范

结构化日志建议统一字段：

- `timestamp`
- `level`
- `service`
- `module`
- `request_id`
- `trace_id`
- `tenant_id`
- `user_id`
- `message`
- `error_code`
- `latency_ms`

统一字段的价值在于跨模块查询和可视化更稳定，避免某模块叫 `reqId`，另一模块叫 `requestId`。

### Trace 埋点策略

Trace 不应只埋 HTTP 入口。建议至少覆盖：

- Handler 入口 span
- 核心 Application Service span
- SQL span
- Redis span
- 外部 HTTP span
- Asynq 任务执行 span
- AI Provider 调用 span

复杂业务链路中，建议为关键阶段打业务语义 span，如 `customer.create.validate`、`workflow.instance.approve`。

### Dashboard 分层

Grafana 面板建议至少分四类：

- 平台总览
- 模块总览
- 依赖资源面板
- 值班排障面板

典型面板：

- API 总体延迟与错误率
- 数据库连接、慢查询、锁等待
- Redis 命中率与连接数
- 队列堆积与死信数量
- 文件上传/导出成功率
- AI 成本与超时趋势

### 发布事件与故障关联

每次发布、配置变更、扩容和数据库迁移都应写入事件流，供 Grafana/日志系统查询。这样在出现错误率峰值时，团队可以快速判断是否与变更有关。

### 监控治理反模式补充

- 只有基础设施监控，没有业务指标监控。
- 只有日志，没有 Trace，跨服务排查靠猜。
- 告警只发群消息，没有责任人和升级路径。
- 每个团队自己定义一套指标命名，最终无法统一汇总。

### 反例

- 只记录文本日志，无法按租户或请求检索。
- 只监控 CPU，不监控业务延迟与错误率。
- 链路追踪没有数据库与外部调用 span。

---

## 第二十二章 Git 规范

### Git Flow

推荐采用“主干开发 + 短分支”的简化策略：

- `main`：始终可发布
- `feature/*`：功能分支
- `fix/*`：问题修复分支
- `release/*`：大版本冻结与验收

不要为了形式引入过重的长生命周期分支模型，尤其是在前后端一体仓库中。

### Commit

提交信息建议遵循 Conventional Commits：

- `feat:`
- `fix:`
- `refactor:`
- `docs:`
- `test:`
- `chore:`
- `build:`

### Branch

分支名建议：

- `feature/crm-customer-import`
- `fix/auth-refresh-token`
- `refactor/permission-policy-engine`

### Tag / Release

版本标签应绑定发布说明、数据库迁移、关键变更列表与回滚说明。

### 最佳实践

- 一个 PR 只解决一个主要问题。
- 不允许巨大“混合变更”同时改动架构、业务、样式与重构。
- 合并前必须通过自动校验。
- 保护主干分支，禁止直接推送。

### 分支生命周期

推荐所有功能分支都短生命周期，理想状态不超过 3 天到 5 天。理由很简单：分支越长，冲突越大、上下文越旧、评审越困难。若一个需求确实较大，应该拆分为多次可独立合并的增量提交，而不是长时间挂一个超级分支。

### Commit 书写规范

提交信息建议结构：

```text
feat(crm): add customer import task flow
fix(auth): rotate refresh token on every renewal
refactor(permission): isolate scope resolver
```

规则：

- 类型必须准确
- scope 建议对应模块
- subject 使用祈使式、简洁描述
- 不要把多个不相关改动塞进同一 commit

### PR 描述规范

每个 PR 建议包含：

- 变更背景
- 改动范围
- 风险点
- 测试方式
- 是否涉及 DB migration
- 是否涉及权限、租户、审计、安全

推荐模板：

```md
## 背景
修复刷新 token 轮换不彻底问题

## 改动
- 调整 refresh token 存储策略
- 补充会话吊销逻辑

## 风险
- 影响登录续签链路

## 验证
- 单元测试
- 手工验证多设备登录
```

### Code Review 规则

Code Review 不是走流程，而是质量闸门。评审重点建议固定为：

- 是否符合模块边界
- 是否引入安全风险
- 是否破坏多租户与权限语义
- 是否补齐测试
- 是否影响迁移与兼容性

对于大改动，建议先评审设计文档，再评审代码实现。

### Rebase 与合并策略

建议主干保持线性历史，优先使用 squash merge 或 rebase merge，避免历史噪声过大。选择标准：

- 功能分支多次小提交但对外只需保留一个语义时，使用 squash
- 需要保留演进过程时，可使用 rebase merge

不建议在主干上保留大量“Merge branch x into y”噪声提交。

### Release 管理

版本发布前应至少准备：

- 版本号
- 发布说明
- 迁移说明
- 风险说明
- 回滚方案

对于影响客户可感知行为的变更，应同步准备用户公告或运营说明。

### Git 反模式补充

- 为了“快”直接往 `main` 推代码。
- 一个分支长期堆积几十个 commit 没人评审。
- PR 没有描述，只贴一句“请帮忙看下”。
- 用 force push 覆盖他人正在 review 的变更而不说明。

### 反例

- 提交信息为 `update`、`test`、`fix bug`。
- 长期不合并分支，导致冲突爆炸。
- 在一个 PR 里顺手修十几个不相干问题。

---

## 第二十三章 测试规范

### 测试金字塔

企业 SaaS 测试策略必须平衡速度、稳定性与覆盖价值。推荐结构：

- 单元测试：覆盖纯函数、领域规则、转换逻辑。
- 集成测试：覆盖仓储、数据库、Redis、对象存储适配。
- API 测试：覆盖鉴权、参数校验、错误码、契约一致性。
- E2E：覆盖关键业务链路。

### 单元测试

适用：

- 领域服务
- 权限策略判定
- 数据转换
- Prompt 模板变量渲染

### 集成测试

重点验证：

- SQL 查询正确性
- 事务边界
- 迁移兼容性
- Redis / MinIO / Asynq 适配

### API 测试

必须覆盖：

- 认证失败
- 权限拒绝
- 参数错误
- 成功路径
- 幂等场景

### E2E

E2E 应优先覆盖关键主链路：

- 登录
- 租户切换
- 列表查询
- 表单创建
- 审批流
- 导入导出

### Mock

Mock 的使用原则：

- 单元测试可广泛 Mock 边界依赖。
- 集成测试尽量少 Mock。
- E2E 仅在外部不可控系统才 Mock。

### 推荐示例

```go
func TestPolicyCanReadOwnCustomer(t *testing.T) {
    policy := NewCustomerPolicy()
    allowed := policy.CanRead(Customer{OwnerID: "u1"}, "u1")
    if !allowed {
        t.Fatalf("expected allowed")
    }
}
```

```tsx
it("renders empty state", async () => {
  server.use(http.get("/api/v1/crm/customers", () => HttpResponse.json({
    code: "OK",
    message: "success",
    data: { items: [], page: { page: 1, pageSize: 20, total: 0 } },
  })));
  render(<CustomerListPage />);
  expect(await screen.findByText("暂无数据")).toBeInTheDocument();
});
```

### 测试分层准入原则

测试不是越多越好，而是越贴近风险越有价值。推荐准入规则：

- 纯计算和规则：单元测试
- 数据访问和适配：集成测试
- 对外契约：API/契约测试
- 主业务链路：E2E

不要把本应单元测试验证的逻辑全部压到 E2E，也不要用一堆低价值单元测试制造覆盖率假象。

### 测试命名规范

测试名称应表达业务语义和预期结果，而不是仅描述函数名。推荐：

- `should_deny_access_when_user_has_no_permission`
- `returns_empty_state_when_customer_list_is_empty`
- `creates_customer_and_enqueues_welcome_job`

### 测试数据治理

测试数据必须可控、可复现、互不污染。建议：

- 使用 fixture 或 builder 模式生成数据
- 明确默认租户、默认用户、默认角色
- 测试之间不共享全局脏状态
- 集成测试优先使用临时数据库或隔离 schema

### 契约测试

前后端一体仓库也不能忽视契约测试。推荐：

- OpenAPI 变更时自动生成 SDK
- PR 中检查契约是否破坏兼容性
- 对关键外部回调接口做契约校验

这样能显著减少“前端照旧请求、后端悄悄改字段”的低级事故。

### E2E 场景选择原则

E2E 只覆盖“高价值主链路”，推荐优先级：

1. 登录与租户切换
2. 列表查询与筛选
3. 创建/编辑/删除主业务对象
4. 审批流转
5. 导入导出
6. 权限可见性与拒绝路径

不要用 E2E 覆盖所有细枝末节样式差异。

### 测试环境规范

建议至少区分：

- 本地快速测试
- CI 隔离测试
- 预发冒烟测试

规则：

- CI 环境测试必须可重复
- 不依赖人工预置数据
- 外部依赖如短信、邮件、支付需替身或沙箱

### 覆盖率使用原则

覆盖率可以看，但不能崇拜。推荐把覆盖率作为辅助指标，而不是唯一目标。比起“80% 覆盖率”，更重要的是：

- 权限链路是否覆盖
- 多租户隔离是否覆盖
- 事务边界是否覆盖
- 错误码与兼容性是否覆盖

### 测试失败处理纪律

一旦测试持续失败，必须尽快处理，不允许长期红灯。建议：

- 临时跳过测试必须带原因和恢复计划
- 同类 flaky case 超过阈值必须专项治理
- 发布前关键主链路测试必须全绿

### 测试反模式补充

- 只测 happy path，不测失败路径。
- 测试名称模糊，看不出业务意义。
- 测试数据靠多个隐式共享 fixture 叠加，维护极差。
- 为了赶进度直接删除失败测试。

### 反例

- 单元测试只断言 getter/setter。
- E2E 覆盖所有细节，导致维护成本失控。
- 没有契约测试，前后端接口变更全靠口头同步。

---

## 第二十四章 安全规范

### 总体原则

安全必须默认内建，而不是上线前“补一下”。所有模块都要遵循最小权限、默认拒绝、输入校验、输出转义、可追踪、可撤销的原则。

### XSS

- 所有富文本输出必须经过白名单清洗。
- 不允许直接渲染后端返回 HTML。
- 前端尽量依赖 React 默认转义机制，危险 HTML 必须封装统一组件。

### CSRF

对于 Cookie 会话模式必须启用 CSRF 防护；对于 Bearer Token 模式仍需防范恶意站点利用已登录上下文发起请求。

### SQL Injection

必须使用参数化查询。禁止字符串拼接 SQL，尤其是排序字段、过滤条件、IN 条件。

### JWT

- 使用强密钥或非对称签名。
- 设置短期访问过期时间。
- 支持吊销会话。
- 验证签名、算法、过期、发行方和受众。

### 权限校验

所有敏感接口都必须后端校验。权限校验结果要与业务状态校验组合使用，例如“有删除权限，但对象已归档时禁止删除”。

### 文件安全

- 校验 MIME、扩展名、大小。
- 对高风险文件做病毒扫描。
- 下载敏感文件时生成短时签名。
- 避免执行型文件被直接访问。

### 接口限流

登录、验证码、导出、Webhook、AI 调用等接口必须限流。限流是稳定性与安全性共同手段。

### 最佳实践

- 敏感配置进入 Secret 管理。
- 安全错误不要泄露内部栈信息。
- 审批、支付、导出等关键操作可引入二次确认。
- 关键权限变更需要审计与告警。

### 威胁建模

安全设计不能只列攻击名词，必须结合平台威胁面做建模。建议至少按以下对象分析：

- 身份与会话
- 多租户边界
- API 与开放平台
- 文件上传下载
- 异步任务与回调
- AI 输入输出

推荐按 STRIDE 或简化清单进行评审，输出：

- 威胁点
- 影响范围
- 当前控制措施
- 待补救措施

### 密钥与凭证治理

所有密钥、Token、三方凭证都必须生命周期化管理：

- 明确来源
- 明确用途
- 明确轮换周期
- 明确失效策略
- 明确持有范围

推荐至少覆盖：

- JWT Secret / 私钥
- OAuth Client Secret
- 数据库账号
- Redis 密码
- MinIO/S3 Access Key
- AI Provider API Key

### 多租户安全边界

多租户系统的安全核心之一就是绝不能串租户。必须在以下层面同时校验：

- 路由访问
- 业务服务
- SQL 条件
- 缓存 Key
- 文件路径
- 异步任务 payload

任何一个环节缺失，都可能造成越权读取或误操作。

### 输入校验与输出编码

推荐把输入校验分三层：

1. 协议层格式校验
2. 应用层命令合法性校验
3. 领域层业务约束校验

输出层则要注意：

- HTML 输出转义
- 文件名安全化
- 错误信息脱敏
- 日志字段截断与掩码

### 安全响应头

对于 Web 应用，建议至少配置：

- `Content-Security-Policy`
- `X-Frame-Options`
- `X-Content-Type-Options`
- `Referrer-Policy`
- `Strict-Transport-Security`

如果是多入口前端，应根据资源加载模式设计合理 CSP，而不是完全放开。

### SSRF / 命令执行 / 反序列化风险

尽管当前平台以 React + Gin 为主，仍要警惕：

- 服务端下载远程文件时的 SSRF
- 调用外部命令生成文档或转码时的命令注入
- 处理不可信 JSON/对象时的反序列化风险

原则是：

- 外部 URL 必须白名单或受控解析
- 禁止直接拼命令字符串
- 不反序列化不可信可执行对象

### 文件与导出安全

文件安全不仅是上传，还包括导出和分享。必须考虑：

- 导出文件带权限校验
- 预签名 URL 短期有效
- 敏感导出支持水印与审计
- 高风险附件进入隔离扫描

### 开放平台与 Webhook 安全

开放接口建议具备：

- 应用级凭证
- 请求签名
- 时间戳与重放防护
- 调用配额
- IP 白名单或回调域校验

Webhook 必须校验签名与重放窗口，不能只看路径正确就放行。

### AI 安全补充

AI 模块还需额外关注：

- Prompt Injection
- 工具调用越权
- 敏感内容泄露
- 非结构化输出误写数据库

推荐：

- 对工具调用做白名单与权限校验
- 对输出做 Schema 校验
- 对输入做敏感信息识别与脱敏

### 安全测试与审计

安全必须进入常规测试流程，建议至少包括：

- 权限越权测试
- 多租户串数据测试
- 上传恶意文件测试
- Webhook 重放攻击测试
- 认证失效与会话吊销测试

高风险模块建议定期执行安全 review 或渗透测试。

### 安全反模式补充

- 认为“内网系统就不需要认真做安全”。
- 只校验前端传入的租户 ID，不做服务端成员验证。
- 敏感配置同时存在于代码、环境变量和文档截图中。
- 安全修复不做回归测试，过段时间又被改回去。

### 反例

- 认为“后台系统没人攻击”。
- 只在网关做权限，不在业务服务校验。
- 文件上传后直接公开可执行访问。

---

## 第二十五章 性能优化

### 前端优化

前端优化优先级：

1. 降低不必要请求。
2. 优化首屏与关键交互。
3. 控制大列表与大表单重渲染。
4. 懒加载低频模块。

推荐措施：

- 路由级代码分割
- Query 缓存与预取
- 虚拟滚动表格
- 图表按需渲染
- 图片与附件延迟加载

### Go 优化

优化重点：

- 避免过度反射
- 控制大对象分配
- 合理复用连接池
- 明确超时与并发边界

### SQL 优化

SQL 优化原则：

- 先看执行计划，再谈重写。
- 先建正确索引，再谈缓存。
- 避免 `OFFSET` 深分页。
- 聚合与统计优先离线化或物化。

### 缓存优化

缓存优化要避免两种误区：一是无脑缓存一切，二是把缓存当最终一致性保障。缓存设计应明确命中对象、失效策略与回源成本。

### 索引优化

索引不是越多越好。每个索引都要回答“服务哪个查询、代价是什么”。对写多读多混合场景，要评估索引对写入成本的影响。

### 示例

```sql
CREATE INDEX idx_customers_tenant_status_created_at
ON crm.customers (tenant_id, status, created_at DESC)
WHERE deleted_at IS NULL;
```

### 性能优化原则

性能优化不能依赖“感觉慢了再看”，必须纳入常规工程治理。建议遵循三条底层原则：

1. 先量化，再优化。
2. 先优化主路径，再优化边缘路径。
3. 先消除结构性瓶颈，再微调实现细节。

所谓量化，至少要能回答：

- 慢的是首屏、交互、接口还是 SQL
- 是所有租户都慢，还是大租户特定场景慢
- 是发布后回归，还是数据增长导致

### 性能预算

建议为核心链路定义性能预算，否则优化会永远停留在口头层面。可参考：

- 首屏可交互时间
- 列表筛选响应时间
- 详情页首屏关键数据响应时间
- 写操作 P95
- 导入导出任务平均完成时长
- AI 请求超时率

性能预算应进入发布验收，而不是只在性能测试报告里存在。

### 前端优化补充

前端性能优化建议按层处理：

- 资源层：代码分割、按需加载、压缩与缓存
- 数据层：Query 预取、去重请求、分页与增量加载
- 渲染层：减少不必要重渲染、表格虚拟化、图表懒渲染
- 体验层：骨架屏、局部加载、交互优先反馈

对于后台系统，列表和表单通常比首页营销式首屏更值得优先优化。

### Go 服务优化补充

后端优化的高价值项通常包括：

- 明确超时边界
- 避免无界 goroutine
- 限制大对象 JSON 编解码
- 复用数据库与 HTTP 连接池
- 减少无意义日志拼装与反射

性能问题若已涉及锁竞争、GC 压力、热点对象分配，应使用 profiling 工具而不是靠猜测修改。

### SQL 与数据访问优化补充

数据库往往是企业系统性能瓶颈的主要来源。推荐实践：

- 关键查询上线前看 `EXPLAIN ANALYZE`
- 热点列表必须验证索引命中
- 大偏移量分页及时切换游标分页
- 聚合类分析使用物化视图或离线任务
- 复杂查询与事务写路径分离

### 缓存优化补充

缓存优化的关键不在“有没有缓存”，而在：

- 缓存是否命中了真正高频热点
- 失效策略是否合理
- 是否因为缓存引入了更高复杂度

推荐顺序：

1. 先减少无效查询
2. 再优化 SQL 与索引
3. 最后为稳定热点加缓存

### 性能测试与压测策略

建议至少建立三类性能验证：

- 接口基准测试：单接口延迟与吞吐
- 核心链路压测：登录、列表、创建、审批
- 异步任务压测：导入、导出、AI、Webhook

压测结论必须包括：

- 压测数据规模
- 并发量
- 数据库与缓存资源曲线
- 错误率与超时率
- 结论与瓶颈位置

### 性能问题治理流程

推荐统一流程：

```mermaid
flowchart TD
    A[发现慢点] --> B[采集指标与日志]
    B --> C[定位瓶颈层级]
    C --> D[制定优化方案]
    D --> E[压测验证]
    E --> F[上线观察]
```

### 性能反模式补充

- 没有监控与基线就直接“优化”。
- 页面卡顿先怪后端，后端慢先怪数据库，没有证据链。
- 一个慢查询还没修复，就先加三层缓存掩盖问题。
- 大租户问题不做分层治理，直接影响全体租户体验。

### 反例

- 列表页每次切换筛选都全量重新加载相关字典。
- 表格 5000 行不分页不虚拟化。
- 没有索引就先上 Redis。

---

## 第二十六章 开发规范

### 代码风格

代码风格的目标是降低认知负担，而不是体现个人习惯。推荐统一：

- 前端：ESLint + TypeScript 严格模式 + Prettier
- 后端：`gofmt` + `golangci-lint`

### 命名规范

- 变量名表达业务含义，不用 `data`、`info`、`temp`。
- 布尔值使用可读前缀，如 `isActive`、`hasPermission`。
- 接口/函数命名体现动作与对象。

### 注释规范

注释应解释“为什么”，而不是机械解释“做了什么”。复杂规则、边界条件、历史兼容原因、性能权衡适合写注释。

### 接口规范

函数签名保持小而稳，避免多个布尔参数控制分支。推荐使用命令对象或选项对象。

### 异常规范

异常必须沿调用链保持语义，日志中保留技术原因，对外返回稳定错误码。不要吞错，不要裸 `panic`。

### 团队开发约定

开发规范的价值不只是让代码“更好看”，而是降低团队协作摩擦。建议统一约定以下内容：

- 新增模块必须遵循既定目录结构
- 新增接口必须补 OpenAPI
- 新增权限必须补资源注册
- 新增数据库迁移必须写风险说明
- 新增高风险功能必须补测试与审计说明

### 命名分层建议

推荐按层使用不同命名习惯：

- 领域实体：业务名词，如 `Customer`、`Workspace`
- 应用服务：动作 + 对象，如 `CreateCustomerService`
- Hook：`use` + 能力
- DTO：`CreateCustomerRequest`
- Query Key：`customerKeys.list`

目的是让人一眼知道对象处于哪个层次，而不是所有东西都叫 `DataService` 或 `InfoManager`。

### 代码可读性规则

建议开发者在提交前自检：

1. 不看上下文能否理解函数目的
2. 函数是否超过合理长度
3. 是否存在多层嵌套且缺少提前返回
4. 变量名是否表达真实语义
5. 是否把复杂条件封装成具名函数

### 注释使用边界

注释不是越多越好。推荐写注释的场景：

- 业务规则不直观
- 历史兼容原因
- 性能权衡
- 安全边界
- 非显然的临时方案及后续计划

不推荐写：

- “给变量赋值”
- “调用函数获取数据”
- 与代码重复的注释

### 函数与模块复杂度控制

建议设定软性规则：

- 单函数过长应拆分
- 参数超过 4 个时考虑对象化
- 多个布尔参数应改为配置对象或枚举
- 巨型工具类与 `common` 目录应被严格限制

### 代码生成与手写边界

要明确哪些内容适合生成，哪些必须手写：

- 适合生成：SDK、Schema、类型定义、部分脚手架
- 必须手写：领域规则、业务编排、权限判定、核心页面逻辑

否则项目会逐渐变成“到处都是生成代码和复制代码”的混合体。

### 开发规范检查清单

PR 提交前建议自检：

- 是否符合命名规范
- 是否引入未审计的新配置
- 是否包含无意义注释或调试代码
- 是否遗漏错误处理
- 是否符合所在层级职责

### 开发反模式补充

- 出现问题就往 `utils` 里塞函数。
- 所有复用都抽象，结果抽出大量没人理解的中间层。
- 为了快，在代码中保留临时开关但不加说明。
- 业务常量、错误码、权限码散落在各处字符串中。

### 反例

- 一个函数 8 个参数，其中 3 个布尔值。
- 注释写“给变量赋值”。
- 公共函数名叫 `HandleData`、`ProcessInfo`。

---

## 第二十七章 SaaS 最佳实践

### 多租户

多租户的本质是“共享平台能力 + 隔离业务与资源边界”。最佳实践包括：

- 配置分层：平台默认、套餐默认、租户覆盖、工作区覆盖。
- 能力收敛：权限、组织、审计、文件、流程作为平台能力。
- 数据隔离：从数据库、缓存、对象路径、日志到分析都带租户语义。

### 开放平台

开放平台不是简单给 API 文档，而是一个完整生态体系，包括应用注册、凭证管理、权限授权、回调订阅、调用配额、审计与开发者文档。

### 插件系统

插件系统建议采用“声明扩展点 + 受控能力暴露 + 沙箱或边界约束”。插件必须回答：

- 能扩展什么
- 运行在何处
- 能访问哪些数据
- 失败如何隔离

### API

API 最佳实践是“内部接口平台化、外部接口产品化”。内部接口可快演进，外部接口必须长期稳定、有迁移策略与开发者支持。

### Webhook

Webhook 是开放平台的重要组成。必须提供：

- 事件目录
- 签名机制
- 重试策略
- 回放能力
- 日志查询

### 国际化

国际化不是翻译层，而是产品能力层。需要考虑：

- 语言
- 时区
- 数字格式
- 日期格式
- 法务文案
- 区域化身份源接入

### AI

AI 的 SaaS 最佳实践是“受控接入、业务闭环、可审计、可计费、可回退”。AI 结果必须被纳入正常业务流程，而不是游离在系统外。

### 配置分层最佳实践

SaaS 平台最常见的长期复杂度来源，是配置层次失控。推荐统一配置优先级：

1. 平台默认配置
2. 套餐默认配置
3. 租户配置
4. 工作区配置
5. 用户个性化配置

治理原则：

- 同一配置项只能有一条主生效链
- 配置变更需审计
- 配置冲突必须有显式优先级

### 平台能力收敛

真正的 SaaS 最佳实践不是“模块越多越强”，而是平台能力足够收敛。优先平台化的能力包括：

- 身份与会话
- 组织与权限
- 审计与日志
- 文件与导出
- 流程与消息
- AI 与知识库

业务模块应尽量站在这些能力之上构建，而不是各自再实现一遍。

### 大客户定制策略

面对大客户需求时，建议优先级如下：

1. 配置化
2. 权限与流程差异
3. 插件与扩展点
4. 最后才是租户级代码特化

如果平台过早接受大量租户分支代码，最终会丧失统一升级与统一测试能力。

### 开放平台最佳实践

开放平台要成为产品，而不是几个接口。建议提供：

- 开发者接入文档
- 应用注册与审核
- 凭证管理
- 事件订阅
- 调试工具
- 调用日志与错误分析

### 插件系统最佳实践

插件体系必须以扩展点为中心，而不是以“任意执行代码”为卖点。建议：

- 插件声明能力边界
- 插件运行上下文受控
- 插件数据访问需授权
- 插件故障可隔离
- 插件版本兼容可管理

### 国际化最佳实践

国际化不只是翻译文案，还涉及：

- 时区计算
- 金额与数字格式
- 日期格式
- 文件与报表语言
- 区域化身份源与合规策略

如果这些不统一规划，国际化会从“多语言”退化为“只多一套翻译文件”。

### SaaS 核心经营指标

建议平台层长期关注：

- 活跃租户数
- 付费租户数
- 功能使用渗透率
- API 调用量
- 导出与文件存储量
- AI Token 消耗与成本
- 租户异常率与告警量

工程系统最终还是服务于经营目标，这也是 SaaS 与普通内部系统的重要区别。

### SaaS 反模式补充

- 平台能力没有收敛，模块各自实现权限、文件、日志。
- 大客户一提需求就开一套分支。
- 开放平台只有接口，没有应用管理、签名和回调治理。
- 国际化只翻译前端，不处理后端报表、时间和数字格式。

### 反例

- 把所有租户差异都做成分支代码。
- 插件可以直接访问数据库。
- 没有事件版本管理就开放 Webhook。

---

## 第二十八章 项目路线图

### V1

V1 目标是建立可运营的标准平台底座，包含：

- 多租户与工作区
- 用户、组织、角色、权限
- CRM 基础能力
- 文件管理
- 审计日志
- OpenAPI 基础能力
- AI Provider 接入基础版

### V2

V2 重点是平台能力中心化与业务增强：

- Workflow 引擎
- 插件与扩展点
- 高级报表
- Webhook 平台
- 多身份源单点登录
- 向量检索与知识库

### V3

V3 重点是生态化与规模化：

- 开发者平台
- 应用市场
- 高级租户配额与计费
- 局部服务化
- 多区域部署
- 高级监控与成本治理

### 微服务演进

微服务不是目标，而是结果。当以下条件出现时，可以考虑拆分：

- 模块边界稳定三个月以上
- 团队需要独立发布节奏
- 计算与流量模式显著不同
- 数据所有权可明确分割

优先拆分候选：

- AI 模块
- Webhook/集成模块
- 导入导出与报表模块
- 搜索与全文检索模块

### 路线图图示

```mermaid
flowchart LR
    V1[统一平台底座] --> V2[能力中心化]
    V2 --> V3[生态化与服务化]
    V3 --> M[局部微服务]
```

### 路线图制定原则

项目路线图必须同时平衡三类目标：

- 业务交付
- 平台沉淀
- 风险控制

如果路线图只追求业务功能，很快会陷入基础能力债务；如果只追求平台化，则容易错失业务窗口。建议每个阶段都至少包含：

- 可见业务成果
- 一项平台能力沉淀
- 一项质量或风险治理目标

### V1 实施重点

V1 阶段最重要的不是功能数量，而是建立统一骨架。必须优先完成：

- 统一 Monorepo
- 统一认证与租户上下文
- 统一权限与审计
- 统一 API 与错误码
- 统一数据库迁移与部署流程

没有这些基础，后续任何新模块都会放大混乱。

### V2 实施重点

V2 阶段建议开始把“重复出现的通用逻辑”平台化，而不是继续纯业务堆叠。重点包括：

- 工作流能力沉淀
- 文件、导出、通知等中台能力
- AI 场景从实验走向平台化
- 开放平台和 Webhook 体系

### V3 实施重点

V3 阶段开始进入规模治理与生态化建设，重点不再只是内部系统可用，而是：

- 多团队协作
- 多环境/多区域部署
- 开发者生态
- 高级计费与配额
- 成本治理与可观测升级

### 架构演进判定信号

建议把以下信号作为是否升级架构的触发条件：

- 单体发布窗口持续过长
- 某模块资源模型与其他模块显著不同
- 某类任务严重影响主业务链路
- 团队边界已经稳定并需要独立节奏

不要因为“大家都在上微服务”而提前拆分。

### 里程碑验收模板

建议每个路线图阶段都使用统一验收模板：

- 目标范围
- 成功指标
- 风险项
- 非目标项
- 发布条件
- 回滚条件

这样路线图就不只是愿景清单，而是可以执行和验收的计划。

### 路线图风险治理

每个阶段都应显式记录风险：

- 人员与组织风险
- 架构复杂度风险
- 成本风险
- 安全与合规风险
- 兼容性风险

路线图不是承诺“只会更好”，而是提前承认风险并制定缓冲方案。

### 最终收口建议

当整本手册进入团队执行阶段后，建议再配套三类资产：

- 架构评审清单
- 新模块脚手架
- 研发入职手册

只有文档、模板、流程三者同时存在，这本规范才会真正从“文档”变成“组织能力”。

### 结语

一套真正可持续的 SaaS 开发规范，不在于把技术名词列满，而在于把“边界、约束、协作、质量、风险、演进”变成团队每天可执行的默认行为。本规范的核心精神可以浓缩为六句话：

1. 先定边界，再写功能。
2. 先建约定，再谈自由。
3. 先保可维护，再追新技术。
4. 先做平台能力，再做租户差异。
5. 先做审计与安全，再做增长。
6. 先演进架构，再拆分系统。

如果团队能够长期坚持这六条原则，那么无论是 React 前端、Gin 后端、PostgreSQL 数据层，还是未来的 AI、插件、开放平台与微服务演进，都将建立在一个稳固、可扩展、可继承的工程基础之上。


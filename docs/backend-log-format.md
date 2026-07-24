# 后端日志格式规范

> 基于《React + Gin + PostgreSQL SaaS 平台开发规范》中的后端规范整理。
> 覆盖章节：第5章 Go 开发规范 - Logger、第15章 审计日志、第21章 日志监控、第13章 异步任务。

---

## 一、应用运行日志（Zap 结构化日志）

文档要求统一使用 **Zap** 输出结构化 JSON，强制字段见第5章 Logger 节及第21章日志字段规范。

### 1.1 请求入口日志（AccessLog 中间件）

```json
{
  "timestamp": "2026-07-08T10:23:45.123+08:00",
  "level": "INFO",
  "service": "sass-api",
  "module": "http",
  "request_id": "req_c9x8a7b6d5e4",
  "trace_id": "trace_f3a2b1c0d9e8",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "user_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "method": "POST",
  "path": "/api/v1/crm/customers",
  "status": 201,
  "latency_ms": 87,
  "client_ip": "10.0.1.25",
  "user_agent": "Mozilla/5.0 ...",
  "message": "request completed"
}
```

### 1.2 业务操作日志（Application Service 内）

```json
{
  "timestamp": "2026-07-08T10:23:45.110+08:00",
  "level": "INFO",
  "service": "sass-api",
  "module": "crm",
  "action": "customer.create",
  "request_id": "req_c9x8a7b6d5e4",
  "trace_id": "trace_f3a2b1c0d9e8",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "user_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "target_type": "customer",
  "target_id": "0192a8b7-d4e3-4c2b-a1f0-e9d8c7b6a5f4",
  "latency_ms": 42,
  "message": "customer created successfully"
}
```

### 1.3 错误日志（ERROR 级别）

```json
{
  "timestamp": "2026-07-08T10:23:46.500+08:00",
  "level": "ERROR",
  "service": "sass-api",
  "module": "crm",
  "action": "customer.create",
  "request_id": "req_c9x8a7b6d5e4",
  "trace_id": "trace_f3a2b1c0d9e8",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "user_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "error_code": "CRM_CUSTOMER_DUPLICATED",
  "error_message": "customer name already exists within tenant",
  "latency_ms": 15,
  "message": "domain rule violation"
}
```

### 1.4 数据库慢查询日志

```json
{
  "timestamp": "2026-07-08T10:23:47.800+08:00",
  "level": "WARN",
  "service": "sass-api",
  "module": "database",
  "request_id": "req_a1b2c3d4e5f6",
  "trace_id": "trace_7a8b9c0d1e2f",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "query": "SELECT id, tenant_id, name, status FROM crm.customers WHERE tenant_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC",
  "latency_ms": 1250,
  "rows_affected": 200,
  "message": "slow query detected"
}
```

### 1.5 异常/Panic 恢复日志（Recovery 中间件）

```json
{
  "timestamp": "2026-07-08T10:23:50.000+08:00",
  "level": "FATAL",
  "service": "sass-api",
  "module": "http",
  "request_id": "req_p9q8r7s6t5u4",
  "trace_id": "trace_v3w2x1y0z9a8",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "user_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "panic": "runtime error: invalid memory address or nil pointer dereference",
  "message": "panic recovered"
}
```

---

## 二、审计日志（持久化到 PostgreSQL `audit_logs` 表）

审计日志与运行日志分离，持久化存储，不可被普通管理员篡改。

### 2.1 登录审计

```json
{
  "event_id": "0192a8b7-f6e5-d4c3-b2a1-f0e9d8c7b6a5",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "operator_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "module": "iam",
  "action": "user.login",
  "target_type": "session",
  "target_id": "0192a8b7-e5d4-c3b2-a1f0-e9d8c7b6a5f4",
  "result": "success",
  "source_type": "web",
  "source_id": "req_c9x8a7b6d5e4",
  "request_id": "req_c9x8a7b6d5e4",
  "trace_id": "trace_f3a2b1c0d9e8",
  "snapshot_before": null,
  "snapshot_after": {
    "login_method": "password",
    "device": "Chrome/Windows",
    "ip": "203.0.113.42",
    "region": "Beijing"
  },
  "created_at": "2026-07-08T10:23:45.000+08:00"
}
```

### 2.2 业务操作审计（含字段级差异摘要）

```json
{
  "event_id": "0192a8b7-d4e3-4c2b-a1f0-e9d8c7b6a5f4",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "operator_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "module": "crm",
  "action": "customer.update",
  "target_type": "customer",
  "target_id": "0192a8b7-b1a2-c3d4-e5f6-a7b8c9d0e1f2",
  "result": "success",
  "source_type": "web",
  "source_id": "req_d3e4f5a6b7c8",
  "request_id": "req_d3e4f5a6b7c8",
  "trace_id": "trace_1a2b3c4d5e6f",
  "changes": [
    { "field": "status", "before": "active", "after": "archived" },
    { "field": "owner_id", "before": "u_01", "after": "u_09" }
  ],
  "snapshot_before": null,
  "snapshot_after": null,
  "created_at": "2026-07-08T10:30:12.000+08:00"
}
```

### 2.3 高风险操作审计（含脱敏前后快照）

```json
{
  "event_id": "0192a8b7-c3d4-e5f6-a7b8-c9d0e1f2a3b4",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "operator_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "module": "iam",
  "action": "member.role.change",
  "target_type": "tenant_member",
  "target_id": "0192a8b7-aaaa-bbbb-cccc-ddddeeeeffff",
  "result": "success",
  "source_type": "web",
  "source_id": "req_f1e2d3c4b5a6",
  "request_id": "req_f1e2d3c4b5a6",
  "trace_id": "trace_9z8y7x6w5v4u",
  "changes": [
    { "field": "roles", "before": ["sales_rep"], "after": ["sales_manager"] }
  ],
  "snapshot_before": {
    "member_status": "active",
    "roles": ["sales_rep"],
    "workspace_ids": ["ws_01"]
  },
  "snapshot_after": {
    "member_status": "active",
    "roles": ["sales_manager"],
    "workspace_ids": ["ws_01"]
  },
  "created_at": "2026-07-08T11:00:00.000+08:00"
}
```

### 2.4 失败操作审计

```json
{
  "event_id": "0192a8b7-9f8e-7d6c-5b4a-3f2e1d0c9b8a",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "operator_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "module": "crm",
  "action": "customer.export",
  "target_type": "export_task",
  "target_id": null,
  "result": "failure",
  "source_type": "web",
  "source_id": "req_7g8h9i0j1k2l",
  "request_id": "req_7g8h9i0j1k2l",
  "trace_id": "trace_m3n4o5p6q7r8",
  "error_code": "PERMISSION_DENIED",
  "changes": null,
  "snapshot_before": null,
  "snapshot_after": null,
  "created_at": "2026-07-08T11:15:30.000+08:00"
}
```

---

## 三、异步任务日志（Asynq Worker）

### 3.1 任务执行成功日志

```json
{
  "timestamp": "2026-07-08T10:24:00.500+08:00",
  "level": "INFO",
  "service": "sass-worker",
  "module": "crm",
  "task_id": "task_d4e5f6a7b8c9",
  "task_type": "crm:customer.import",
  "queue": "default",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "operator_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b5",
  "attempt": 1,
  "max_retries": 3,
  "latency_ms": 3200,
  "result": "success",
  "message": "task completed: 500 customers imported"
}
```

### 3.2 任务重试日志

```json
{
  "timestamp": "2026-07-08T10:24:05.200+08:00",
  "level": "WARN",
  "service": "sass-worker",
  "module": "integration",
  "task_id": "task_a1b2c3d4e5f6",
  "task_type": "webhook:deliver",
  "queue": "webhook",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "operator_id": null,
  "attempt": 2,
  "max_retries": 5,
  "latency_ms": 30100,
  "result": "retrying",
  "error_code": "WEBHOOK_TIMEOUT",
  "message": "webhook delivery timeout, will retry after backoff"
}
```

### 3.3 任务死信日志

```json
{
  "timestamp": "2026-07-08T10:30:00.000+08:00",
  "level": "ERROR",
  "service": "sass-worker",
  "module": "integration",
  "task_id": "task_a1b2c3d4e5f6",
  "task_type": "webhook:deliver",
  "queue": "webhook",
  "tenant_id": "0192a8b7-c6d5-4e4f-a3b2-c1d0e9f8a7b6",
  "operator_id": null,
  "attempt": 5,
  "max_retries": 5,
  "latency_ms": 30100,
  "result": "dead",
  "error_code": "WEBHOOK_EXHAUSTED",
  "message": "task moved to dead letter queue after 5 failed attempts"
}
```

---

## 四、日志字段汇总

根据文档规范，以下是所有日志模版中应统一的字段字典。

### 4.1 运行日志通用字段

| 字段 | 来源 | 说明 |
|------|------|------|
| `timestamp` | 第21章 日志字段规范 | ISO 8601 格式时间戳 |
| `level` | 第21章 + 第15章异常日志 | `DEBUG` / `INFO` / `WARN` / `ERROR` / `FATAL` |
| `service` | 第21章 日志字段规范 | 服务名，如 `sass-api` / `sass-worker` |
| `module` | 第5章 Logger | 领域模块，如 `crm` / `iam` / `workflow` |
| `action` | 第5章 Logger | 业务动作，如 `customer.create` |
| `request_id` | 第5章 + 第21章 | 请求唯一 ID（RequestID 中间件生成） |
| `trace_id` | 第5章 + 第21章 | 链路追踪 ID（OpenTelemetry 透传） |
| `tenant_id` | 第5章 + 第21章 | 租户 ID（所有日志必备） |
| `user_id` | 第5章 + 第21章 | 操作人 ID |
| `error_code` | 第5章 错误码分层 + 第21章 | 稳定字符串错误码，如 `CRM_CUSTOMER_DUPLICATED` |
| `latency_ms` | 第5章 + 第21章 | 操作耗时（毫秒） |
| `message` | 第21章 | 人类可读的日志摘要 |

### 4.2 审计日志（持久化）额外字段

| 字段 | 来源 | 说明 |
|------|------|------|
| `event_id` | 第15章 审计事件模型 | 审计事件唯一 ID |
| `operator_id` | 第15章 | 操作人 ID（审计语境） |
| `target_type` | 第15章 | 操作目标类型，如 `customer` |
| `target_id` | 第15章 | 操作目标 ID |
| `result` | 第15章 | `success` / `failure` |
| `source_type` | 第15章 审计来源分类 | `web` / `api` / `system` / `worker` / `integration` / `plugin` |
| `source_id` | 第15章 | 来源标识（如 request_id） |
| `changes` | 第15章 快照与差异摘要 | 字段级差异数组 `[{field, before, after}]` |
| `snapshot_before` | 第15章 | 高风险操作的脱敏前快照 |
| `snapshot_after` | 第15章 | 高风险操作的脱敏后快照 |

### 4.3 异步任务额外字段

| 字段 | 来源 | 说明 |
|------|------|------|
| `task_id` | 第13章 任务可观测性 | 任务唯一 ID |
| `task_type` | 第13章 | 任务类型，如 `crm:customer.import` |
| `queue` | 第13章 | 队列名称 |
| `attempt` | 第13章 | 当前重试次数 |
| `max_retries` | - | 最大重试次数 |
| `result` | 第13章 | `success` / `retrying` / `dead` |

---

## 五、规范要点

1. **统一使用 Zap**：所有后端日志必须使用 Zap 输出结构化 JSON，禁止纯文本日志。
2. **强制租户字段**：所有日志必须包含 `tenant_id`，确保多租户场景下的日志可检索。
3. **链路可追踪**：`request_id` + `trace_id` 贯穿所有日志，实现前后端跨层关联。
4. **审计与运行日志分离**：审计日志持久化到 PostgreSQL `audit_logs` 表，不可被普通管理员篡改；运行日志输出到标准输出，由 Loki 聚合。
5. **错误码稳定可检索**：错误码使用稳定字符串编码（如 `CRM_CUSTOMER_DUPLICATED`），而非数字码或中文消息。
6. **敏感信息脱敏**：日志中禁止记录明文密码、Token、身份证号等敏感信息。
7. **异步任务独立观测**：每个任务执行记录 `task_id`、`task_type`、`attempt`、`result`，并暴露队列堆积、成功率等指标。
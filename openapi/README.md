# 跨模块接口契约（`openapi/`）

**本目录是全组唯一的跨模块接口权威来源。**

---

## 铁律

1. **先改契约，再改代码。** 顺序颠倒的 PR 一律打回。
2. **调用方 + 提供方共同批准。** CODEOWNERS 已配置，GitHub 会强制。
3. **CI 会拦截。** 改了本目录但 PR 没有 `contract-approved` 标签 → 直接红灯。
4. **禁止另起炉灶。** 不得绕过本目录私自定义跨模块调用方式。

---

## 文件清单

| 文件 | 子域 | 提供方 | 调用方 | 状态 |
|---|---|---|---|---|
| `common.yaml` | 共享字典 | 全组 | 全部 | 草案，待 A 确认 |
| `m1-seat-restriction.yaml` | M1 | B | C、D | **已冻结** |
| `d-auth.yaml` | D-001 | A | M1/M2/M3、前端 | 草案，待 A 确认 |
| `d-space-master-data.yaml` | D-002 | E | M1、M2 | 草案，待 E 确认 |
| `d-notification.yaml` | D-003 | C | M1/M2/M3 | 草案，待 C 确认 |
| `d-audit.yaml` | D-004 | D | M1/M2/M3 | 草案，待 D 确认 |
| `d-config-parameter.yaml` | D-005 | A | M1/M2/M3 | 草案，待 A 确认 |

---

## 五份 d-* 草案的来历

这五份由 B 起草，**目的不是代替负责人设计，而是给出一个可评审的具体形状**。

对照"没有契约"的状态，差别在于：

- 没有契约：各人自己定路径和字段，联调时才发现对不上
- 有草案：负责人只需回复"确认"或"改这个字段"，五分钟就能定

**确认流程**：子域负责人确认（可改字段）→ 加 `contract-approved` 标签 → 状态改为 FROZEN → 双方按此实现。

**注意：草案中标了 `x-` 前缀的区块（如 `x-required-parameter-keys`、`x-routing-convention`）是说明性内容，不参与接口校验，供实现参考。**

---

## 命名与路径约定

```
/api/m1/**   M1 座位预约
/api/m2/**   M2 整教室审批
/api/m3/**   M3 报修工单
/api/d/**    公共层（RBAC / 主数据 / 通知 / 审计 / 参数）
```

Nginx 按前缀转发。**两个模块不可能写出同名路径。**

---

## 通用约定

所有跨模块接口共享以下约定，详见 `common.yaml`：

- 认证：`Authorization: Bearer <jwt>`，`claims` 结构见 `JwtClaims`
- 幂等：`X-Idempotency-Key: <sourceType>:<sourceId>:<ACTION>`，仅做日志关联，**判定靠数据库唯一约束**
- 追踪：`X-Trace-Id`，服务端必须原样回填到错误响应的 `traceId`
- 时间：UTC ISO 8601 带 `Z`
- 主键：UUID（带 pattern 硬校验）
- 错误：一律 `ErrorResponse`（`code` / `message` / `traceId`），`code` 取 `ErrorCode` 枚举值
- **复用：`ErrorResponse` / `TraceId` / `IdempotencyKey` / `Role` 等通用结构，一律用
  `$ref: './common.yaml#/components/...'` 引用，禁止在本目录其他契约里复制粘贴一份**

> **为什么必须外部引用**：改一次 `common.yaml`，全部契约跟着生效。
> 若各自复制一份，加一个错误码要改 6 个文件，必有人漏改，而且 CI 查不出来。
>
> **唯一例外**：`m1-seat-restriction.yaml` 的 `IdempotencyKey` 刻意收窄为 `M2|M3` ——
> 该接口只被 M2（审批）与 M3（报修）调用，M1 不会调用自己。文件内已注明，不是漏改。

---

## 变更流程

```
提变更 Issue（原因 / 影响范围 / 迁移方式 / 回退方案）
      ↓
调用方负责人 + 提供方负责人评审批准
      ↓
修改本目录的 yaml
      ↓
负责人加 contract-approved 标签 → CI 放行
      ↓
再改各自服务的代码
```

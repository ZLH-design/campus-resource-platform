# d-service 公共层 —— 模块约束

> schema：`common` ｜ Flyway 段：`V4xx__` ｜ URL 前缀：`/api/d/**`
> 上级约束见根目录 `AGENTS.md`。

**注意：本服务由多人共建，按子域划分权限，不归一个人。**

| 子域 | 需求 | 负责人 | 状态 |
|---|---|---|---|
| 身份与 RBAC | D-001 | **A** | ⬜ 未定义 |
| 空间/座位主数据 | D-002 | **E** | ⬜ 未定义 |
| 统一通知 | D-003 | **C** | ⬜ 未定义 |
| 审计 | D-004 | **D** | ⬜ 未定义 |
| 业务参数 | D-005 | **A** | ⬜ 未定义 |

**一个 PR 只改自己那个子域，改之前看 CODEOWNERS。**

---

## 1. 共享字典在这里

子域负责人请先看 `openapi/common.yaml`，有你要的枚举：

| 子域 | 已拟好的枚举 | 确认人 |
|---|---|---|
| D-001 | `Role`（8 个，含 `APPROVER_DEPT` / `APPROVER_UNIVERSITY`）、`JwtClaims`（`sub`/`roles`/`dept`/`exp`） | A |
| D-002 | `Uuid`、`UtcDateTime` | E |
| D-003 | `NotificationType`（7 个） | C |
| D-004 | `AuditAction`（8 个） | D |

**这些字典归公共层，改了要全组批准。各业务模块只能引用，不许自建。**

---

## 2. D-001 身份与 RBAC —— A

要求：

- JWT 鉴权 + RBAC 权限判断
- **无权限返回 403，不能默认放行**
- 权限规则必须可配置，不许写死在业务代码里
- 本轮不做复杂权限配置界面，只要"规则可配置 + 拒绝生效"

**待决（PD-001）：四个服务如何校验 JWT？**

| 方案 | 取舍 |
|---|---|
| 共享密钥 | 最简单，密钥轮换麻烦 |
| **JWKS 端点** | 标准做法，Spring Security OAuth2 Resource Server 原生支持 |
| 内省端点 | 最安全，每次请求多一跳 |

建议 JWKS。**这条不定，四个服务会各写一套，合并时必炸。**

---

## 3. D-002 空间与座位主数据 —— E

**这是卡住 B 的那一项，优先做。**

建议接口：

```
GET /api/d/rooms
  过滤：building / floor / hasSocket / openFrom / openTo
  返回：id、name、building、floor、openFrom、openTo、status

GET /api/d/rooms/{roomId}/seats
  过滤：hasSocket
  返回：seatId、seatNo、hasSocket
```

教室需要字段：`id` `name` `building` `floor` `open_from` `open_to` `status`

验收标准（需求基线 D-002）：教室与座位有稳定唯一 ID；**注销数据不能继续用于新业务** —— 所以要有 `status` 表示注销，注销的不返回给调用方。

**边界（ADR-001，待 E 与 A 确认）**：本模块**只管静态属性与永久状态**，
`status` 取值 `ACTIVE` / `CLOSED`，**不含 `MAINTENANCE`**。
维修等时段性不可用由 M3 写入 M1 的 `seat_restriction`，不进主数据。
因此本模块**只提供读接口，不提供状态写接口**。

完整论证见 `openapi/d-space-master-data.yaml` 末尾 `x-decision-log` → ADR-001。

---

## 4. D-003 统一通知 —— C

建议接口：

```
POST /api/d/notifications
{
  "type": "BOOKING_APPROVED",
  "recipientId": "<UUID>",
  "content": "...",
  "bizRef": { "sourceType": "M2", "sourceId": "<UUID>" }
}
```

按 §7.2：v0.1 **只实现站内通知表 + 控制台发送器**。邮件渠道列入后续迭代。
业务模块只调统一接口，不绑定具体渠道。

---

## 5. D-004 审计 —— D

建议接口：

```
POST /api/d/audit-events
{
  "action": "TICKET_STATUS_CHANGE",
  "operatorId": "<UUID>",
  "objectType": "REPAIR_TICKET",
  "objectId": "<UUID>",
  "result": "SUCCESS",
  "traceId": "..."
}
```

必须记录的行为（§7.2）：登录、权限变更、审批、工单状态变化、预约取消、系统参数修改。

**两条硬要求：**审计记录不可被普通用户修改；**不得承载业务逻辑**（见 INT-003）。

---

## 6. D-005 业务参数 —— A

**这是卡住 B 的第二项。**

建议接口：

```
GET /api/d/parameters/{key}
200 → { "key": "...", "value": "...", "type": "INTEGER" }
```

必预置的默认值：

| key | 默认值 |
|---|---|
| `RESERVATION_MAX_DURATION_HOURS` | 4 |
| `RESERVATION_REMINDER_MINUTES` | 15 |
| `CHECKIN_REMINDER_MINUTES` | 10 |
| `CHECKIN_TIMEOUT_MINUTES` | 15 |

**参数变更必须写审计。** 业务方必须在代码中走接口读参数，不得写死常量。

---

## 7. 公共层红线

- `common` schema **只放主数据与公共能力，不放业务表**
- **业务规则不许下沉到公共层**（INT-003 明确禁止）
- 其他三个服务的账号**不能访问 `common`**，只有 d 账号能读写
- 公共层变更 MR 需要公共子域负责人 + 至少一个使用方负责人批准

---

## 正式契约文件已起草

以上五个子域的接口已分别落成可评审的 yaml，位于 `openapi/` 目录：

| 子域 | 文件 |
|---|---|
| D-001 鉴权 | `openapi/d-auth.yaml` |
| D-002 主数据 | `openapi/d-space-master-data.yaml` |
| D-003 通知 | `openapi/d-notification.yaml` |
| D-004 审计 | `openapi/d-audit.yaml` |
| D-005 参数 | `openapi/d-config-parameter.yaml` |

各子域负责人只需在对应文件里回复确认或修改字段，确认后状态改为 FROZEN。
**本文件第 2~6 节保留为设计说明，具体接口一律以 `openapi/` 下的 yaml 为准。**

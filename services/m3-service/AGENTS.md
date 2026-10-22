# M3 物业报修工单 —— 模块约束

> 负责人：**D** ｜ schema：`m3` ｜ Flyway 段：`V3xx__` ｜ URL 前缀：`/api/m3/**`
> 上级约束见根目录 `AGENTS.md`。

---

## 1. 你的需求与优先级

| 编号 | 需求 | 优先级 | 本轮 |
|---|---|---|---|
| M3-001 | 提交故障报修（类型/描述/附件） | Must | ✅ 做 |
| M3-002 | 管理员派单、物业接单转维修中 | Must | ✅ 做 |
| M3-003 | 维修中通知 M1 下架该室全部座位 | Must | ✅ 做 |
| M3-004 | 验收通过后通知 M1 恢复座位 | Must | ✅ 做 |
| M3-005 | 工单超时升级提醒 | Should | ⬜ 暂缓 |
| M3-006 | 报修人或验收人验收并评价 | Should | ⬜ 暂缓 |

**另外：你还负责 D-004 审计（见第 4 节），全组都在等你。**

---

## 2. 调用 M1 的接口（契约已冻结）

```
POST /api/m1/seat-restrictions
Authorization: Bearer <jwt>
X-Idempotency-Key: M3:<工单UUID>:<APPLY|RELEASE>
Content-Type: application/json

{
  "sourceType": "M3",
  "sourceId":   "<工单主键，UUID>",
  "roomId":     "<教室主键，UUID>",
  "startAt":    "2026-10-22T02:00:00Z",
  "endAt":      "2026-10-22T10:00:00Z",
  "action":     "APPLY"
}
```

**什么时候调：**

| M3 动作 | 调用 |
|---|---|
| 工单进入「维修中」 | `action: "APPLY"` |
| 验收通过 | `action: "RELEASE"` |
| 验收不通过退回返修 | **不调**，保持 APPLY |

**三个容易错的：**

1. **不传 `seatId`** —— v0.1 整间教室下架，M1 内部展开
2. **`sourceId` 必须是 UUID** —— 工单主键不要用自增 int
3. **时间 UTC 带 `Z`**

---

## 3. 最关键的一条：RELEASE 只解除自己

同一间教室可能同时有：

- M2 的审批占用（ACTIVE）
- 你的 M3 维修下架（ACTIVE）

**你验收通过发 RELEASE 后，如果 M2 的限制还在，座位仍然不可预约。**
这是 M1 按来源叠加判断的结果，**属于正确行为，不是 bug。**

你不需要、也不能"顺手恢复整个教室"。只传你的 `sourceType: M3 + sourceId: 你的工单UUID`，
剩下的判断归 M1。

幂等：APPLY 两次只有一条；RELEASE 两次第二次什么都不做，`releasedAt` 保持首次解除时间。
所以你的超时扫描重复跑不会产生重复数据 —— **但扫描逻辑本身"不重复升级"是你自己的事。**

---

## 4. 你还欠别人：D-004 审计

全组的关键操作都要写审计。请出一个最小契约，建议：

```
POST /api/d/audit-events
Authorization: Bearer <jwt>
X-Trace-Id: <string>

{
  "action": "TICKET_STATUS_CHANGE",
  "operatorId": "<UUID>",
  "objectType": "REPAIR_TICKET",
  "objectId": "<UUID>",
  "result": "SUCCESS",
  "traceId": "..."
}
```

`action` 用 `openapi/common.yaml` 的 `AuditAction` 枚举（LOGIN / PERMISSION_CHANGE / RESERVATION_CREATE / RESERVATION_CANCEL / APPROVAL_DECIDE / BOOKING_ROLLBACK / TICKET_STATUS_CHANGE / SYSTEM_PARAM_CHANGE）。请确认或补充。

**两条硬要求：**

- 审计记录**不可被普通用户修改**，要在权限上落实，不只是说说
- **不要把业务逻辑写进审计**（INT-003：公共层不得重新实现业务规则）。审计只记录"谁在什么时间对什么对象做了什么、结果如何"

---

## 5. 状态机（本轮要交付）

状态列表：待派单 / 已派单 / 已接单 / 维修中 / 待验收 / 已完成 / 返修中

每条转换写成：`当前状态 --[触发事件 + 操作人]--> 下一状态`
标注哪条要调 M1、用 APPLY 还是 RELEASE。

本轮最小链路：**报修 → 接单转维修中 → 调 M1 下架**。这条能跑通就算达标。

---

## 6. 依赖与协作

| 依赖 | 负责人 | 说明 |
|---|---|---|
| M1 写回接口 | B | 已冻结，可用 yaml 起 mock 先行 |
| D-001 鉴权 | A | 物业人员角色 `PROPERTY_STAFF`、验收人 `ACCEPTER` 来自他的枚举 |

调 M1 的 PR 需要 **B（提供方）+ 你（调用方）共同批准**，提前找 B。

---

## 7. 禁止事项

- 不提前做 M3-005 的定时超时升级任务
- 不做附件真实上传（本轮附件字段留空或存路径即可）
- 不跨 schema 查 `m1`
- 不替 M1 判断座位最终可用性

# M1 自习座位预约 —— 模块约束

> 负责人：**B** ｜ schema：`m1` ｜ Flyway 段：`V1xx__` ｜ URL 前缀：`/api/m1/**`
> 上级约束见根目录 `AGENTS.md`。本文件只写 M1 特有的东西。

---

## 1. 你的需求与优先级

| 编号 | 需求 | 优先级 | 本轮 |
|---|---|---|---|
| M1-001 | 按时间/区域/开放范围/插座查询可预约座位 | Must | ✅ 做 |
| M1-002 | 按整点预约，单次最长由参数控制，默认 4 小时 | Must | ✅ 做 |
| M1-003 | 教室动态编码或二维码签到 | Should | ✅ 做 |
| M1-004 | 前 15 分钟提醒；未签到 15 分钟自动取消并记违约 | Should | ✅ 做 |
| M1-005 | 查看历史预约并再次预约 | Should | ✅ 做 |
| M1-006 | 管理员查看预约与利用统计 | Could | ⬜ 暂缓 |

---

## 2. 核心数据模型：限制来源叠加

`seat_restriction` 表。**这是全组最容易做错的地方，任何 AI 建议改动都要回来核对本文件。**

字段：`id` `room_id` `source_type` `source_id` `start_at` `end_at` `status` `created_at` `released_at`

**硬性约束：**

- `UNIQUE (source_type, source_id)` —— 幂等的物理兜底，必须有
- `status` 只有 `ACTIVE` / `RELEASED`
- `source_type` 只有 `M2` / `M3`
- 时间存 UTC

**语义规则（与 `common.yaml` 的 `x-availability-rule` 一致，那里是唯一口径）：**

```
available = 主数据 Room/Seat 状态 = ACTIVE   ← 别漏这条，静态属性查 E 的 D-002
        AND 该时段无个人预约
        AND 该时段无 status='ACTIVE' 的限制记录
```

- 时间按**半开区间 `[from, to)`** 判重叠，避免相邻时段误判
- **RELEASE 只解除自己那条来源的记录**，绝不清空整个教室
- 多个来源叠加：只有全部 ACTIVE 限制都解除后，座位才恢复可预约

---

## 3. 对外接口（已冻结）

契约：`openapi/m1-seat-restriction.yaml`（全组唯一权威，改需 C + D 共同批准）

```
POST /api/m1/seat-restrictions    写回（被 M2 / M3 调用）
GET  /api/m1/seats                查询座位可用性
POST /api/m1/reservations         创建预约（仅本模块内部使用，无需进 openapi/）
```

### 写回接口五条幂等语义（一条都不能少）

| 场景 | 期望 |
|---|---|
| APPLY 且已有 ACTIVE | 200，`created: false`，不新增 |
| APPLY 且已有 RELEASED | 200，改回 ACTIVE 更新时间，`created: false` |
| RELEASE 且存在且 ACTIVE | 200，置 RELEASED，写 `releasedAt` |
| RELEASE 且记录不存在 | 200，什么都不做，`restrictionId: null` |
| RELEASE 且已是 RELEASED | 200，**不修改 `releasedAt`** |

幂等由数据库唯一约束判定。`X-Idempotency-Key` **只做日志关联，不承担判定**。

### 请求体共 8 个字段

必填 7 个：`sourceType` `sourceId` `ownerUserId`(M2) `roomId` `startAt` `endAt` `action`
可选 1 个：`onConflict`（默认 `CANCEL_EXISTING`）
（`additionalProperties: false`，多传即拒；**不传 seatId**，整间教室由 M1 内部展开；
`ownerUserId` 对 M2 必传、对 M3 传了即 400 —— 详见契约）

---

## 4. 依赖的其他模块（你在等别人）

| 依赖 | 负责人 | 状态 |
|---|---|---|
| D-002 空间/座位主数据 | E | 📝 草案已出（`d-space-master-data.yaml`），待 E 确认（含 ADR-001 教室状态归属） |
| D-005 业务参数 | A | 📝 草案已出（`d-config-parameter.yaml`，8 个参数），待 A 确认进不进本轮 |
| D-001 鉴权与 RBAC | A | 📝 草案已出（`d-auth.yaml`），待 A 确认 JWT 方案（PD-001） |
| D-003 通知 | C | 📝 草案已出（`d-notification.yaml`，含批量），待 C 确认 |
| D-004 审计 | D | 📝 草案已出（`d-audit.yaml`），待 D 确认 |

**在这些契约落地前：按接口写 mock，不要自己新建跨模块调用方式。**

特别注意 M1-002 的"单次最长时长"必须**从 D-005 参数接口读**，不得写死常量 4。
在 D-005 可用前允许临时写死，但必须留 `// TODO: 接入 D-005` 注释，并在 PR 里说明。

---

## 5. 预约单状态机（M1 内部，本文件是唯一权威）

状态英文名即数据库枚举值，**不得另起名**。五个终态、四条出口，每条出口的配套动作（违约/通知/审计）绑死，**没有任何路径允许预约「悄悄消失」**。

```
            提交成功           签到              到点离开
 (空) ──────────────→ RESERVED ──────→ CHECKED_IN ──────→ COMPLETED
                        │
                        ├─[用户主动取消]──→ CANCELLED
                        ├─[15min 未签到]──→ AUTO_CANCELLED
                        └─[被清退]────────→ EVICTED
```

### 每条转换的配套动作（一张表定死）

| 转换 | 触发者 | 记违约 | 通知（D-003） | 审计（D-004） |
|---|---|---|---|---|
| → COMPLETED | 系统（到点） | ❌ | 无 | 无（正常结束） |
| → CANCELLED | 学生 | ❌ | 无（自己取消无需通知） | `RESERVATION_CANCEL` |
| → AUTO_CANCELLED | 定时任务（SYSTEM） | ✅ **记** | `VIOLATION_RECORDED` | `VIOLATION_RECORDED` + `taskId` |
| → EVICTED | M2/M3 APPLY 触发 | ❌（CP-1） | `RESERVATION_EVICTED`，**文案区分**：未开始→「请重新预约」；已签到→「请立即离开」 | `RESERVATION_EVICTED` + `relatedRef` 指向来源单据 |

**红线：违约只记学生自身行为。** 系统或他人造成的取消（EVICTED）一律豁免，无论是否已签到（CP-1）。

### 签到相关的三条防误判（易错，逐条实现）

1. **签到记录随预约失效**：预约进 EVICTED/AUTO_CANCELLED 时签到记录一并作废，不留悬空状态
2. **定时任务扫到非 RESERVED 的预约一律跳过**：已取消/已清退的绝不二次处理、绝不补记违约
3. **EVICTED 不可逆**：任何人不得把 EVICTED 改回 RESERVED（CP-2），学生只能重新预约

### 创建预约的四道闸（顺序执行，任一不过即拒）

| 闸 | 查什么 | 参数/依据 |
|---|---|---|
| 1 提前期 | 目标时段在开放窗口内 | `RESERVATION_ADVANCE_DAYS_SEAT = 1`（D-005） |
| 2 时长 | 不超过单次最长 | `RESERVATION_MAX_DURATION_HOURS = 4`（D-005） |
| 3 可用性 | 无他人预约、无 ACTIVE 限制 | 半开区间 `[from, to)` |
| 4 座位有效性 | 主数据 Seat.status = ACTIVE | 查 D-002，不跨 schema |

并发抢同一座位：靠数据库唯一约束/重叠检查兜底，后到者 409，属正常现象，不是 bug。

### 定时任务清单（全部 SYSTEM 身份，规则见 common.yaml x-system-identity）

| 任务 | taskId 建议 | 阈值参数 | 动作 |
|---|---|---|---|
| 开始前提醒 | `m1-resv-reminder` | `RESERVATION_REMINDER_MINUTES = 15` | 发 `RESERVATION_REMINDER`（仅 RESERVED 状态） |
| 签到催办 | `m1-checkin-remind` | `CHECKIN_REMINDER_MINUTES = 10` | 发 `CHECKIN_REMINDER`（仍未签到的） |
| 未签到取消 | `m1-checkin-timeout` | `CHECKIN_TIMEOUT_MINUTES = 15` | 原子三连：AUTO_CANCELLED + 记违约 + 通知 |

**参数值以 D-005 为准，本表数字是当前草案值。** 不得在代码里写死且不留 TODO。

### 限制记录状态机（不变）

```
  (无) --[APPLY / M2或M3]--> ACTIVE --[RELEASE / 同一来源]--> RELEASED
  RELEASED --[APPLY / 同一来源]--> ACTIVE
  ACTIVE --[更高优先级 APPLY 清退 / 仅M3撞M2]--> RELEASED（见契约处置二）
```

非法转换示例：EVICTED --[恢复]--> RESERVED（违反 CP-2，应拒绝）；RELEASE 试图解除他人来源的记录（403/400）。错误码用 `ErrorCode` 枚举，不自造。

---

## 6. Review 演示脚本（3 分钟）

1. `GET /api/m1/seats` → 某座位 `available: true`
2. 同一座位同一时段创建预约两次 → 第二次被拒
3. 再查 → `available: false`
4. 模拟 M2 审批通过：APPLY → `created: true`
5. **重复发同一条 APPLY → `created: false`，查库确认只有一条** ← 核心证据
6. RELEASE → 座位恢复，个人预约仍在

---

## 7. 禁止事项

- 不跨 schema 查 `common`，主数据一律走 E 的 REST 接口
- 不替 C / D 写他们的代码
- 不做预约利用统计（M1-006，本轮暂缓）
- 定时任务不得借用真实用户 token（SI-1）；不得假设调度器只跑一次（SI-5）
- 不得把 EVICTED 预约恢复为 RESERVED（CP-2）
- 状态枚举名以本文件第 5 节为准，不自造（前端展示文案随意）
- 不修改已合并的迁移文件

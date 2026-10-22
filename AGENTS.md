# AGENTS.md —— 全组总约束（根目录）

> **本文件是最高约束。任何 AI / 任何人进入本仓库，先读本文件，再读你所在目录的 `AGENTS.md`。**
> 版本 v0.1-baseline ｜ 适用至 v0.1.0-review1

---

## 0. 怎么用这份文件

```
你在哪个目录干活，AI 就读哪一层：
  services/m1-service/AGENTS.md   ← 你的模块约束（最近优先）
  ./AGENTS.md                     ← 本文件，全组总约束（始终生效）
```

**两者冲突，以本文件为准。**

### 0.1 AI 开工前必读清单（按角色）

只看 `AGENTS.md` 不够 —— 它管纪律，不管接口形状。**开工前按角色把下列文件一起喂给 AI，
缺一份 AI 就会自己猜，猜出来的东西大概率跟别人对不上。**

| 角色 | 必读（按顺序） | 为什么 |
|---|---|---|
| **A** 架构/RBAC/参数 | 本文件 → `openapi/README.md` → `openapi/common.yaml` → `openapi/d-auth.yaml` → `openapi/d-config-parameter.yaml` | 拍板 PD-001~006、确认 RBAC 与参数接口 |
| **B** M1 座位预约 | 本文件 → `services/m1-service/AGENTS.md` → `openapi/m1-seat-restriction.yaml` → `openapi/common.yaml` → `openapi/d-space-master-data.yaml` | 实现限制写入与可用性查询；要读主数据才知道座位从哪来 |
| **C** M2 整教室预约 + 通知 | 本文件 → `services/m2-service/AGENTS.md` → **`openapi/m1-seat-restriction.yaml`** → `openapi/d-notification.yaml` → `openapi/common.yaml` | **C 是 M1 的调用方**，不看这份就不知道审批通过后要 APPLY 什么 |
| **D** M3 报修 + 审计 | 本文件 → `services/m3-service/AGENTS.md` → **`openapi/m1-seat-restriction.yaml`** → `openapi/d-audit.yaml` → `openapi/common.yaml` | **D 是 M1 的调用方**，报修转维修中时调 APPLY（sourceType=M3） |
| **E** 工程化 + 主数据 | 本文件 → `services/d-service/AGENTS.md` → `openapi/d-space-master-data.yaml` → `openapi/common.yaml` → `CONTRIBUTING.md` | 主数据只管静态属性（ADR-001）；工程规范在 CONTRIBUTING |

**三条容易漏的：**

1. **C 和 D 必须读 `m1-seat-restriction.yaml`** —— 他们是调用方，不是提供方。
   只给自己那份契约，AI 会不知道怎么调 M1。
2. **每个人都要读 `common.yaml`** —— 角色、错误码、优先级、可用性口径、提前期不等式都在里面。
   不读就会自建枚举、自己算可用性。
3. **每个人都要读 `openapi/README.md`** —— 那里标了每份契约是「草案」还是「已冻结」。
   **AI 不得把草案当已批准的实现依据**：草案可能被改，实现前先确认状态。

### 0.2 提问模板（每次问 AI 直接套）

```
背景：对应需求 [编号]，当前模块、已有接口。
契约：[文件名]，状态 = 草案 / 已冻结（草案未经批准，不得当作实现依据）。
目标：本次只完成什么。
范围外：明确列出不能改的文件、模块、接口、架构。
约束：权限、事务、幂等、迁移、接口、编码规范。
过程：先给 2–3 个方案及权衡，等我确认后再写代码。
验收：正向、反向、边界测试，以及必须同步更新的文档。
```

---

## 1. 一句话总纲

**本轮目标不是做出完整系统，是做出清晰、可验证、可追溯的工程过程。**
任何产出若无法回答"它对应哪条需求编号""它怎么被验证过"，就不是交付物。

---

## 2. 已冻结清单 —— AI 不得建议更换

| 类别 | 冻结决定 |
|---|---|
| 前端 | Vue 3 + TypeScript + Vite + Pinia + Vue Router + Axios（Vitest / Playwright） |
| 后端 | Java 21 + Spring Boot 3 + Spring Security + Maven（JWT，统一父 POM） |
| 数据库 | PostgreSQL 16，**一个实例四个 schema**：m1 / m2 / m3 / common |
| 迁移 | Flyway，各服务只维护自己目录 |
| 接口 | REST + OpenAPI 3.1 + springdoc，本阶段**不引入消息队列** |
| 部署 | Docker Compose + Nginx（静态资源 + `/api` 反代） |
| 仓库 | GitHub 私有 Monorepo，main / develop 均保护 |
| 主键 | UUID，**禁止自增 int 参与跨模块调用** |
| 时间 | UTC，接口带 `Z` 后缀 |

**AI 若主动建议换框架、换库、引 MQ、改 schema 划分，一律拒绝。**

---

## 3. 数据边界

```
m1 / m2 / m3  各自独占，账号只能读写自己的 schema
common        d-service 读写，只放主数据与公共能力
```

**绝对禁止：**
- 跨 schema JOIN 或直接查表 → 需要数据走 REST
- 在 `common` 建业务表
- 服务账号越权

---

## 4. 模块所有权

| 负责人 | 目录 | 需求范围 |
|---|---|---|
| A | `docs/requirements/`、`docs/adr/`、治理文件 | 需求基线、ADR、RBAC(D-001)、参数(D-005) |
| **B** | `services/m1-service/` | M1-001 ~ M1-006 |
| C | `services/m2-service/` | M2-001 ~ M2-006、通知(D-003) |
| D | `services/m3-service/` | M3-001 ~ M3-006、审计(D-004) |
| E | `deploy/`、`.github/`、`services/d-service/`（主数据） | 工程化、CI、主数据(D-002) |

**原则：一个分支只碰一个服务目录。** 跨模块 → 改契约文件 + 通知对方，不要替对方改代码。

---

## 5. 命名空间（防物理冲突）

| 手段 | 规则 |
|---|---|
| URL 前缀 | `/api/m1/**`、`/api/m2/**`、`/api/m3/**`、`/api/d/**`，Nginx 按前缀转发 |
| **Flyway 版本号分段** | m1=`V1xx__`、m2=`V2xx__`、m3=`V3xx__`、d=`V4xx__` |
| 共享字典 | 角色、错误码、JWT 字段等一律引用 `openapi/common.yaml`，**禁止自建** |

---

## 6. 跨模块调用规则

现状：`openapi/` 下只有 `m1-seat-restriction.yaml`（已冻结）。
**还缺五份契约**：`d-auth`(A)、`d-space-master-data`(E)、`d-notification`(C)、`d-audit`(D)、`d-config-parameter`(A)。
详见 `docs/interfaces/接口注册表.md`。

契约变更流程：

1. 提变更 Issue（原因 / 影响范围 / 迁移方式 / 回退方案）
2. 调用方 + 提供方共同批准
3. **先改 yaml，再改代码**（顺序颠倒一律打回）
4. CI 校验通过 + `contract-approved` 标签

---

## 7. Git 规范

```
main / develop   受保护，禁止直推
feature/m1-01-seat-restriction
fix/m1-xx-idempotency
docs/adr-001-d-ownership
```

提交：`feat(m1): add seat availability query`

PR 必含：需求 ID + Issue / 改了什么和为什么 / 影响范围 / 跑了什么测试及结果 / 未解决问题与回滚方式。

评审最低要求：普通变更 1 人批准；跨模块接口需调用方+提供方；schema 变更需模块负责人+工程化负责人并附迁移与回退说明。

冲突处理：先同步 develop → 双方人工决定业务语义（**AI 只解释不决策**）→ 重跑单测与契约测试 → 在 PR 记录保留/舍弃了什么及原因。

---

## 8. 共享字典（`openapi/common.yaml`）

必须要引用的项，不许自己发明：

- `Role` —— 8 个角色，含 `APPROVER_DEPT` / `APPROVER_UNIVERSITY`
- `ErrorCode` —— `INVALID_ARGUMENT`、`UNAUTHORIZED`、`FORBIDDEN`、`NOT_FOUND`、`CONFLICT`、`IDEMPOTENT_HIT`、`INTERNAL_ERROR`
- `ErrorResponse` —— `code` / `message` / `traceId`，禁止自定义字段
- `JwtClaims` —— `sub`(UUID) / `roles` / `dept` / `exp`
- `Uuid` / `UtcDateTime` —— 带 pattern 硬校验，时区半开区间 `[from, to)`
- `AuditAction` / `NotificationType`

---

## 9. 本轮范围（防蔓延）

**推进这 8 条**：M1-001、M1-002、M2-001、M2-002、M3-001、M3-003、D-001、D-005

**本轮明确不做**：
M1 完整签到/违约/历史/统计；M2 多级审批/超时调度/真实通知渠道；M3 派单/升级/评价/附件；全局的生产发布、完整 UI、自然语言业务代理。

---

## 10. AI 协作硬性规则

- AI 不得替人做冲突决策
- 涉及第三方库、框架配置、安全规则 → 核对官方文档
- 读完整 diff，不能只看 AI 总结
- 测试跑真的；**故意破坏实现确认测试会失败**，排除"假测试"
- 测试不得断言常量，不得 mock 掉被测逻辑本身
- 每次协作留一行：问题 / AI建议 / 风险 / 人工验证 / 最终决定 / 证据 → `docs/ai/`（模板见该目录）

---

## 11. Done 的定义

- [ ] 有需求编号，且在追踪矩阵里
- [ ] 有对应 Issue 和分支
- [ ] 跨模块先落契约再落代码
- [ ] 有真实测试，且破坏实现后会失败
- [ ] schema 变更有版本化迁移，空库可重放
- [ ] PR 通过 CI，审批人已批准
- [ ] AI 参与部分有人工验证记录

# CONTRIBUTING.md —— 协作流程

进仓库第一件事：读完根目录 `AGENTS.md`，再读你负责目录里的 `AGENTS.md`。

---

## 一、接活的流程

1. 在需求追踪表（`docs/requirements/需求追踪表.md`）确认你要做的需求编号和验收标准
2. 建 GitHub Issue：范围 / 非范围 / 风险 / 完成定义
3. 涉及接口或 schema → **先写契约或 ADR**
4. 从最新 `develop` 拉短生命周期分支
5. 小步开发：代码、迁移、测试、文档同步提交
6. 发 PR，关联 Issue
7. CI 通过 + 至少一名相关人员评审
8. 合并进 develop，部署测试环境冒烟

---

## 二、分支命名

```
feature/m1-01-seat-restriction     业务功能
fix/m3-31-idempotency              缺陷修复
docs/adr-001-d-ownership           文档与决策
```

- 一个分支对应一个 Issue
- **一个分支只碰一个服务目录**
- 尽量 1–3 天内合并，不留长分支
- 可演示版本打 tag，如 `v0.1.0-review1`

---

## 三、提交信息

```
feat(m1): add seat availability query
fix(m2): make approval callback idempotent
test(m3): cover duplicate repair writeback
docs(adr): record common layer ownership
```

格式：`<type>(<scope>): <英文动词开头，小写>`

---

## 四、Flyway 迁移（容易撞车，务必遵守）

**版本号按模块分段：**

| 模块 | 段 | 示例 |
|---|---|---|
| m1 | `V1xx__` | `V101__create_seat_restriction.sql` |
| m2 | `V2xx__` | `V201__create_booking_request.sql` |
| m3 | `V3xx__` | `V301__create_repair_ticket.sql` |
| d  | `V4xx__` | `V401__create_space_master.sql` |

- 迁移一经合并**禁止修改**，只能新增版本
- CI 会检测重复版本号，重了直接红灯

---

## 五、PR 检查（模板会自动带出）

必须写清：
- 关联需求编号与 Issue
- 做了什么、为什么
- 影响的模块、接口、schema
- 跑了哪些测试，结果如何
- 未解决问题和回滚方式

触及以下区域必须在 PR 中显式说明：
跨模块接口 / 数据库 schema 与迁移 / 公共层 d-service / 权限、审计、安全

---

## 六、评审门槛

| 变更类型 | 最低要求 |
|---|---|
| 模块内部普通变更 | 至少 1 名其他成员批准，CI 通过 |
| 跨模块接口变更 | 调用方 + 提供方负责人共同批准 |
| 公共层变更 | 公共子域负责人 + 至少 1 个使用方负责人 |
| schema 变更 | 模块负责人 + 工程化负责人，附迁移与回退说明 |
| 权限、安全、敏感数据 | RBAC 负责人参与，补负向测试 |

CODEOWNERS 已按此配置，GitHub 会强制。

---

## 七、契约变更

改 `openapi/` 下任何文件：

1. 开变更 Issue
2. 调用方 + 提供方共同批准
3. **先改 yaml，再改代码**
4. 批准后由负责人加 `contract-approved` 标签，CI 才放行

---

## 八、冲突处理

1. 先同步最新 `develop`，确认冲突涉及哪些需求
2. 冲突双方一起读差异，**由人决定业务语义**，AI 只能辅助解释
3. 接口、公共层、schema 冲突必须请对应负责人确认
4. 解决后重跑单测、契约测试、冒烟
5. 在 PR 里记录保留了什么、舍弃了什么、为什么

---

## 九、AI 使用规定

- 提问前把根目录 `AGENTS.md` 贴进去，再贴你模块的 `AGENTS.md`
- AI 生成的 diff 必须人工读完再提交
- AI 参与的结论必须留一行记录到 `docs/ai/`
- 禁止让 AI 自动决定冲突、自动生成最终 schema 变更

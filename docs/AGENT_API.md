# Agent Studio · 对话、展板与可操作接口（v1.11）

## 在应用里使用

1. 菜单栏番茄 → **Agent 对话与积累**，或从工作台 / 研究展板进入 Agent。
2. 打开 **连接设置**，填写完整的 Chat Completions URL、模型 ID、API Key。本机服务可不填 Key；公网使用 HTTPS，本机 localhost / 127.0.0.1 支持 HTTP。
3. 输入消息，点击发送。用户消息先保存，再请求 AI；回复自动保存。
4. 默认仅发送当前对话最近 20 条用户 / AI 消息及本次输入。勾选上下文时，才附加当前项目、任务、看板、日程；不会附加专注 Session 或其他聊天。复盘笔记不发送。
5. 从提案下拉框选择回复，点击 **预览 / 应用修改**。整批成功才写入；未知操作、无效项目 / 连线或日期会拒绝。同一提案只可应用一次。
6. **打开展板 / 编辑任务** 进入现有编辑器继续手动修改。**保存为复盘笔记** 只存本地，不发送 AI。
7. 新对话创建独立存档，下拉框可切换。工作台 → 设置 → 完整 JSON 备份包含聊天、提案及应用时间。

API Key 只在本次应用运行内存中，重启后重新填写，不写入偏好、数据库、备份或日志。服务地址和模型 ID 保存为偏好。请求不跟随重定向。停止只取消本地请求，不能保证服务商停止已开始的生成或计费。

## 服务适配接口

当前适配 **非流式 Chat Completions** 协议，发送：

```json
{"model":"your-model-id","messages":[{"role":"system","content":"操作协议与可选上下文"},{"role":"user","content":"用户输入"}],"stream":false}
```

服务返回 `choices[0].message.content` 字符串。建议其中包含以下提案 JSON；普通文字回复也会保存，但不产生操作。不是直接支持所有厂商原生 API：例如原生 Messages 协议需要外部兼容代理或新增适配器。应用没有预置账号、模型订阅或访问密钥。

实现入口：`Sources/AgentUI.swift` 的 `AgentTransport` 与 `AgentController.send()`。超时 90 秒；发送体 / 读取的回复上限 2 MB。当前不支持流式输出、工具循环、MCP 服务或后台自主执行。

## 外部 Agent / 模型操作契约 v1

无需配置在线服务也能使用：**导出上下文 → 交给任意 AI / Agent → 导入回复 JSON → 预览应用**。

导出对象包含 `version:1`、`instructions` 与 `context`（projects/tasks/graph/schedule）。不含 API Key、聊天或 Session。日期时间字段沿用应用完整数据格式；每日计划的 `plannedDay` 使用 `YYYY-MM-DD`。

[机器可读 Schema](agent/reply.schema.json) · [可直接导入的示例](agent/example-reply.json)

```json
{"reply":"我的建议","operations":[{"action":"create_task","id":"10000000-0000-4000-8000-000000000001","title":"验证实验条件","plannedDay":"2026-09-15","plannedDuration":60}]}
```

每个操作必须有 `action` 和稳定 UUID `id`，每次最多 100 项。创建需新 ID；更新需已有 ID。省略 / null 字段表示保留，不用于清空字段。请先创建项目 / 节点，再引用它们。更新已有内容前应重新导出上下文以获取最新 ID 和状态。

| action | 支持字段 |
| --- | --- |
| create_project | title（必需）、body（目标） |
| create_task / update_task | title（创建必需）、body（说明）、projectID、status、plannedDay、plannedDuration |
| create_node / update_node | title（创建必需）、body、projectID、kind、status、important、x、y |
| create_edge | from、to（必需，节点 UUID）、relation |

- 任务状态：待办 / 进行中 / 已完成。完成时间与状态同步。
- 节点类型：问题 / 观点 / Idea / 假设 / 实验 / 结果 / 论文 / 讨论 / 失败。
- 节点状态：待探索 / 进行中 / 已验证 / 已解决 / 已否定。
- 连线关系：推进到 / 启发 / 验证 / 反驳 / 产生 / 依赖 / 相关。
- 建议节点横向间隔至少 280，纵向至少 180；单节点宽 240、高 138。
- 更新任务的项目 / 日期必须符合已关联周目标的约束；接口不绕过现有校验。
- 当前不支持删除、清空关联、修改已记录专注时长、文件操作、SQL、Shell 或任意代码执行。
- 新建月 / 周目标暂由日程界面操作；Agent 可以读取目标上下文并安排每日任务。

程序调用入口：`AgentActions.applying(_:to:)` 用于无副作用预演；`AgentActions.commit(messageID:conversationID:in:)` 通过 `FocusSessionCoordinator.change` 一起保存操作及应用时间。不要直接覆盖 SQLite。聊天存储于 metadata 的 `agentArchive`，旧数据缺省为空，随完整备份合并（同 ID 内容冲突时拒绝）。

## English

Agent Studio persists conversations, local reflection notes, proposed operations and application timestamps. Configure an exact non-streaming Chat Completions endpoint, model and an in-memory API key; or exchange JSON files with an external agent. No network call occurs before Send. Context sharing is opt-in; no focus sessions or other conversations are sent. Preview and apply proposals atomically, then continue editing in the task and graph editors. The v1 contract supports project creation, task/node creation and updates, and directed edges. It does not execute scripts or expose an HTTP/MCP server. Provider-native APIs may require an adapter. Full backups include agent history; old backups remain compatible.

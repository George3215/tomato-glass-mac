## 番茄时光 1.11.0 · Agent Studio

新增可配置的 AI 聊天与本地积累空间。兼容非流式 Chat Completions；也可导入外部 Agent JSON。任务、节点和连线提案经预览后原子应用，对话、复盘笔记和应用时间随完整备份保存。API Key 仅保留本次运行内存；项目上下文需主动勾选发送。提供操作契约、Schema 和示例 JSON。

流程图滚动方向反转；采用 Lucide 开源箭头的加粗圆角样式。保留色块展板与开源中英字体。

## English

Adds Agent Studio with persistent conversations, local reflection notes and previewable task/graph operations. Supports compatible non-streaming Chat Completions endpoints and external Agent JSON imports. Operations save atomically and cannot be applied twice; full backups retain agent history. API keys remain in memory; context sharing is opt-in. Includes contract, schema and sample reply. Reverses graph scrolling and adopts thick rounded Lucide arrows.

Validation includes isolated database tests and mocked HTTP GUI tests; no live provider credentials were used. macOS 13+ Universal; not Apple-notarized. Bundled butterfly/ripple assets retain noncommercial licenses.

## 番茄时光 1.8.0 · Research OS Phase 1

- 新增独立科研工作台：概览、任务、项目、Focus 入口、Session 记录与设置。
- 项目支持目标、阶段、里程碑、本周目标、下一步与累计投入；任务支持 Inbox、今天/本周/指定日期、优先级、截止日期、完成/重开和归档/恢复。
- 项目与任务使用稳定 ID；同名任务不混合，改名保留历史关联。
- 一次番茄的暂停/继续归入同一个 Session，支持工作类型、可跳过的到期短记与事后补写。
- 本地 SQLite 事务存储；首次迁移前保留旧版原始备份；完整 JSON 备份导出、冲突保护的合并恢复。
- 保留菜单栏、透明度、Comic Sans MS、自选提示音、动态壁纸、手动补记和 CSV。

旧 Activity 无法还原原始 Session 边界，因此保留时长但不推测历史番茄次数。旧版回退只能看到旧版数据，新版新增记录请先导出。科研日志、习惯、Research Map、Timeline 和 AI Analysis 尚未实现，将按后续阶段推进。

macOS 13+ Universal；本地原生逻辑和 UI 回归通过。安装包未经 Apple 公证；图片与水波许可不变，含这些资源的安装包仅限非商业用途。

---

## English

Research OS Phase 1 adds an independent workspace for projects, tasks and focus sessions. Pause/resume segments belong to a single session; optional notes capture results, findings, questions, ideas and next actions. Stable IDs keep same-name tasks separate. Local SQLite storage includes legacy backup/migration and reviewed JSON backup merging. Existing timer, wallpaper, sound and font features remain.

Legacy durations are preserved; historical Pomodoro counts cannot be reconstructed. Logs, habits, graph, timeline and AI analysis are future phases. macOS 13+ Universal; not Apple-notarized. Bundled third-party assets are noncommercial.

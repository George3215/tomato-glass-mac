# Research OS Phase 1 · 使用与验收

本文记录 Phase 1 的 1.8.0；1.9.0 新增可编辑看板，见 [研究看板说明](RESEARCH_BOARD.md)。

版本：1.8.0。继续使用原生番茄钟，新增项目、任务和 Session；没有加入科研图谱或 AI 后台调用。

## 从哪里开始

1. 点击番茄钟内「科研工作台」或菜单栏「科研工作台…」。
2. 在「项目 Projects」新建项目，填写目标、阶段、下一步。里程碑和本周目标每行一项；`[ ]` 待完成、`[x]` 已完成。阶段可自由填写。进度取已完成里程碑数 / 总数。
3. 在「任务 Tasks」新建任务，可关联项目，也可留为临时任务。安排选择 Inbox、今天、本周或指定日期，截止日期可选。
4. 选中任务点「去专注」，在 Focus 选择工作类型和时长。关联任务后名称在任务页编辑，自由记录仍可直接输入名称。
5. 到期弹窗可以只关闭，也可写一句短记。工作台「Session 记录」选择记录后点「编辑 / 短记」，可补充结果、发现、问题、Idea 和下一步。
6. 任务列表的「完成 / 重开」「归档 / 恢复」是独立动作。归档后通过筛选「已归档」找回。

项目/任务、同名记录通过 ID 区分；Session 保留开始时标题快照。已有 Session 的任务不能换绑项目，避免重解释历史。暂停/继续不拆成两个番茄；休息不计入项目科研投入，重置仍保留已经投入的时间。暂停、睡眠和退出不累计空白时间。

## 数据与升级

位置：`~/Library/Application Support/local.ry.menubar-pomodoro/`。

- `research.sqlite` 及运行时 WAL/SHM：科研数据。项目、任务有外键；每个 Session 的状态、片段与短记作为一条版本化记录事务保存。
- `legacy-v1-backup.json`：首次迁移前原始 UserDefaults 数据的 Base64 备份，原偏好不会删除。
- 工作台「设置 → 导出完整备份」：导出项目、任务、Session、短记的 JSON；不包含壁纸/音频文件或系统偏好。
- 「导入备份（合并）」：先校验并确认，导入前自动保存当前 JSON 备份。相同 ID 相同内容跳过，相同 ID 不同内容拒绝整批导入；避免旧备份覆盖新工作。运行中的导入 Session 在 checkpoint 暂停；不能同时恢复两条未结束的 Session。

迁移按旧任务名建立未分配任务，不推断真实项目。同名旧任务此前已混合，无法自动拆分。每条旧 Activity 保留为 legacy 记录，**时长保留、历史番茄次数不可还原**。手动 / AI JSON 补记不自动变成普通任务、完整番茄或科研节点。

请通过设置导出备份；直接复制正在写入的 SQLite 主文件可能缺少 WAL 中的数据。旧版应用不能读新版科研库；回退旧版只能看到迁移前旧记录，新版新增记录需先导出保存。

## 当前实现边界

Phase 1 使用原生 AppKit 页面导航。SQLite 启动时读取缓存快照，计时每秒只更新当前状态；每 30 秒保存 checkpoint，数据库仅更新变化行。历史当前在内存缓存中，尚未做超大规模历史的分页或完整内存基准，不能声称适合无限历史。后续可以在仓储接口后增加查询分页，不改实体 ID。

结构化科研节点、自动每日科研日志、习惯、可编辑图谱、Timeline、AI 分析均未上线。当前短记只保存用户输入，不生成科研结论。

## 验证

`./scripts/test.sh`：旧计时/Activity/补记测试，加 SQLite 迁移幂等、稳定身份、Session 暂停继续、单次到期、checkpoint 恢复、冲突/重叠拒绝、磁盘写失败不改内存、损坏迁移不覆盖、完整备份恢复等测试。

`./scripts/test.sh --ui`：独立测试数据库；创建项目/任务、归档恢复、短记编辑保存、项目/Session 页面、计时联动、字体、透明度、声音、水波开关和窗口生命周期。演示截图全部来自隔离测试数据。

---

## English quick start

Open **科研工作台** (Research Workspace). Create a project under Projects, optionally create a linked task under Tasks, then select it and choose **去专注** (Focus). Select a work type in the timer and start. Add an optional note in the reminder or edit notes later under Session records.

Project milestones and weekly objectives use one item per line: `[ ]` pending, `[x]` done. Tasks support Inbox, today, this week, specific dates, optional deadlines, completion/reopening and archiving/restoring. IDs keep same-name tasks distinct. A session contains its pause/resume segments; breaks are excluded from research totals.

Settings can export a full JSON backup and merge one after review. Same-ID conflicts reject the entire import. Legacy records retain durations but cannot reconstruct past Pomodoro boundaries. Original legacy data is backed up before migration. New research data is stored locally in SQLite; old app versions cannot read it. Export before downgrading.

Daily logs, habits, nodes, graph, timeline and AI analysis remain future phases. The interface is currently Chinese. SQLite uses a cached snapshot and changed-row writes; large-history pagination and whole-app memory benchmarking are not yet implemented.

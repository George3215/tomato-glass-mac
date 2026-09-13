# Research OS 渐进升级方案（原始设计）

分析日期：2026-09-13。基线：本地 v1.7.1，提交 df90f32。以下保留原始分阶段设计；Phase 1 已在确认后实现为 v1.8.0，实际行为和边界见 [Phase 1 使用与验收](PHASE1.md)。其余阶段仍是规划。

## 1. 现有代码分析

| 模块 | 当前实现 | 升级含义 |
| --- | --- | --- |
| Sources/Countdown.swift | Foundation 值类型；截止时间、暂停剩余时间、到期一次性结算 | 保留计时算法，用协调层接入 Session |
| Sources/ActivityLog.swift | Activity 只有任务名、分类、开始/结束、原因；Active 有 30 秒 checkpoint | 当前 Activity 是工作片段，不是完整番茄 Session；没有稳定 ID |
| Sources/AppDelegate.swift | 生命周期、菜单栏、计时事件、数据读写、窗口引用混合在一起 | 仅逐步抽出 Session 协调与存储职责，保留启动/菜单栏行为 |
| Sources/WindowUI.swift | AppKit 原生布局、任务名输入、四类活动、背景/音效/字体设置 | 保留 Focus 轻量窗口，新增项目/任务/工作类型选择 |
| Sources/StatisticsBoard.swift | 当日记录表；按任务名称分组，完成状态也按名称索引 | 必须改为按 ID 聚合，否则改名或同名项目会混淆历史 |
| Sources/StatisticsUI.swift / ActivityImport.swift | 手动补记、CSV、JSON v1 校验和预览 | 通过兼容适配器继续保留；补记不等于完成一个番茄 |
| Sources/main.swift | NSApplication + AppDelegate | 没有 Web 路由或前端状态框架；新增原生窗口导航即可 |
| build.sh / scripts/test.sh | swiftc 编译双架构、原生逻辑/UI 测试 | 继续沿用；新增目录后调整源文件收集，避免现有 Sources/*.swift 漏编译 |

当前存储：UserDefaults 中 `activityLog.v1` 保存整份 JSON；`savedCountdown.v1` 单独保存计时状态。任务只是字符串，没有独立 Task、Project、Habit、科研日志或图结构。研究数据增长后，不适合继续将所有历史与设置一起全量写入 UserDefaults。

现有完成标记会在同名任务再次开始时被清除；新架构中“任务完成”和“继续一次计时”要成为不同动作。休息预设仍单独归类，不计入科研投入。现有 JSON 导入只是补记接口，不是 AI Research Analysis。

## 2. 推荐架构

保持 Swift/AppKit、macOS 13+、Universal 构建和本地优先。新增原生 Research Workspace 窗口，不将所有研究页面塞入番茄钟窗口。

```text
现有 Focus 窗口 / 菜单栏      Research Workspace 各独立页面
             \                 /
              FocusSessionCoordinator / 各领域服务
                              |
                   ResearchRepository（存储接口）
                              |
                SQLite（项目、任务、Session、后续科研数据）

UserDefaults：继续保存字体、声音、背景、透明度等偏好
```

推荐系统 SQLite，串行后台读写、事务与外键约束；按查询读取统计，不在每秒计时回调扫描全库。不给应用增加服务器或图数据库。数据库放 Application Support 下，附件独立存放相对路径；schemaVersion + 迁移记录支持升级。仓储接口隔离数据库与 UI，测试可使用临时库。

Phase 1 的 Session 状态与片段写入同一事务；计时运行状态以 Session 为唯一真源，Countdown 作为纯逻辑值类型使用。旧 UserDefaults 记录迁移后只作备份，不维持两套可写账本。

## 3. 数据关系与规则

所有实体使用稳定 UUID。显示名称、RQ-003 等短编号只用于显示，不作外键。统一 createdAt / updatedAt / archivedAt；时间存 UTC，日期安排和日志另存日历日期与时区。

| 实体 | 关键字段 / 关系 |
| --- | --- |
| Project | title、goal、stage、nextAction、状态；拥有 Tasks、Milestones、WeeklyObjectives；研究问题/实验等后续通过节点关联 |
| Milestone / WeeklyObjective | projectID、标题、状态、顺序；周目标记录周起始日期。进度按完成里程碑计算，无里程碑显示未定义，不用耗时猜进度 |
| Task | title、description、status、priority、scheduledDate/安排范围、dueDate、completedAt；可选 projectID。临时任务可留 Inbox、安排今天/本周/指定日期、归档 |
| FocusSession | projectID?、taskID?、workType、category、plannedSeconds、状态、结束原因、checkpoint；保留开始时名称快照 |
| FocusSegment | sessionID、start、end；一段连续实际活动时间。一个 Session 可含多个片段 |
| SessionNote | sessionID、自由短记；可选结果/发现/问题/Idea/下一步。允许为空，允许之后修改 |
| Habit / HabitCheckIn | 独立习惯及按 habitID+本地日期唯一的打卡；不每天生成 Task。Phase 2 加入界面 |
| ResearchLog | 日期+时区、关联 Session、自动摘要与用户补充分开；重算不覆盖手写内容 |
| ResearchNode | type、title、status、正文、来源、创建时间；通过 ProjectNode 支持关联多个项目 |
| ResearchRelation | fromNodeID、toNodeID、语义类型、说明/证据来源；有方向、允许分支和环路，禁止悬空引用 |
| NodeSource | 关联 SessionNote、ResearchLog 或外部出处；记录引用片段及版本，便于追溯 |
| GraphLayout | nodeID、画布位置；布局独立于语义关系和节点内容 |

Project、临时 Task、Habit 是三种不同业务对象。项目可拆分执行 Task；Session 可直接关联项目而不强迫建立 Todo。旧“学习/工作/休息/其他”分类与新 Work Type 分开，避免损坏旧统计。

Work Type 首批：论文阅读、科研思考、Idea、写代码、实验、实验分析、论文写作、数据处理、讨论、学习、其他。内部存稳定枚举值，UI 显示中文。

Session 规则：开始创建 Session；暂停结束当前 Segment，继续添加同一 Session 的新 Segment；到时/重置/切换结束 Session；睡眠/退出暂停，恢复需手动；异常退出按最后 checkpoint 恢复并标明原因。实际耗时等于各片段之和，跨午夜按相应日期切片，不把暂停间隔或休息算成研究时间。

普通结束计时不自动完成 Task；完成 Task 单独操作。进行中的 Session 不允许静默换绑项目/任务。归档项目和任务保留历史外键；改名不丢历史，也不合并同名 Task。

后续节点类型：Question、Idea、Hypothesis、Experiment、Result、Discussion、Paper、Failure。公共节点表加按类型的结构化详情：

- Question：Open / Exploring / Answered / Rejected。
- Idea / Hypothesis：内容、验证状态、来源；论文/讨论/问题关联使用语义边。
- Experiment：目的、方法、baseline、参数、数据集、条件、结果状态、附件。
- Result：独立指标记录，可有多项数值、单位、对照对象和条件，不只存一段文字。
- Paper：文献标识/链接、问题、方法、贡献、实验、局限。
- Discussion / Failure：来源、结论或观察、当前解释；将解释与事实分开。

关系包括 inspired_by、derived_from、tested_by、validates、disproves、produces、leads_to、answered_by、related_to。按关系定义校验两端类型；允许多个边和反馈回路，不强制科研沿固定流程走。失败保留为知识；普通任务和 Session 不自动生成科研节点。

## 4. 旧数据迁移与恢复

1. 在迁移前备份原始 ActivityLog JSON、Countdown JSON及相关任务选择值；不修改用户当前数据进行“试迁移”。
2. 检查字段与时间；发现损坏时停止迁移并提示恢复，不能静默创建空历史覆盖原数据。
3. 建立旧任务名到新 Task ID 的固定映射。旧同名任务无法辨认真实项目，统一留为“待整理”的未分配任务，不猜项目或科研含义。
4. 每个旧 Activity 迁成来源为 legacy 的历史 Session+Segment，保留原因和分类。旧数据没有 Session 边界，不能把相邻片段臆测为一个番茄；历史番茄次数显示不可还原，累计秒数保持一致。
5. 暂停中的旧倒计时迁成可继续的 Session，旧 Active 先按 checkpoint 结算；不把重启前后的空白时间补为学习。
6. 单事务写入并记录迁移版本和每条来源映射；重复启动不重复导入。核对记录数、按日/分类/任务总秒数及完成状态。
7. 迁移成功后启用新仓库。原始备份保留，旧版回退只能回到备份时点；新版新增记录需通过新版导出保留，不能声称旧版可读取新库。

JSON v1 补记继续接受原格式，由适配器映射为来源明确的补记记录；无 ID 时不自动归到某个同名项目任务。后续 v2 支持明确 projectID/taskID；所有格式继续预览、校验、整批事务导入。

## 5. 页面与分阶段交付

Research Workspace 用侧栏+内容页；Focus 保持现有可独立使用的窗口。项目页展示推进状态；Research Map 展示知识关系，独立路由/控制器。保留番茄图标、玻璃、Comic Sans MS、自选提示音；密集研究表格优先可读性，背景动画仅在需要的可见页面运行。

| 阶段 | 交付内容 | 验收边界 |
| --- | --- | --- |
| Phase 1 | 数据仓库与迁移；Tasks、Projects、Focus、Session 历史/可跳过的快速短记；简洁 Dashboard / Settings 导航 | 创建项目→创建或选择任务→选工作类型→专注→可选短记→项目累计。旧记录、暂停/恢复、到时提醒与补记可用 |
| Phase 2 | Research Logs 独立页；按日/Work Type 汇总、源 Session 链接、手写补充、Markdown 导出；Habits 独立页 | 日志可重算、不覆盖手写；不猜科研结论；习惯每日唯一打卡、撤销、连续天数、周/月完成率与历史。完成率分母按截至当天的有效计划日期计算 |
| Phase 3 | 8 类节点、结构化详情、人工从笔记提取；Ideas / Experiments / Papers 独立页 | 来源可追溯，失败与结果不混淆；用户确认后入库 |
| Phase 4 | 独立 Research Map；节点增删改、详情、拖动；语义边增删；缩放平移；搜索和类型/项目/状态筛选 | 位置与边重启仍在；允许分支/回路；删除节点处理关联边并支持恢复；过滤隐藏不删数据 |
| Phase 5 | 独立 Research Timeline | 汇总 Session、节点和研究事件；显示业务发生时间与修改时间的区别，支持项目/日期过滤和回看来源 |
| Phase 6 | AI Analysis 独立页；上下文导出、可选模型适配、证据引用、分析保存和候选节点审核 | 覆盖问题/Idea/假设/实验/结果/失败/讨论/论文/图/日志；分析不伪造数据、不自动修改图 |

后续 AI 问答覆盖：研究状态、近期/未验证 Idea、失败实验、未解决问题、矛盾结果、重复工作、相关论文、研究 gap、论文故事、月度方向变化。涉及“与全世界已有工作重复吗”等判断时，本地库不足以支持结论，需明确外部检索范围。

AI 输出记录模型、生成时间、输入范围、引用节点/日志 ID 和版本；区分事实、解释与建议。API 配置和密钥方案留到 Phase 6，密钥存 Keychain；用户触发时才发送所选上下文。附件不默认发送。前期继续离线，不加入后台定时 AI 分析。

## 6. Phase 1 的具体修改位置

新增模型文件（Project、Task、FocusSession、SessionNote），ResearchRepository / SQLiteResearchStore / LegacyMigration，FocusSessionCoordinator，ResearchWorkspaceWindowController 和 Tasks / Projects / SessionHistory 页面。先按现有目录习惯增量添加，必要时再拆子目录。

修改 AppDelegate 的开始、暂停、继续、重置、到时、睡眠、退出事件，统一转交协调层；窗口仅发送动作并显示状态。修改 WindowUI 的绑定选择与快速短记入口；StatisticsBoard 改为仓库聚合读模型；StatisticsUI/ActivityImport 增加兼容适配。

不重写 Countdown / RippleWater，不同时切换 UI 框架。代码拆分以这一阶段的实际依赖为准，不先建立大批空控制器或虚假的 Research Map / AI 页面。

## 7. 验收与发布

- 迁移：v1 快照、空库、重复迁移、损坏输入、进行中/暂停计时；事务失败不半写，备份可读，总秒数不变。
- 身份：同名不同项目不混合；改名、归档不丢 Session；任务完成不会因普通继续计时静默撤销。
- 计时：暂停排除、跨日切分、到期一次、休息隔离、睡眠和异常恢复、菜单栏预设与主窗口入口一致。
- 数据：笔记可跳过、补写和恢复；跨项目错误引用拒绝；v1 JSON/CSV 兼容；备份导出和恢复演练。
- UI：现有窗口常驻、关闭/重开、透明度、字体、静音/自选音频、水波开关回归；新增页面操作与布局实测。现有 UI smoke 会改写演示截图，分析阶段不运行它。
- 打包：逻辑/UI 测试通过后构建 Universal DMG、校验签名与包版本；真实记录、任务名和研究附件不入 GitHub。
- 每阶段独立验收，再进入下一阶段；安装替换前做数据备份。Phase 1 已获得确认并实现，后续阶段另行推进。

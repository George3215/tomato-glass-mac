# 研究进程看板 · Research Board

v1.9.0 新增独立、可编辑的二维节点画布。打开菜单栏「研究进程看板…」，或科研工作台顶部「研究看板」。

![示例研究进程，使用测试数据](research-board.png)

## 操作

- 双击空白或点击「＋ 新节点」创建节点；双击节点或选中后点「编辑」修改。
- 节点可记录标题、详细内容、类型、状态、关联项目；通过复选框或「★ 标为重点」标记关键内容。
- 类型：问题、观点、Idea、假设、实验、结果、论文、讨论、失败。
- 状态：待探索、进行中、已验证、已解决、已否定。标记由用户填写，不意味着 AI 验证过。
- 拖动节点移动位置。拖动空白或滚轮平移；⌘＋滚轮、触控板捏合或 ± 按钮缩放。「显示全部」将当前筛选可见的节点放进视野。
- 开启「连线模式」，选择关系后依次点击起点、终点。箭头表示方向，支持分支和回路。Esc 退出连线模式。
- 连接关系：推进到、启发、验证、反驳、产生、依赖、相关。点击连线后可编辑关系或删除。
- 按标题/内容搜索，或按项目、节点类型、状态、重点筛选。搜索输入后按回车；筛选只隐藏内容，不删除节点。
- 删除节点会同时移除其连接。「撤销」可撤回当前窗口最近 30 次修改，包括移动和删除；撤销历史不跨重启保留。

节点位置、文字、星标、状态、项目关联和连接在操作结束时自动保存到本机 SQLite。绘图按需刷新，不增加后台动画循环。“动态”指可以持续编辑和移动的节点，不是自动漂浮动画。

完整数据备份（科研工作台 → 设置）现在包含看板；旧版不含看板的备份仍可导入，不会清空现有看板。相同 ID 内容冲突拒绝整批合并。请使用 1.9.0 或更新版本导出包含看板的备份。

这是手工编辑的研究进程图，不会把普通任务自动转成节点。暂未实现自动科研日志、AI 分析、节点附件或实验指标的专用表单；实验条件、数值和结论可以先写在节点内容中。

## English

Open **研究进程看板…** in the menu bar, or **研究看板** in Research Workspace. Double-click blank space to add a node and double-click a node to edit its title, details, type, status, project and importance.

Drag nodes to move them; drag empty space or scroll to pan. Use Command-scroll, pinch, or ± to zoom. Enable connection mode, choose a relationship, then click the source and destination. Select an edge to edit or delete it. Search (press Return) and filter by project, type, status or importance. Undo retains the most recent 30 changes in the current window.

Nodes, positions and directed relationships are stored locally and included in full JSON backups. Deleting a node removes its edges and can be undone. Old backups without graph data do not erase the current graph. The board is manually edited; no tasks are automatically promoted to research nodes, and no AI calls are made. Experiment-specific metric forms and attachments remain future work.

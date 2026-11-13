# 🍅 Tomato Glass · Linux 版

轻量番茄钟，Python 3 + Tkinter，无第三方依赖。Mac 版功能(研究看板、Agent 等)未移植，只包含核心计时。

- 25 / 5 / 15 分钟预设，自定义 1–599 分钟
- 开始 / 暂停 / 继续 / 重置（空格键切换）
- 任务名、完成时桌面通知（notify-send）+ 提示音
- 本地记录与今日统计：`~/.local/share/tomato-glass/records.json`

## 运行

```bash
sudo apt install python3-tk libnotify-bin   # Debian/Ubuntu，如已安装可跳过
python3 linux/tomato_glass.py
```

## 安装到应用菜单

```bash
bash linux/install.sh
```

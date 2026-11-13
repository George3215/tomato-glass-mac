#!/usr/bin/env python3
"""Tomato Glass · 番茄时光 — Linux 版 (Python 3 + Tkinter, 无第三方依赖)

功能: 番茄钟 25/5/15 预设、自定义 1-599 分钟、开始/暂停/继续/重置、
任务名、完成提醒(桌面通知 + 提示音)、本地记录与今日统计。
数据保存在 ~/.local/share/tomato-glass/records.json
"""
import json
import os
import shutil
import subprocess
import time
import tkinter as tk
from datetime import datetime, date
from pathlib import Path
from tkinter import messagebox

APP = "Tomato Glass · 番茄时光"
DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "tomato-glass"
RECORDS = DATA_DIR / "records.json"

BG, CARD, FG, SUB, ACCENT = "#f4f1ec", "#ffffff", "#2b2b2b", "#8a8580", "#e5533d"
PRESETS = [("番茄 25", 25, "focus"), ("短休 5", 5, "break"), ("长休 15", 15, "break")]


def load_records():
    try:
        return json.loads(RECORDS.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []


def save_record(rec):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    recs = load_records()
    recs.append(rec)
    tmp = RECORDS.with_suffix(".tmp")
    tmp.write_text(json.dumps(recs, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(RECORDS)


def notify(title, body):
    if shutil.which("notify-send"):
        subprocess.Popen(["notify-send", "-a", "Tomato Glass", title, body])
    for player, snd in (("paplay", "/usr/share/sounds/freedesktop/stereo/complete.oga"),
                        ("canberra-gtk-play", None)):
        if shutil.which(player) and (snd is None or os.path.exists(snd)):
            args = [player, snd] if snd else [player, "-i", "complete"]
            subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return


def fmt(sec):
    sec = max(0, int(round(sec)))
    m, s = divmod(sec, 60)
    return f"{m:02d}:{s:02d}"


class App:
    def __init__(self, root):
        self.root = root
        root.title(APP)
        root.configure(bg=BG)
        root.minsize(380, 520)
        self.total = 25 * 60
        self.remaining = float(self.total)
        self.kind = "focus"
        self.running = False
        self.end_at = None
        self.started_at = None
        self._build()
        self._refresh()
        root.bind("<space>", lambda e: self.toggle())

    def _build(self):
        r = self.root
        tk.Label(r, text="🍅 " + APP, bg=BG, fg=FG, font=("Sans", 14, "bold")).pack(pady=(16, 6))
        card = tk.Frame(r, bg=CARD, padx=20, pady=16)
        card.pack(padx=20, fill="x")
        self.canvas = tk.Canvas(card, width=240, height=240, bg=CARD, highlightthickness=0)
        self.canvas.pack()
        self.mode_lbl = tk.Label(card, text="", bg=CARD, fg=SUB, font=("Sans", 10))
        self.mode_lbl.pack()

        pf = tk.Frame(r, bg=BG)
        pf.pack(pady=10)
        for label, mins, kind in PRESETS:
            tk.Button(pf, text=label, relief="flat", bg=CARD, fg=FG, padx=10,
                      command=lambda m=mins, k=kind: self.set_duration(m, k)).pack(side="left", padx=4)

        cf = tk.Frame(r, bg=BG)
        cf.pack()
        tk.Label(cf, text="自定义(分钟)", bg=BG, fg=SUB).pack(side="left")
        self.custom = tk.Spinbox(cf, from_=1, to=599, width=5)
        self.custom.delete(0, "end"); self.custom.insert(0, "25")
        self.custom.pack(side="left", padx=4)
        tk.Button(cf, text="设置", relief="flat", bg=CARD,
                  command=self.set_custom).pack(side="left")

        tf = tk.Frame(r, bg=BG)
        tf.pack(pady=8)
        tk.Label(tf, text="任务", bg=BG, fg=SUB).pack(side="left")
        self.task = tk.Entry(tf, width=26)
        self.task.pack(side="left", padx=4)

        bf = tk.Frame(r, bg=BG)
        bf.pack(pady=6)
        self.start_btn = tk.Button(bf, text="开始", width=8, relief="flat", bg=ACCENT, fg="white",
                                   activebackground="#c9432f", command=self.toggle)
        self.start_btn.pack(side="left", padx=6)
        tk.Button(bf, text="重置", width=8, relief="flat", bg=CARD, command=self.reset).pack(side="left", padx=6)
        tk.Button(bf, text="记录", width=8, relief="flat", bg=CARD, command=self.show_records).pack(side="left", padx=6)

        self.stats = tk.Label(r, text="", bg=BG, fg=SUB)
        self.stats.pack(pady=(6, 12))

    # --- timer logic ---
    def set_duration(self, mins, kind="focus"):
        if self.running and not messagebox.askyesno(APP, "计时进行中，确定切换吗？"):
            return
        self.running = False
        self.kind = kind
        self.total = mins * 60
        self.remaining = float(self.total)
        self.started_at = None
        self._refresh()

    def set_custom(self):
        try:
            m = int(self.custom.get())
        except ValueError:
            return
        if 1 <= m <= 599:
            self.set_duration(m, "focus")

    def toggle(self):
        if self.running:
            self.remaining = max(0.0, self.end_at - time.monotonic())
            self.running = False
        else:
            if self.remaining <= 0:
                self.remaining = float(self.total)
            if self.started_at is None:
                self.started_at = datetime.now()
            self.end_at = time.monotonic() + self.remaining
            self.running = True
            self._tick()
        self._refresh()

    def reset(self):
        self.running = False
        self.remaining = float(self.total)
        self.started_at = None
        self._refresh()

    def _tick(self):
        if not self.running:
            return
        self.remaining = self.end_at - time.monotonic()
        if self.remaining <= 0:
            self.remaining = 0
            self.running = False
            self._finish()
        else:
            self.root.after(250, self._tick)
        self._refresh()

    def _finish(self):
        task = self.task.get().strip() or ("专注" if self.kind == "focus" else "休息")
        save_record({
            "task": task, "kind": self.kind, "minutes": round(self.total / 60, 2),
            "start": (self.started_at or datetime.now()).isoformat(timespec="seconds"),
            "end": datetime.now().isoformat(timespec="seconds"),
        })
        self.started_at = None
        msg = "专注完成，休息一下吧 ☕" if self.kind == "focus" else "休息结束，继续加油 🍅"
        notify("番茄时光", f"{task}：{msg}")
        self.root.bell()
        self.root.deiconify(); self.root.lift()

    # --- UI ---
    def _refresh(self):
        c = self.canvas
        c.delete("all")
        frac = self.remaining / self.total if self.total else 0
        c.create_oval(20, 20, 220, 220, outline="#eee6dc", width=14)
        if frac > 0:
            color = ACCENT if self.kind == "focus" else "#5aa36a"
            c.create_arc(20, 20, 220, 220, start=90, extent=-359.99 * frac,
                         style="arc", outline=color, width=14)
        c.create_text(120, 120, text=fmt(self.remaining), fill=FG, font=("Sans", 36, "bold"))
        self.mode_lbl.config(text=("专注" if self.kind == "focus" else "休息") + f" · {self.total // 60} 分钟")
        self.start_btn.config(text="暂停" if self.running else ("继续" if self.started_at else "开始"))
        self.root.title(f"{fmt(self.remaining)} · {APP}" if self.running else APP)
        today = date.today().isoformat()
        recs = [x for x in load_records() if x["end"].startswith(today) and x["kind"] == "focus"] \
            if not self.running else getattr(self, "_today_cache", [])
        self._today_cache = recs
        self.stats.config(text=f"今日完成 {len(recs)} 个番茄 · {sum(x['minutes'] for x in recs):g} 分钟")

    def show_records(self):
        w = tk.Toplevel(self.root, bg=BG)
        w.title("记录")
        txt = tk.Text(w, width=60, height=20, bg=CARD, relief="flat")
        txt.pack(padx=10, pady=10, fill="both", expand=True)
        for x in reversed(load_records()[-200:]):
            txt.insert("end", f"{x['end'].replace('T', ' ')}  {x['minutes']:>6g} 分  "
                              f"{'🍅' if x['kind'] == 'focus' else '☕'} {x['task']}\n")
        txt.config(state="disabled")


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Tomato Glass · 番茄时光 — Linux 版

界面复刻 macOS 版主窗口：蝴蝶壁纸、毛玻璃卡片、专注 / 我的空间两栏、壁纸展示。
依赖：Python 3、Tkinter、Pillow（Debian/Ubuntu: sudo apt install python3-tk python3-pil python3-pil.imagetk）
数据：~/.local/share/tomato-glass/records.json   设置：~/.config/tomato-glass/settings.json
"""
import json
import os
import shutil
import subprocess
import time
import tkinter as tk
import tkinter.font as tkfont
from datetime import datetime, timedelta
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageTk
except ImportError:  # pragma: no cover
    raise SystemExit("需要 Pillow：sudo apt install python3-pil python3-pil.imagetk  或  pip install pillow")

HERE = Path(__file__).resolve().parent
RES = next((p for p in (HERE.parent / "Resources", HERE / "Resources") if p.is_dir()), HERE.parent / "Resources")
WALLPAPER = RES / "Wallpapers" / "internal-beyond-butterfly.png"
DATA = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "tomato-glass"
CONF = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "tomato-glass"
RECORDS, SETTINGS = DATA / "records.json", CONF / "settings.json"

W, H = 920, 640
TEXT, MUTED = "#f5f5f7", "#c4c7d0"
PURPLE = (186, 107, 176)
THEMES = ["冰蓝蝴蝶 · Internal Beyond", "粉紫渐变", "自选壁纸"]
FONTS = ["Comic Neue + 霞鹜文楷", "系统字体"]
SOUNDS = [("提示音：关闭", ""), ("Ping", "message"), ("Glass", "complete"), ("Pop", "bell"),
          ("Purr", "alarm-clock-elapsed"), ("自选音频…", "custom")]
CATEGORIES = ["学习", "工作", "休息", "其他"]


# ---------------------------------------------------------------- storage
def read_json(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(path)


def record_seconds(r):
    return r.get("seconds", r.get("minutes", 0) * 60)


def install_fonts():
    """把仓库自带的开源字体注册到用户字体目录（与 Mac 版相同的 Comic Neue + 霞鹜文楷）。"""
    src = RES / "Fonts"
    dst = Path.home() / ".local/share/fonts/tomato-glass"
    if not src.is_dir():
        return
    fresh = False
    for f in src.glob("*.ttf"):
        if not (dst / f.name).exists():
            dst.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, dst / f.name)
            fresh = True
    if fresh and shutil.which("fc-cache"):
        subprocess.run(["fc-cache", "-f", str(dst)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def fmt(sec):
    import math
    total = int(math.ceil(max(0, sec)))
    return f"{total // 60:02d}:{total % 60:02d}"


# ---------------------------------------------------------------- drawing
def cover(img, w, h):
    s = max(w / img.width, h / img.height)
    img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    x, y = (img.width - w) // 2, (img.height - h) // 2
    return img.crop((x, y, x + w, y + h))


def gradient(w, h):
    top, bottom = (196, 140, 196), (92, 82, 158)
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return g.resize((w, h))


def rounded_mask(size, radius, ss=3):
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, m.width - 1, m.height - 1), radius * ss, fill=255)
    return m.resize(size, Image.LANCZOS)


class Glass:
    """收集所有毛玻璃形状，最后一次性合成到一张背景图上。"""
    SS = 3

    def __init__(self, base):
        self.base = base.convert("RGBA")
        self.cards, self.shapes = [], []

    def card(self, rect, radius=24):
        self.cards.append((rect, radius))

    def shape(self, rect, fill, outline=None, radius=6):
        self.shapes.append((rect, fill, outline, radius))

    def render(self):
        img = self.base.copy()
        blurred = self.base.filter(ImageFilter.GaussianBlur(2.5))
        for (x0, y0, x1, y1), r in self.cards:
            region = blurred.crop((x0, y0, x1, y1))
            region = Image.alpha_composite(region, Image.new("RGBA", region.size, (205, 210, 228, 62)))
            img.paste(region, (x0, y0), rounded_mask(region.size, r))
        ss = self.SS
        over = Image.new("RGBA", (img.width * ss, img.height * ss), (0, 0, 0, 0))
        d = ImageDraw.Draw(over)
        for (x0, y0, x1, y1), r in self.cards:
            d.rounded_rectangle((x0 * ss, y0 * ss, x1 * ss - 1, y1 * ss - 1), r * ss, outline=(255, 255, 255, 80), width=ss)
        for (x0, y0, x1, y1), fill, outline, r in self.shapes:
            d.rounded_rectangle((x0 * ss, y0 * ss, x1 * ss - 1, y1 * ss - 1), r * ss, fill=fill,
                                outline=outline, width=ss if outline else 0)
        img = Image.alpha_composite(img, over.resize(img.size, Image.LANCZOS))
        return img


def tomato_icon(size=22):
    ss = 4
    im = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size * ss
    d.ellipse((s * .08, s * .2, s * .92, s * .96), fill=(226, 72, 52))
    d.ellipse((s * .22, s * .32, s * .42, s * .5), fill=(255, 150, 130))
    d.polygon([(s * .5, s * .28), (s * .3, s * .12), (s * .45, s * .22), (s * .5, s * .04),
               (s * .55, s * .22), (s * .72, s * .12)], fill=(76, 150, 70))
    return im.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------- app
class TomatoGlass:
    def __init__(self, root):
        self.root = root
        self.s = read_json(SETTINGS, {})
        root.title("🍅 番茄时光")
        root.geometry(f"{W}x{H}")
        root.resizable(False, False)
        root.configure(bg="#262629")
        self.canvas = tk.Canvas(root, width=W, height=H, highlightthickness=0, bd=0, bg="#262629")
        self.canvas.pack(fill="both", expand=True)
        self._choose_fonts()
        self._wall_cache = {}
        # countdown state (same model as Countdown.swift)
        self.duration = float(self.s.get("duration", 25 * 60))
        self.deadline = self.s.get("deadline")          # epoch seconds while running
        self.paused = self.s.get("pausedRemaining")     # seconds while paused
        self.session_start = self.s.get("sessionStart")
        self.title_ = self.s.get("activityTitle", self.s.get("lastFocusTask", "未命名任务"))
        self.category = self.s.get("activityCategory", "学习")
        self.showcase = False
        self.buttons = []
        self.error_text = None
        self.build()
        self.apply_transparency()
        self.tick()

    # ---- settings helpers
    def save(self):
        self.s.update(duration=self.duration, deadline=self.deadline, pausedRemaining=self.paused,
                      sessionStart=self.session_start, activityTitle=self.title_, activityCategory=self.category)
        write_json(SETTINGS, self.s)

    def _choose_fonts(self):
        fam = set(tkfont.families(self.root))
        pick = lambda *names: next((n for n in names if n in fam), "TkDefaultFont")
        self.comic_family = pick("LXGW WenKai Lite", "霞鹜文楷 轻便版", "Comic Neue")
        self.sys_family = pick("Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei", "DejaVu Sans")
        self.timer_family = pick("Noto Sans CJK SC Light", "Noto Sans Light", "DejaVu Sans Light",
                                 "Noto Sans CJK SC", "DejaVu Sans")

    def font(self, size, bold=False):
        fam = self.comic_family if self.s.get("comicFont", True) else self.sys_family
        bold = bold and fam == self.sys_family   # 霞鹜文楷没有粗体，加粗会退回到其他字体
        return tkfont.Font(root=self.root, family=fam, size=-size, weight="bold" if bold else "normal")

    # ---- background
    def wallpaper(self):
        theme = self.s.get("backgroundTheme", 0)
        key = (theme, self.s.get("backgroundImagePath"))
        if key not in self._wall_cache:
            img = None
            try:
                if theme == 0 and WALLPAPER.exists():
                    img = Image.open(WALLPAPER)
                elif theme == 2 and self.s.get("backgroundImagePath"):
                    img = Image.open(self.s["backgroundImagePath"])
            except OSError:
                img = None
            if img is not None:
                base = cover(img.convert("RGB"), W, H)
                base = Image.blend(base, Image.new("RGB", (W, H), (0, 0, 0)), 0.23)
            elif theme == 1:
                base = gradient(W, H)
            else:
                base = Image.new("RGB", (W, H), (38, 38, 43))
            self._wall_cache = {key: base}
        return self._wall_cache[key]

    # ---- widget helpers (drawn on canvas)
    def label(self, x, y, text, size=13, muted=False, anchor="nw", bold=None, font=None):
        return self.canvas.create_text(x, y, text=text, anchor=anchor, fill=MUTED if muted else TEXT,
                                       font=font or self.font(size, size >= 20 if bold is None else bold))

    def btn_width(self, text, size=13, extra=24):
        return self.font(size).measure(text) + extra

    def button(self, x, y, text, cmd, w=None, h=24, size=13, primary=False, popup=False):
        w = w or self.btn_width(text, size, 40 if popup else 24)
        rect = (int(x), int(y), int(x + w), int(y + h))
        fill = PURPLE + (235,) if primary else (255, 255, 255, 52)
        self.glass.shape(rect, fill, (255, 255, 255, 70), 7 if h > 24 else 6)
        tx = x + 12 if popup else x + w / 2
        t = self.canvas.create_text(tx, y + h / 2, text=text, fill=TEXT, font=self.font(size),
                                    anchor="w" if popup else "center")
        items = [t]
        if popup:
            items.append(self.canvas.create_text(x + w - 12, y + h / 2, text="⌄", fill=TEXT, font=self.font(12)))
        hit = self.canvas.create_rectangle(*rect, outline="", fill="", tags="hit")
        b = {"rect": rect, "text": t, "cmd": cmd, "enabled": True}
        for i in items + [hit]:
            self.canvas.tag_bind(i, "<Button-1>", lambda e, b=b: b["enabled"] and b["cmd"]())
            self.canvas.tag_bind(i, "<Enter>", lambda e: self.canvas.config(cursor="hand2"))
            self.canvas.tag_bind(i, "<Leave>", lambda e: self.canvas.config(cursor=""))
        self.buttons.append(b)
        return b

    def popup(self, x, y, w, options, current, on_pick):
        b = self.button(x, y, options[current], None, w=w, popup=True)

        def show():
            m = tk.Menu(self.root, tearoff=0, font=self.font(13))
            for i, o in enumerate(options):
                m.add_command(label=("✓ " if i == current else "   ") + o, command=lambda i=i: on_pick(i))
            m.tk_popup(self.root.winfo_rootx() + int(x), self.root.winfo_rooty() + int(y + 26))
        b["cmd"] = show
        return b

    def row(self, cx, y, specs, gap=8, h=24):
        """居中排列一行按钮；specs: (text, cmd, kwargs)"""
        widths = [k.get("w") or self.btn_width(t, k.get("size", 13), 40 if k.get("popup") else 24) for t, _, k in specs]
        x = cx - (sum(widths) + gap * (len(specs) - 1)) / 2
        out = []
        for (t, c, k), w in zip(specs, widths):
            k = dict(k, w=w)
            out.append(self.button(x, y, t, c, h=h, **{a: v for a, v in k.items() if a != "popup"}))
            x += w + gap
        return out

    # ---- layout (mirrors WindowUI.swift)
    def build(self):
        c = self.canvas
        for wdg in getattr(self, "_widgets", []):
            wdg.destroy()
        self._widgets = []
        c.delete("all")
        self.buttons = []
        self.glass = Glass(self.wallpaper())
        self._fields = []
        if not self.showcase:
            self._build_main()
        sb = self.button(W - 30 - self.btn_width("返回番茄钟"), H - 18 - 24,
                         "返回番茄钟" if self.showcase else "壁纸展示", self.toggle_showcase,
                         w=self.btn_width("返回番茄钟"))
        img = self.glass.render()
        if not self.showcase:
            img.alpha_composite(tomato_icon(24), (30, 52))
        self._bg = ImageTk.PhotoImage(img)
        c.tag_lower(c.create_image(0, 0, image=self._bg, anchor="nw"))
        for widget, rect in self._fields:   # 输入框背景取合成后的平均色，看起来像透明玻璃
            r, g, b, _ = img.crop(rect).resize((1, 1), Image.BOX).getpixel((0, 0))
            col = f"#{r:02x}{g:02x}{b:02x}"
            if isinstance(widget, ttk.Combobox):
                self.style.configure("Glass.TCombobox", fieldbackground=col, background=col)
                self.style.map("Glass.TCombobox", fieldbackground=[("readonly", col), ("disabled", col)])
            else:
                widget.configure(bg=col, disabledbackground=col)
        self.refresh()

    def _build_main(self):
        c, g = self.canvas, self.glass
        self.style = ttk.Style(self.root)
        self.style.theme_use("clam")
        self.style.configure("Glass.TCombobox", foreground=TEXT, arrowcolor=TEXT, bordercolor="#9aa0b4",
                             lightcolor="#9aa0b4", darkcolor="#9aa0b4", selectbackground="#7a6aa8",
                             insertcolor=TEXT, padding=3)
        self.style.map("Glass.TCombobox", foreground=[("disabled", MUTED)])
        self.root.option_add("*TCombobox*Listbox.font", self.font(13))

        # heading
        self.label(30 + 34, 52, "番茄时光", 23)
        self.label(30, 90, "给自己一小段，不被打扰的时间。", 13, muted=True)

        top, card_h = 130, 384
        fx0, fw = 30, W - 60 - 252
        ox0, ow = fx0 + fw + 18, 234
        g.card((fx0, top, fx0 + fw, top + card_h))
        g.card((ox0, top, ox0 + ow, top + card_h))

        # ---- focus card
        cx, y = fx0 + fw / 2, top + 28
        self.label(cx, y, "F O C U S   /   专 注", 12, muted=True, anchor="n")
        y += 16 + 16
        tasks = sorted({r.get("task", "") for r in read_json(RECORDS, []) if r.get("task")})
        self.task_var = tk.StringVar(value=self.title_)
        self.task_box = ttk.Combobox(self.root, textvariable=self.task_var, values=tasks, style="Glass.TCombobox",
                                     font=self.font(13))
        c.create_window(cx, y, window=self.task_box, anchor="n", width=430, height=26)
        self._widgets.append(self.task_box)
        self._fields.append((self.task_box, (int(cx - 215), y + 4, int(cx + 215), y + 22)))
        if not self.task_var.get():
            self.task_box.set("")
        y += 26 + 16
        self.cat_btn, self.stats_btn, self.done_btn = self.row(cx, y, [
            (self.category, self.pick_category, {"popup": True, "w": 78}),
            ("时间统计 / 补记", self.show_statistics, {}),
            ("任务完成", self.complete_task, {})])
        y += 24 + 14
        self.time_text = c.create_text(cx, y, text="25:00", anchor="n", fill=TEXT,
                                       font=tkfont.Font(family=self.timer_family, size=-76))
        y += 92 + 14
        self.phase_text = self.label(cx, y, "", 13, muted=True, anchor="n")
        y += 18 + 16
        self.row(cx, y, [(n, (lambda m=m: self.start_preset(m)), {}) for n, m in
                         (("专注 25′", 25), ("小憩 5′", 5), ("休息 15′", 15))])
        y += 24 + 16
        _, self.pause_btn, self.reset_btn = self.row(cx, y, [
            ("开始专注", self.start_custom, {"primary": True}),
            ("暂停倒计时", self.toggle_pause, {"w": self.btn_width("暂停倒计时")}),
            ("重置", self.reset, {})], h=28)

        # ---- options card (我的空间)
        x, y = ox0 + 20, top + 20
        self.label(x, y, "我的空间", 19, bold=True)
        y += 24 + 13
        self.label(x, y, "自定义时长", 12, muted=True)
        y += 16 + 13
        self.minutes_var = tk.StringVar(value=str(int(self.duration // 60)))
        ent = tk.Entry(self.root, textvariable=self.minutes_var, justify="center", relief="flat", bd=0,
                       fg=TEXT, insertbackground=TEXT, font=tkfont.Font(family=self.timer_family, size=-22),
                       highlightthickness=1, highlightbackground="#a8adbf", highlightcolor="#d9b4d8")
        ent.bind("<Return>", lambda e: self.start_custom())
        c.create_window(x, y, window=ent, anchor="nw", width=74, height=32)
        self._widgets.append(ent)
        self._fields.append((ent, (x + 3, y + 3, x + 71, y + 29)))
        self.minutes_entry = ent
        self.label(x + 84, y + 16, "分钟", 13, muted=True, anchor="w")
        y += 32 + 11
        self.error_text = self.label(x, y, "支持 1–599 分钟", 11, muted=True)
        y += 14 + 13
        self.opacity_text = self.label(x, y, "透明度 0%", 12)
        y += 16 + 13
        self._slider(x, y, 190)
        y += 20 + 13
        self.popup(x, y, 190, THEMES, self.s.get("backgroundTheme", 0), self.change_theme)
        y += 24 + 13
        self.button(x, y, "选择背景图片…", self.choose_background)
        y += 24 + 13
        self.popup(x, y, 190, FONTS, 0 if self.s.get("comicFont", True) else 1, self.change_font)
        y += 24 + 13
        names = [n for n, _ in SOUNDS]
        cur = next((i for i, (_, k) in enumerate(SOUNDS) if k == self.s.get("reminderSound", "")), 0)
        self.popup(x, y, 128, names, cur, self.change_sound)
        self.button(x + 134, y, "试听", self.play_sound)

        # footer
        self.label(30, top + card_h + 24, "✧  时间到会弹窗提醒    ·    窗口标题会显示剩余时间", 11, muted=True)

    def _slider(self, x, y, w):
        c = self.canvas
        val = float(self.s.get("windowTransparency", 0))
        cy = y + 10
        self.glass.shape((x, cy - 2, x + w, cy + 2), (255, 255, 255, 70), None, 2)
        fill = c.create_line(x, cy, x, cy, fill="#eb9cca", width=4, capstyle="round")
        knob = c.create_oval(0, 0, 0, 0, fill="#f4f4f6", outline="#d0d0d8")
        r = 9

        def place(v):
            px = x + r + (w - 2 * r) * v / 80
            c.coords(fill, x, cy, px, cy)
            c.coords(knob, px - r, cy - r, px + r, cy + r)

        def drag(e):
            v = min(80, max(0, (e.x - x - r) / (w - 2 * r) * 80))
            self.s["windowTransparency"] = v
            place(v)
            self.apply_transparency()

        hit = c.create_rectangle(x - 4, y - 2, x + w + 4, y + 22, outline="", fill="")
        for i in (hit, knob, fill):
            c.tag_bind(i, "<Button-1>", drag)
            c.tag_bind(i, "<B1-Motion>", drag)
            c.tag_bind(i, "<ButtonRelease-1>", lambda e: write_json(SETTINGS, self.s))
        c.tag_raise(knob)
        place(val)

    # ---- state
    def remaining(self):
        if self.deadline is not None:
            return max(0.0, self.deadline - time.time())
        return self.paused if self.paused is not None else self.duration

    @property
    def running(self):
        return self.deadline is not None

    @property
    def is_paused(self):
        return self.paused is not None

    def refresh(self):
        text = fmt(self.remaining())
        state = "计时中" if self.running else "已暂停" if self.is_paused else "准备开始"
        self.root.title(f"🍅 {'Ⅱ ' if self.is_paused else ''}{text} · 番茄时光" if (self.running or self.is_paused)
                        else "🍅 番茄时光")
        if self.showcase or not hasattr(self, "time_text"):
            return
        c = self.canvas
        c.itemconfig(self.time_text, text=text)
        c.itemconfig(self.phase_text, text=f"{state} · {self.title_}")
        active = self.running or self.is_paused
        c.itemconfig(self.pause_btn["text"], text="继续倒计时" if self.is_paused else "暂停倒计时",
                     fill=TEXT if active else MUTED)
        c.itemconfig(self.reset_btn["text"], fill=TEXT if active else MUTED)
        self.pause_btn["enabled"] = self.reset_btn["enabled"] = active
        self.task_box.configure(state="disabled" if active else "normal")
        self.cat_btn["enabled"] = not active
        c.itemconfig(self.cat_btn["text"], text=self.category, fill=MUTED if active else TEXT)

    def tick(self):
        if self.running and self.remaining() <= 0:
            self.finish("完成")
            self.show_reminder()
        self.refresh()
        self.root.after(250, self.tick)

    def begin(self, seconds):
        title = self.task_var.get().strip()
        self.title_ = title or "未命名任务"
        if self.category == "休息":
            self.title_ = "休息"
        else:
            self.s["lastFocusTask"], self.s["lastFocusCategory"] = self.title_, self.category
        if self.running or self.is_paused:
            self.finish("提前结束")
        self.duration = float(seconds)
        self.paused = None
        self.deadline = time.time() + seconds
        self.session_start = datetime.now().isoformat(timespec="seconds")
        self.save()
        self.refresh()

    def start_preset(self, minutes):
        self.minutes_var.set(str(minutes))
        if minutes in (5, 15):
            self.category, self.title_ = "休息", "休息"
            self.task_var.set("休息")
        if minutes == 25 and self.category == "休息":
            self.title_ = self.s.get("lastFocusTask", "未命名任务")
            self.category = self.s.get("lastFocusCategory", "学习")
            self.task_var.set(self.title_)
        self.begin(minutes * 60)

    def start_custom(self):
        raw = self.minutes_var.get().strip()
        if not raw.isdigit() or not 1 <= int(raw) <= 599:
            self.canvas.itemconfig(self.error_text, text="请输入 1–599 之间的整数分钟。", fill="#ff6b6b")
            return
        self.canvas.itemconfig(self.error_text, text="支持 1–599 分钟", fill=MUTED)
        self.begin(int(raw) * 60)

    def toggle_pause(self):
        if self.running:
            self.paused, self.deadline = self.remaining(), None
        elif self.is_paused:
            self.deadline, self.paused = time.time() + self.paused, None
        self.save()
        self.refresh()

    def reset(self):
        self.finish("提前结束")
        self.refresh()

    def finish(self, status):
        if not (self.running or self.is_paused):
            return
        spent = self.duration - self.remaining()
        if spent >= 1:
            recs = read_json(RECORDS, [])
            recs.append({"task": self.title_, "category": self.category,
                         "start": self.session_start or datetime.now().isoformat(timespec="seconds"),
                         "end": datetime.now().isoformat(timespec="seconds"),
                         "seconds": round(spent), "status": status})
            write_json(RECORDS, recs)
            if getattr(self, "task_box", None) and self.task_box.winfo_exists() and self.title_ not in self.task_box["values"]:
                self.task_box["values"] = sorted(set(self.task_box["values"]) | {self.title_})
        self.deadline = self.paused = self.session_start = None
        self.save()

    def complete_task(self):
        if self.running or self.is_paused:
            self.finish("任务完成")
            self.refresh()
            messagebox.showinfo("任务完成", f"「{self.title_}」已记录为完成。", parent=self.root)
        else:
            messagebox.showinfo("任务完成", "当前没有进行中的计时。", parent=self.root)

    def pick_category(self):
        if not self.cat_btn["enabled"]:
            return
        m = tk.Menu(self.root, tearoff=0, font=self.font(13))
        for cat in CATEGORIES:
            m.add_command(label=("✓ " if cat == self.category else "   ") + cat,
                          command=lambda cat=cat: (setattr(self, "category", cat), self.save(), self.refresh()))
        x0, y0, _, y1 = self.cat_btn["rect"]
        m.tk_popup(self.root.winfo_rootx() + x0, self.root.winfo_rooty() + y1 + 2)

    # ---- options
    def apply_transparency(self):
        t = float(self.s.get("windowTransparency", 0))
        try:
            self.root.attributes("-alpha", 1 - t / 100)
        except tk.TclError:
            pass
        if not self.showcase and hasattr(self, "opacity_text"):
            self.canvas.itemconfig(self.opacity_text, text=f"透明度 {round(t)}%")

    def change_theme(self, i):
        if i == 2 and not self.s.get("backgroundImagePath"):
            return self.choose_background()
        self.s["backgroundTheme"] = i
        write_json(SETTINGS, self.s)
        self.rebuild()

    def choose_background(self):
        path = filedialog.askopenfilename(parent=self.root, title="选择背景图片",
                                          filetypes=[("图片", "*.png *.jpg *.jpeg *.webp *.bmp *.tif *.tiff")])
        if not path:
            return
        try:
            Image.open(path).verify()
        except Exception:
            return messagebox.showerror("番茄时光", "无法读取这张图片。", parent=self.root)
        self.s.update(backgroundImagePath=path, backgroundTheme=2)
        write_json(SETTINGS, self.s)
        self.rebuild()

    def change_font(self, i):
        self.s["comicFont"] = i == 0
        write_json(SETTINGS, self.s)
        self.rebuild()

    def change_sound(self, i):
        key = SOUNDS[i][1]
        if key == "custom":
            path = filedialog.askopenfilename(parent=self.root, title="选择提示音",
                                              filetypes=[("音频", "*.wav *.ogg *.oga *.flac *.mp3 *.m4a")])
            if not path:
                return
            if os.path.getsize(path) > 20_000_000:
                return messagebox.showerror("番茄时光", "请选择可播放的音频文件（最大 20 MB）。", parent=self.root)
            DATA.mkdir(parents=True, exist_ok=True)
            dst = DATA / ("reminder-audio" + Path(path).suffix)
            shutil.copyfile(path, dst)
            self.s["reminderSoundPath"] = str(dst)
        self.s["reminderSound"] = key
        write_json(SETTINGS, self.s)
        self.rebuild()

    def play_sound(self):
        key = self.s.get("reminderSound", "")
        if not key:
            return
        path = self.s.get("reminderSoundPath") if key == "custom" else f"/usr/share/sounds/freedesktop/stereo/{key}.oga"
        if not path or not os.path.exists(path):
            return self.root.bell()
        for cmd in (["pw-play", path], ["paplay", path], ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", path]):
            if shutil.which(cmd[0]):
                subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return

    def toggle_showcase(self):
        self.showcase = not self.showcase
        self.rebuild()

    def rebuild(self):
        if hasattr(self, "task_var"):
            self.title_ = self.task_var.get().strip() or self.title_
        self.build()
        self.apply_transparency()

    # ---- reminder
    def show_reminder(self):
        self.play_sound()
        rest = self.category == "休息"
        msg = "休息结束，继续加油吧。" if rest else f"「{self.title_}」专注完成，休息一下吧。"
        if shutil.which("notify-send"):
            subprocess.Popen(["notify-send", "-a", "番茄时光", "🍅 时间到啦", msg])
        win = tk.Toplevel(self.root)
        win.title("时间到啦")
        win.resizable(False, False)
        win.attributes("-topmost", True)
        cv = tk.Canvas(win, width=380, height=200, highlightthickness=0)
        cv.pack()
        base = cover(self.wallpaper(), 380, 200)
        gl = Glass(base)
        gl.card((16, 16, 364, 184), 20)
        bw = 92
        gl.shape((380 / 2 - bw - 6, 132, 380 / 2 - 6, 160), PURPLE + (235,), (255, 255, 255, 70), 7)
        gl.shape((380 / 2 + 6, 132, 380 / 2 + 6 + bw, 160), (255, 255, 255, 52), (255, 255, 255, 70), 7)
        win._img = ImageTk.PhotoImage(gl.render())
        cv.create_image(0, 0, image=win._img, anchor="nw")
        cv.create_text(190, 54, text="时间到啦", fill=TEXT, font=self.font(22, True))
        cv.create_text(190, 96, text=msg, fill=MUTED, font=self.font(13), width=320)
        nxt = (lambda: self.start_preset(25)) if rest else (lambda: self.start_preset(5))
        for x, label, cmd in ((190 - bw / 2 - 6, "专注 25′" if rest else "小憩 5′", nxt), (190 + 6 + bw / 2, "知道了", None)):
            t = cv.create_text(x, 146, text=label, fill=TEXT, font=self.font(13))
            hit = cv.create_rectangle(x - bw / 2, 132, x + bw / 2, 160, outline="", fill="")
            for i in (t, hit):
                cv.tag_bind(i, "<Button-1>", lambda e, cmd=cmd: (win.destroy(), cmd and cmd()))
        win.update_idletasks()
        win.geometry(f"+{self.root.winfo_rootx() + (W - 380) // 2}+{self.root.winfo_rooty() + 180}")
        self.root.deiconify()
        self.root.lift()

    # ---- statistics / 补记
    def show_statistics(self):
        win = tk.Toplevel(self.root, bg="#f8f7f3")
        win.title("时间统计 / 补记")
        win.geometry("720x520")
        st = ttk.Style(win)
        st.configure("Rec.Treeview", font=self.font(13), rowheight=26, background="#ffffff", fieldbackground="#ffffff")
        st.configure("Rec.Treeview.Heading", font=self.font(12))
        summary = tk.Label(win, bg="#f8f7f3", fg="#303836", font=self.font(15, True), anchor="w", justify="left")
        summary.pack(fill="x", padx=18, pady=(16, 6))
        cols = ("time", "task", "cat", "min", "status")
        tree = ttk.Treeview(win, columns=cols, show="headings", style="Rec.Treeview")
        for col, name, wd in zip(cols, ("时间", "任务", "分类", "分钟", "状态"), (150, 250, 70, 70, 90)):
            tree.heading(col, text=name)
            tree.column(col, width=wd, anchor="w" if col == "task" else "center")
        tree.pack(fill="both", expand=True, padx=18)

        def load():
            recs = read_json(RECORDS, [])
            tree.delete(*tree.get_children())
            for r in reversed(recs):
                tree.insert("", "end", values=(r.get("end", "")[:16].replace("T", " "), r.get("task", ""),
                                               r.get("category", "学习"), f"{record_seconds(r) / 60:.0f}",
                                               r.get("status", "完成")))
            today = datetime.now().date().isoformat()
            week0 = (datetime.now() - timedelta(days=datetime.now().weekday())).date().isoformat()
            focus = [r for r in recs if r.get("category") != "休息"]
            tm = sum(record_seconds(r) for r in focus if r.get("end", "").startswith(today)) / 60
            wk = sum(record_seconds(r) for r in focus if r.get("end", "")[:10] >= week0) / 60
            summary.config(text=f"今日专注 {tm:.0f} 分钟    ·    本周 {wk:.0f} 分钟    ·    共 {len(recs)} 条记录")
        load()

        form = tk.Frame(win, bg="#f8f7f3")
        form.pack(fill="x", padx=18, pady=12)
        tk.Label(form, text="补记：", bg="#f8f7f3", font=self.font(13)).pack(side="left")
        task = ttk.Entry(form, width=22, font=self.font(13))
        task.pack(side="left", padx=4)
        cat = ttk.Combobox(form, values=CATEGORIES, width=5, state="readonly", font=self.font(13))
        cat.set("学习")
        cat.pack(side="left", padx=4)
        mins = ttk.Spinbox(form, from_=1, to=599, width=5, font=self.font(13))
        mins.set("25")
        mins.pack(side="left", padx=4)
        tk.Label(form, text="分钟，结束于", bg="#f8f7f3", font=self.font(13)).pack(side="left")
        end = ttk.Entry(form, width=16, font=self.font(13))
        end.insert(0, datetime.now().strftime("%Y-%m-%d %H:%M"))
        end.pack(side="left", padx=4)

        def add():
            try:
                m = int(mins.get())
                e = datetime.strptime(end.get().strip(), "%Y-%m-%d %H:%M")
                assert 1 <= m <= 599 and task.get().strip()
            except (ValueError, AssertionError):
                return messagebox.showerror("补记", "请填写任务名、1–599 分钟和正确的时间（YYYY-MM-DD HH:MM）。", parent=win)
            recs = read_json(RECORDS, [])
            recs.append({"task": task.get().strip(), "category": cat.get(),
                         "start": (e - timedelta(minutes=m)).isoformat(timespec="seconds"),
                         "end": e.isoformat(timespec="seconds"), "seconds": m * 60, "status": "补记"})
            write_json(RECORDS, recs)
            task.delete(0, "end")
            load()
        ttk.Button(form, text="添加", command=add).pack(side="left", padx=6)


def main():
    install_fonts()
    root = tk.Tk()
    TomatoGlass(root)
    root.mainloop()


if __name__ == "__main__":
    main()

# 🍅 Tomato Glass · 番茄时光

[简体中文](README.md) | **English**

![Tomato Glass — stars and butterflies](docs/banner.svg)

> Save a little of today's effort in a tiny tomato. ✧

A lightweight native **Mac Pomodoro and countdown timer**. Butterfly wallpaper, rippling water and translucent glass make room for focus, while task records help you see where your time went. Built with Swift/AppKit. Offline, no account, telemetry or Electron.

**[↓ Download for macOS](https://github.com/George3215/tomato-glass-mac/releases/latest)** · [Releases](https://github.com/George3215/tomato-glass-mac/releases) · [Discovery index](llms.txt)

## Color-block research boards · 1.10.3

Cream, peach, sage and lavender organize research nodes by type and daily Todos by project. Completed items retain their labels on neutral backgrounds. Bundled open-source Comic Neue includes regular and bold weights. Light rounded panels and frosted navigation remain, without dots or large gradients.

## 🗓️ Research Planner · 1.10

A light grouped planner connects **Projects → Monthly Goals → Weekly Goals → Daily Todos**. Weekly/monthly calendars, consecutive-month planning, detailed daily execution, synchronized checkboxes and a collapsible outline keep long plans manageable.

[Planner guide](docs/SCHEDULE.md)

![Weekly planner, demonstration data](docs/schedule-week.png)

## 🧩 Editable research board · 1.9

A separate 2D canvas for questions, viewpoints, experiments and other research nodes. Drag nodes, mark important ideas, edit directed connections, pan/zoom, filter and undo. Saved locally and included in backups.

[Board guide](docs/RESEARCH_BOARD.md)

![Editable research board, example data](docs/research-board.png)

## 🔬 Research OS · Phase 1

An independent workspace now connects **Projects → Tasks → Focus Sessions → Optional Notes**.

- Projects: goals, stages, milestones, weekly objectives, next actions and invested time.
- Tasks: Inbox, today/this week/specific dates, priorities, deadlines, completion and archiving.
- Sessions: project/task/work-type associations; pause/resume remains one session, with optional results, findings and next actions.
- Local SQLite with legacy backup/migration and conflict-protected JSON backup merging.

[Phase 1 usage and migration guide](docs/PHASE1.md). Daily logs, habits, timeline and AI analysis are planned for later phases.

![Research workspace with isolated test data, interface in Chinese](docs/research-workspace.png)

## 🦋 A little corner for focus

![Actual timer interface, shown in Chinese](docs/screenshot.png)

| Feature | What it does |
| --- | --- |
| 🍅 Pomodoro timer | 25 / 5 / 15-minute presets, custom 1–599 minutes, pause, resume, reset and a menu bar countdown. |
| 🔔 Gentle reminders | A dialog when time is up. Sound is off by default; choose an effect or import your own audio (up to 20 MB), preview it and save your choice. |
| 🦋 Butterflies and water | Ice-blue butterfly wallpaper with animated rain, refraction and pointer ripples. Disable motion or choose your own background. |
| ✨ Your style | Adjustable transparency; Comic Neue or system font, with LXGW WenKai Lite for Chinese and fallback for missing glyphs. |
| 📖 Time journal | Named tasks, Study / Work / Break / Other categories, daily records, category summaries and cumulative task totals. |
| 📝 Fill in and export | Manual entries, reviewed AI JSON imports and CSV export. Only recorded activity is shown; gaps are never guessed. |

## 🌙 Start a focus session

1. Download the DMG, drag `番茄钟.app` into **Applications**, then launch it.
2. Enter a task such as “Read a paper,” choose a category and duration, and click “开始专注” (Start).
3. Use “我的空间” (My space) on the right to change the background, transparency, font and sound.
4. Open “时间统计 / 补记” (Statistics / Manual entry) to review your day, or mark a task complete to review its total time.

Tasks use stable IDs, so same-name tasks in different projects have separate totals. Reset before switching tasks; elapsed time is saved. Closing the window leaves the menu bar timer running. Sleep and quitting pause tracking; resume manually when you return. Crash recovery uses the last 30-second checkpoint. There are no automatic cycles. The app interface is currently Chinese; these READMEs are bilingual.

**Requirements:** macOS 13+, Universal binary for Apple Silicon / Intel. Runtime-tested on macOS 15.5 / Apple Silicon; Intel and macOS 13 have not been tested on hardware. Releases are not Apple-notarized, so Gatekeeper may block downloaded builds. Building from source is supported. SHA-256 checksums are included in Releases.

## 📖 See where your time goes

![Time table showing test records, interface in Chinese](docs/records.png)

Category cards summarize the selected day. Switch the table between daily records and all-time task totals. Paused time is excluded. Manual and JSON entries reject overlaps and future times; imports are validated as a whole before saving.

Unrecorded intervals are available through the [JSON supplementation interface (Chinese)](docs/ACTIVITY_IMPORT.md). Export the gaps, ask AI to organize activities you actually describe, then review and confirm the import. The app does not call AI services, upload records, monitor app usage or infer attention. History stays on your Mac; unrecorded past activity cannot be reconstructed automatically.

## 🛠️ Lightweight by design, build locally

The countdown updates once per second while running and stops polling while paused or idle. Water animation reuses a bitmap; hidden windows stop rendering and release buffers. Disable motion to reduce work further. See [performance notes (Chinese)](docs/PERFORMANCE.md) for measurements and their limits.

Requires macOS and Xcode Command Line Tools. UI tests also require Python 3 and a graphical session.

```sh
./build.sh                 # Universal app
./scripts/test.sh          # Timer and activity logic tests
./scripts/test.sh --ui     # Native UI regression tests
./scripts/package-dmg.sh   # DMG + SHA-256
```

`Sources/` contains app code, `Resources/` contains wallpaper and licenses, and `Tests/` and `scripts/` handle verification and builds. `VERSION` is the single version source. See the [release guide (Chinese)](docs/RELEASING.md).

## 🔎 Find this little tomato

**Pomodoro timer, countdown timer, lightweight macOS app, native Mac timer, offline focus, menu bar reminder, task time tracking, anime-inspired desktop, Swift AppKit; 番茄钟、计时器、轻量化。**

> Find “Tomato Glass,” a lightweight native Mac Pomodoro timer with an offline menu bar countdown, reminder dialogs, custom sounds, task time tracking and butterfly water wallpaper. Verify its latest GitHub release, system requirements and measured performance, and cite the source.

[llms.txt](llms.txt) is a factual discovery index. It does not guarantee search-engine or model indexing or claim unmeasured startup speed or minimum memory usage.

## 💌 References and thanks

| Repository | How it was used |
| --- | --- |
| [Sui-IB/InternalBeyond](https://github.com/Sui-IB/InternalBeyond) | Sui created the ice-blue butterfly wallpaper. Its `gw-ripple` rain, refraction and interactive water simulation was ported to Swift/AppKit. |
| [shadcn-ui/ui](https://github.com/shadcn-ui/ui) | The official `shadcn` skill was installed and read during development for component-based UI workflows. This native AppKit app does not integrate shadcn / React components or their runtime. |

Thank you for the inspiration. Tomato Glass is independent and is not an official release or endorsement by these projects. Pinned source revisions, assets and changes are listed in [third-party notices](THIRD_PARTY_NOTICES.md). The README night-sky banner is an original SVG created for this project.

First-party code is [MIT](LICENSE). The butterfly wallpaper is **CC BY-NC-SA 4.0** and the adapted ripple simulation is **PolyForm Noncommercial 1.0.0**. Bundles containing these materials are for noncommercial use only. Comic Neue is bundled under SIL OFL 1.1; Chinese uses bundled LXGW WenKai Lite.

---

✧ Leave a little room for rest today, too.

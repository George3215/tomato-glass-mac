# Tomato Glass · 番茄时光

[简体中文](README.md) | **English**

**A lightweight native Mac Pomodoro and countdown timer: menu bar display, reminders, and offline operation.**

Built with Swift/AppKit. No account, server, Electron, or runtime dependencies.

[Download DMG](https://github.com/George3215/tomato-glass-mac/releases/latest) · [Discovery index](llms.txt) · [Performance notes (Chinese)](docs/PERFORMANCE.md)

![Tomato Glass timer](docs/screenshot.png)

## Install

Open the DMG, drag `番茄钟.app` into Applications, then launch it from Applications.

Requires macOS 13+. The Universal binary includes Apple Silicon and Intel. Runtime-tested on macOS 15.5 / Apple Silicon; Intel and macOS 13 have not been tested on hardware. Current releases are not Apple-notarized, so Gatekeeper may block downloaded builds. Building from source is also supported. Checksums are included in each release.

## Features

- 25/5/15-minute presets and a custom 1–599-minute countdown; pause, resume, and reset.
- Menu bar countdown with a reminder dialog and sound when time is up.
- Persistent window, adjustable transparency, custom backgrounds, and animated butterfly water wallpaper.
- Locally saved timer state; no sign-in, telemetry, or network requests.

The countdown updates once per second while running and stops polling while paused or idle. Animation reuses a bitmap; hidden windows stop rendering and release ripple buffers. Disable animation to reduce work further. See the [performance notes (Chinese)](docs/PERFORMANCE.md) for measurements and their limits.

Closing the window keeps the menu bar timer running. Reminders cannot appear while the app is quit or the Mac is shut down; sleep and quitting pause the timer; resume manually on return. Automatic cycles are not included. Task history is now available.

## Build

Requires macOS and Xcode Command Line Tools. UI tests also require Python 3 and a graphical session.

```sh
./build.sh                 # Universal app
./scripts/test.sh          # Countdown tests
./scripts/test.sh --ui     # Native UI regression tests
./scripts/package-dmg.sh   # DMG + SHA-256
```

`Sources/` contains the timer, window, and background renderer; `Resources/` contains the wallpaper and licenses. `Tests/` and `scripts/` handle verification and builds. `VERSION` is the single version source; binaries are distributed through Releases. See the [release guide (Chinese)](docs/RELEASING.md).

## Search terms and example query

**Pomodoro timer, countdown timer, lightweight macOS app, native Mac timer, offline focus, menu bar reminder, Swift AppKit; 番茄钟、计时器、轻量化、Mac 倒计时。**

> Find Tomato Glass, a lightweight native macOS Pomodoro and countdown timer with offline operation, menu bar countdown and reminder dialogs. Verify its latest release, installation requirements and measured performance, and provide the GitHub source.

[llms.txt](llms.txt) provides a factual discovery index. It does not guarantee search-engine or model indexing, and makes no unmeasured startup-speed or minimum-memory claims.

## Referenced repositories and acknowledgments

| Repository | How it was used |
| --- | --- |
| [Sui-IB/InternalBeyond](https://github.com/Sui-IB/InternalBeyond) | Supplies the ice-blue butterfly wallpaper. Its `gw-ripple` rain, refraction, and interactive water simulation was ported to Swift/AppKit. Original author: Sui. Image and code licenses are listed below. |
| [shadcn-ui/ui](https://github.com/shadcn-ui/ui) | The official `shadcn` skill was installed and read during development to understand component-based UI workflows. This app uses native AppKit; it does not integrate shadcn/React components or their runtime. |

Thank you to these projects. Tomato Glass is independent, is not their official release, and does not imply endorsement. Asset details, pinned source revision, and modifications are documented in [third-party notices](THIRD_PARTY_NOTICES.md).

## License

First-party code is [MIT](LICENSE). The butterfly wallpaper by **Sui — Internal Beyond** is CC BY-NC-SA 4.0; the adapted ripple simulation uses PolyForm Noncommercial 1.0.0. See [third-party notices](THIRD_PARTY_NOTICES.md) for complete attribution and licensing. Bundles containing these materials are for noncommercial use only.

## Task tracking (1.6)

Name a task, choose Study / Work / Break / Other, and start. Same-name tasks share cumulative totals. Pauses, sleep and time outside the app are excluded. The daily table shows recorded activities only; unrecorded gaps remain available through the supplementation interface; manual entries cannot overlap or be in the future. Mark tasks complete to compare their total time, or export all records to CSV. Crash recovery uses the last 30-second checkpoint. The app does not monitor attention or infer activities. Records remain local and are never included in releases. Old sessions cannot be reconstructed.

## Tables, imports and font (1.7)

Statistics now use category cards and a striped table, with daily records and all-time task totals. Unrecorded time is not listed as activity. Manual entries remain available; AI-generated JSON can be previewed and confirmed before an atomic import. See [JSON v1 interface (Chinese)](docs/ACTIVITY_IMPORT.md). No AI service is called automatically.

Choose Comic Sans MS or System Font in the main window. Comic Sans MS is used when installed; unsupported glyphs and unavailable fonts fall back to system fonts. No font files are bundled.

Reminder sound is off by default. Choose a sound or import your own audio (up to 20 MB), preview it, or mute it without disabling the popup. Preferences persist across launches.

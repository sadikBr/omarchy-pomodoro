# Omarchy Pomodoro

A pomodoro timer for [Omarchy](https://omarchy.org), built as an Omarchy shell (Quickshell) plugin. It sits in the bar next to the clock. When it's time for a break, it covers every screen with a break overlay. Breaks can still be skipped from the overlay.

## How a session works

A session is one **focus block** with short **micro-breaks** inside it, followed by a **long break**. The defaults:

```
|-- 10m --|2m|-- 10m --|2m|-- 10m --|2m|-- 10m --|2m|--- 12m ---|====== 10m break ======|
'------------------------------- 1h focus block -----------------------------'
```

- **Focus block**: the total length of the block, micro-breaks included (default 1 h)
- **Micro-breaks**: a short break every N minutes inside the block (default 2 min every 10 min). A micro-break is only scheduled if at least a minute of focus follows it before the block ends
- **Long break**: after the block (default 10 min; set it to *Off* to skip it)
- With *Keep going* on, the next session starts automatically after the long break

All four values can be changed in the popup. The popup shows how many micro-breaks fit in the block and draws the whole session as a timeline.

## Break overlay

Micro-breaks and the long break both cover every monitor with a blurred wallpaper. The overlay takes all mouse and keyboard input and shows:

- a countdown ring, the break number (*micro-break 2 of 4*) and the time left in the block
- a short suggestion: an eye or stretch exercise for micro-breaks, a stand-up suggestion for the long break
- the session timeline
- **+1 min**, **Skip break** and **Stop timer** buttons. Pressing **Esc twice** also skips the break

With *Strict breaks* on, skipping needs a 3-second hold on the button, and Esc and *Stop timer* are disabled.

## Bar widget

The widget shows a timer icon when idle. During a session it shows the time until the next phase change (`8m`, then `0:42` in the last minute) and a thin progress line underneath. During micro-breaks the icon is an eye; during the long break it is a coffee cup. Hover for details: next break, time left in the block, and micro-breaks done.

| Mouse | Action |
|---|---|
| Left click | Open the popup |
| Right click | Start / pause / resume |
| Middle click | Stop |
| Scroll | Add or remove 1 minute on the current phase (later phases move with it) |

## Popup

- Live countdown, the session timeline, time left in the block and micro-breaks done
- **Start / Pause / Resume**, **Break** (take the next break now) or **Skip** (during a break), **+5m**, **Stop**
- **Session**: focus block, micro-breaks on/off, *every* and *for*, and the long break. Each value uses − / + buttons; scrolling over the number also works. Changes made during a session apply from the next session
- **Options**: *Keep going*, *Warn before long break* (notification one minute ahead), *Sounds*, *Strict breaks*
- **Today**: sessions completed, minutes focused, micro-breaks taken and breaks skipped, with a reset button. The counters reset at midnight

## Keys

| Key | Action |
|---|---|
| SUPER+ALT+P | Toggle the popup |
| SUPER+ALT+SHIFT+P | Start / pause / resume |
| Esc, Esc | Skip the break (on the overlay; not in strict mode) |

## Command line

The plugin registers a `bsadik.pomodoro` IPC target, which you can use in scripts, hooks and keybindings:

```bash
omarchy-shell bsadik.pomodoro start         # start a session
omarchy-shell bsadik.pomodoro toggle        # start / pause / resume
omarchy-shell bsadik.pomodoro pause
omarchy-shell bsadik.pomodoro resume
omarchy-shell bsadik.pomodoro skip          # focus -> next break now, or end the current break
omarchy-shell bsadik.pomodoro skipBreak     # only acts during a break
omarchy-shell bsadik.pomodoro extend 5      # +5 min on the current phase (negative values remove time)
omarchy-shell bsadik.pomodoro stop
omarchy-shell bsadik.pomodoro panel         # toggle the popup
omarchy-shell bsadik.pomodoro status        # JSON: phase, time left, block left, micro-breaks, config, today
omarchy-shell bsadik.pomodoro resetStats    # clear today's counters
```

## Install

```bash
git clone <this repo> ~/Work/omarchy-pomodoro-plugin
cd ~/Work/omarchy-pomodoro-plugin
./install.sh
```

`install.sh` is safe to re-run. It:

1. copies `bsadik.pomodoro/` to `~/.config/omarchy/plugins/bsadik.pomodoro/`
2. adds the widget right after `omarchy.clock` in the bar's center section in `~/.config/omarchy/shell.json`
3. adds a marked keybinding block to `~/.config/hypr/bindings.lua` and reloads Hyprland
4. restarts the Omarchy shell. The shell caches plugin code that is already loaded, so changes only take effect after a restart. The timer state is saved to disk, so a restart does not interrupt a running session

After editing anything in this repo, run `./install.sh` again to apply it. Omarchy rejects symlinked plugin folders, so the plugin is copied rather than linked.

To move the widget somewhere else: `omarchy bar move bsadik.pomodoro --section right`.

To remove it: `./install.sh --uninstall`.

## How it works

The plugin has two parts: a **service** and a **bar widget**. The service holds the timer and draws the break overlay. The shell runs one bar per monitor, and the center section also keeps a hidden placeholder copy, so keeping the timer in the service means there is only ever one copy of it.

A running session is stored as a list of segments (focus, micro-break, long break), each with an absolute start and end time. Pausing, extending and skipping work by shifting those times. Everything is saved to `~/.local/state/omarchy/bsadik-pomodoro.json`: the session, the settings and today's stats. A shell restart or suspend/resume therefore picks up at the correct time. Breaks that went by entirely while the machine was asleep are not shown.

| File | Purpose |
|---|---|
| `bsadik.pomodoro/manifest.json` | Plugin manifest (service and bar widget) |
| `bsadik.pomodoro/Service.qml` | Timer engine, persistence, notifications, sounds, IPC |
| `bsadik.pomodoro/BreakOverlay.qml` | Full-screen break overlay (one per monitor) |
| `bsadik.pomodoro/BarWidget.qml` | Bar icon, countdown and popup host |
| `bsadik.pomodoro/PomodoroPanel.qml` | Popup contents |
| `bsadik.pomodoro/Timeline.qml` | Session timeline bar |
| `bsadik.pomodoro/SettingRow.qml` | Labelled popup row |
| `bsadik.pomodoro/Stepper.qml` | − / + minute picker |
| `bsadik.pomodoro/Pomodoro.js` | Defaults, schedule building, state normalization, formatting |

## Notes

- The overlay takes all mouse and keyboard input, but Hyprland's own keybindings still work, so a workspace switch is still possible during a break. Covering every screen is what keeps the windows unreachable.
- The lock screen is drawn above the overlay, so locking during a break works normally.
- **Break** during focus moves the rest of the session earlier, so the break you take keeps its full length. Skipping a micro-break gives the spare minutes to the next focus stretch, so the block still ends on time.

## Requirements

- Omarchy with the Quickshell-based `omarchy-shell` and Lua Hyprland config
- `JetBrainsMono Nerd Font` (Omarchy default) for the icons
- `pw-play` (PipeWire) for sounds, using the freedesktop sound theme
- `jq` and `rsync` (for `install.sh`)

## Troubleshooting

- **Bar icon missing or old behaviour after an update:** run `omarchy restart shell`.
- **Logs:** `qs log --id "$(qs list --all | awk '/Instance/{print $2; exit}' | tr -d :)" | grep -i pomodoro`

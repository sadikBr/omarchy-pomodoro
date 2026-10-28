import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import "Pomodoro.js" as P

// Pomodoro engine. One instance per shell: it owns the timer state, persists
// it to disk, raises notifications, and shows the break overlay on every
// screen. Bar widgets (one per monitor) only read from it and call into it.
//
// A running session is a list of segments (focus / micro / break) with
// absolute wall-clock start and end times, so a shell restart, plugin reload
// or suspend resumes at the right moment. Pausing, extending and skipping all
// work by shifting those times.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/bsadik-pomodoro.json"
  readonly property string soundDir: "/usr/share/sounds/freedesktop/stereo/"

  // ---------------------------------------------------------------- state

  property var config: P.defaults().config
  property var settings: P.defaults().settings
  property var stats: P.defaults().stats

  property var segments: []
  property int index: -1
  property bool paused: false
  property real pausedAt: 0
  property int blockNumber: 0          // sessions finished since start()

  property bool loaded: false
  property bool warned: false
  property real now: Date.now()

  readonly property var current: index >= 0 && index < segments.length ? segments[index] : null
  readonly property var next: index + 1 < segments.length ? segments[index + 1] : null
  readonly property string phase: current ? current.kind : "idle"
  readonly property bool active: current !== null
  readonly property bool running: active && !paused
  readonly property bool onBreak: phase === "micro" || phase === "break"
  readonly property real clockNow: paused ? pausedAt : now

  readonly property real remainingMs: current ? Math.max(0, current.end - clockNow) : 0
  readonly property real remainingSeconds: remainingMs / 1000
  readonly property real phaseDuration: current ? current.end - current.start : 0
  readonly property real progress: phaseDuration > 0 ? Math.max(0, Math.min(1, 1 - remainingMs / phaseDuration)) : 0

  // Whole-session view, for the timeline and "block ends in".
  readonly property real sessionStart: segments.length > 0 ? segments[0].start : 0
  readonly property real sessionEnd: segments.length > 0 ? segments[segments.length - 1].end : 0
  readonly property real blockEnd: {
    for (var i = segments.length - 1; i >= 0; i--) if (segments[i].kind === "focus") return segments[i].end
    return 0
  }
  readonly property real blockRemainingMs: active ? Math.max(0, blockEnd - clockNow) : 0
  readonly property real sessionProgress: sessionEnd > sessionStart
    ? Math.max(0, Math.min(1, (clockNow - sessionStart) / (sessionEnd - sessionStart))) : 0
  readonly property int microTotal: segments.filter(function(s) { return s.kind === "micro" }).length
  readonly property int microDone: {
    var n = 0
    for (var i = 0; i < index && i < segments.length; i++) if (segments[i].kind === "micro") n++
    return n
  }
  // Time until the next micro or long break, while focusing.
  readonly property real nextBreakMs: phase === "focus" ? remainingMs : 0
  readonly property string nextBreakKind: next ? next.kind : ""

  readonly property bool finalMinute: phase === "focus" && !paused && remainingMs <= 60000 && next !== null
  readonly property bool overlayVisible: loaded && onBreak

  // ------------------------------------------------------------- lifecycle

  function applyState(text) {
    var raw = null
    try { raw = text ? JSON.parse(text) : null } catch (e) { raw = null }
    var s = P.normalize(raw)
    root.config = s.config
    root.settings = s.settings
    root.stats = s.stats
    root.segments = s.run.segments
    root.index = s.run.index
    root.paused = s.run.paused
    root.pausedAt = s.run.pausedAt
    root.blockNumber = s.run.blockNumber
    root.now = Date.now()
    root.warned = root.phase === "focus" && root.remainingMs <= 60000
    root.rollDay()
    root.loaded = true
    // Catch up on anything that elapsed while the shell was down.
    root.tick()
  }

  function snapshot() {
    return {
      config: root.config,
      settings: root.settings,
      run: {
        segments: root.segments,
        index: root.index,
        paused: root.paused,
        pausedAt: root.pausedAt,
        blockNumber: root.blockNumber
      },
      stats: root.stats
    }
  }

  function save() {
    if (root.loaded) saveDebounce.restart()
  }

  // ---------------------------------------------------------------- engine

  function tick() {
    root.now = Date.now()
    if (!root.loaded || !root.current || root.paused) return

    if (root.phase === "focus" && root.next && root.next.kind === "break") {
      var left = root.current.end - root.now
      if (!root.warned && left <= 60000 && left > 5000 && root.phaseDuration > 120000) {
        root.warned = true
        if (root.settings.warnBeforeBreak)
          root.notify("Long break in 1 minute", "Wrap up what you're doing.", P.icons.bell)
      }
    }
    if (root.current.end <= root.now) root.advance()
  }

  // Moves past every segment that has ended (several, when catching up after
  // a suspend), then announces whatever is current now.
  function advance() {
    var t = Date.now()
    var from = root.phase
    var idx = root.index
    while (idx < root.segments.length && root.segments[idx].end <= t) {
      root.completeSegment(root.segments[idx])
      idx++
    }
    root.index = idx
    root.warned = false
    root.now = t

    if (!root.current) {
      root.finishSession()
      return
    }
    root.save()

    if (root.phase === "micro" || root.phase === "break") {
      root.playSound("complete")
    } else if (root.phase === "focus" && from !== "focus") {
      root.playSound("bell")
    }
  }

  function completeSegment(seg) {
    root.rollDay()
    var s = root.copy(root.stats)
    if (seg.kind === "focus") s.focusMinutes += Math.round((seg.end - seg.start) / 60000)
    else if (seg.kind === "micro") s.microBreaks += 1
    root.stats = s
  }

  function finishSession() {
    var s = root.copy(root.stats)
    s.blocks += 1
    root.stats = s
    root.blockNumber += 1
    if (root.settings.autoRepeat) {
      root.startSession(Date.now())
      root.playSound("bell")
      root.notify("Back to focus", "Session #" + (root.blockNumber + 1) + " started: " + root.summary() + ".", P.icons.brain)
    } else {
      root.clear()
      root.playSound("bell")
      root.notify("Session complete", "Start the next one from the bar when you're ready.", P.icons.flag)
    }
  }

  function startSession(from) {
    root.segments = P.buildSchedule(from, root.config)
    root.index = 0
    root.paused = false
    root.pausedAt = 0
    root.warned = false
    root.now = Date.now()
    root.save()
  }

  function start() {
    root.blockNumber = 0
    root.startSession(Date.now())
    root.notify("Focus started", root.summary() + ".", P.icons.brain)
    return "ok"
  }

  function clear() {
    root.segments = []
    root.index = -1
    root.paused = false
    root.pausedAt = 0
    root.warned = false
    root.save()
  }

  // Shifts segment `from` and everything after it by `delta` ms. With
  // `onlyEnd`, segment `from` keeps its start (used for the current one).
  function shiftFrom(from, delta, onlyEnd) {
    var segs = root.copy(root.segments)
    for (var i = from; i < segs.length; i++) {
      if (!(onlyEnd && i === from)) segs[i].start += delta
      segs[i].end += delta
    }
    root.segments = segs
  }

  function pause() {
    if (root.phase !== "focus" || root.paused) return "ignored"
    root.pausedAt = Date.now()
    root.paused = true
    root.save()
    return "ok"
  }

  function resume() {
    if (!root.paused) return "ignored"
    var t = Date.now()
    root.shiftFrom(root.index, t - root.pausedAt, true)
    root.paused = false
    root.pausedAt = 0
    root.now = t
    root.save()
    return "ok"
  }

  // Primary action: start when idle, otherwise pause/resume focus.
  function toggle() {
    if (!root.active) return root.start()
    if (root.onBreak) return "ignored"
    return root.paused ? root.resume() : root.pause()
  }

  function stop() {
    if (!root.active) return "ignored"
    if (root.phase === "focus") {
      // Count the minutes worked in the interrupted stretch.
      var worked = Math.max(0, root.clockNow - root.current.start)
      var s = root.copy(root.stats)
      s.focusMinutes += Math.round(worked / 60000)
      root.stats = s
    }
    root.blockNumber = 0
    root.clear()
    return "ok"
  }

  // Ends the current segment now.
  //   focus → the next break starts now; the rest of the session moves
  //           earlier so that break keeps its full length.
  //   micro → back to focus now; that focus stretch gets the spare time.
  //   break → the session ends (and the next starts if auto-repeat is on).
  function skip() {
    if (!root.active) return "ignored"
    if (root.paused) root.resume()
    var t = Date.now()
    var segs = root.copy(root.segments)
    var cur = segs[root.index]
    var left = Math.max(0, cur.end - t)

    if (cur.kind === "focus") {
      var s = root.copy(root.stats)
      s.focusMinutes += Math.round((t - cur.start) / 60000)
      root.stats = s
      cur.end = t
      for (var i = root.index + 1; i < segs.length; i++) { segs[i].start -= left; segs[i].end -= left }
      root.segments = segs
      // Already counted above; don't count the stretch again on advance.
      root.index += 1
      root.warned = false
      root.now = t
      if (!root.current) { root.finishSession(); return "ok" }
      root.save()
      if (root.onBreak) root.playSound("complete")
      return "ok"
    }

    var st = root.copy(root.stats)
    st.breaksSkipped += 1
    root.stats = st
    cur.end = t
    if (root.index + 1 < segs.length) segs[root.index + 1].start = t
    root.segments = segs
    root.index += 1
    root.warned = false
    root.now = t
    if (!root.current) { root.finishSession(); return "ok" }
    root.save()
    return "ok"
  }

  function skipBreak() {
    return root.onBreak ? root.skip() : "ignored"
  }

  // Adds (or with a negative value removes) minutes from the current segment;
  // everything after it moves by the same amount.
  function extend(minutes) {
    var m = Math.round(Number(minutes) || 0)
    if (!root.active || m === 0) return "ignored"
    var delta = m * 60000
    var left = root.remainingMs
    if (left + delta < 5000) delta = 5000 - left
    root.shiftFrom(root.index, delta, true)
    if (left + delta > 60000) root.warned = false
    root.now = Date.now()
    root.save()
    return "ok"
  }

  function setConfig(key, value) {
    if (!(key in root.config)) return
    var next = root.copy(root.config)
    next[key] = key === "microEnabled" ? !!value : P.clampConfig(key, value)
    root.config = next
    root.save()
  }

  function setSetting(key, value) {
    if (!(key in root.settings)) return
    var next = root.copy(root.settings)
    next[key] = !!value
    root.settings = next
    root.save()
  }

  function resetStats() {
    root.stats = P.emptyStats(P.dayKey())
    root.save()
  }

  function rollDay() {
    var today = P.dayKey()
    if (root.stats.day === today) return
    root.stats = P.emptyStats(today)
    root.save()
  }

  // "1h focus with 2m breaks every 10m, then a 10m break"
  function summary() {
    var c = root.config
    var text = P.duration(c.block) + " focus"
    if (c.microEnabled && P.countMicro(c) > 0)
      text += " with " + P.duration(c.microLength) + " breaks every " + P.duration(c.microEvery)
    if (c.longBreak > 0) text += ", then a " + P.duration(c.longBreak) + " break"
    return text
  }

  function status() {
    return JSON.stringify({
      phase: root.phase,
      paused: root.paused,
      remaining: Math.ceil(root.remainingMs / 1000),
      blockRemaining: Math.ceil(root.blockRemainingMs / 1000),
      microBreaks: { done: root.microDone, total: root.microTotal },
      session: root.blockNumber + (root.active ? 1 : 0),
      config: root.config,
      settings: root.settings,
      today: root.stats
    })
  }

  // ---------------------------------------------------------------- output

  function copy(value) { return JSON.parse(JSON.stringify(value)) }

  function notify(title, body, glyph) {
    var args = [root.omarchyPath + "/bin/omarchy-notification-send", "--app-name", "Pomodoro"]
    if (glyph) args.push("-g", glyph)
    args.push(title)
    if (body) args.push(body)
    Quickshell.execDetached(args)
  }

  function playSound(name) {
    if (!root.settings.sounds) return
    Quickshell.execDetached(["pw-play", root.soundDir + name + ".oga"])
  }

  // ------------------------------------------------------------- plumbing

  FileView {
    id: stateFile
    path: root.statePath
    printErrors: false
    onLoaded: root.applyState(text())
    onLoadFailed: root.applyState("")
  }

  Timer {
    id: saveDebounce
    interval: 150
    onTriggered: stateFile.setText(JSON.stringify(root.snapshot(), null, 2) + "\n")
  }

  Timer {
    interval: 250
    repeat: true
    running: root.loaded && root.running
    triggeredOnStart: true
    onTriggered: root.tick()
  }

  // Rolls today's counters over at midnight even when nothing is running.
  Timer {
    interval: 60000
    repeat: true
    running: root.loaded
    onTriggered: root.rollDay()
  }

  IpcHandler {
    target: "bsadik.pomodoro"

    function start(): string { return root.start() }
    function toggle(): string { return root.toggle() }
    function pause(): string { return root.pause() }
    function resume(): string { return root.resume() }
    function stop(): string { return root.stop() }
    function skip(): string { return root.skip() }
    function skipBreak(): string { return root.skipBreak() }
    function extend(minutes: int): string { return root.extend(minutes) }
    function status(): string { return root.status() }
    function resetStats(): void { root.resetStats() }
    function panel(): void { if (root.shell) root.shell.toggle("bsadik.pomodoro", "") }
  }

  Variants {
    model: Quickshell.screens

    BreakOverlay {
      required property var modelData
      screen: modelData
      service: root
    }
  }
}

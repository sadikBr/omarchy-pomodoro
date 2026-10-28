.pragma library

// Pure helpers for the pomodoro service and widget: defaults, schedule
// building, state normalization, and formatting. No QML objects in here.
//
// A session is one focus block (e.g. 60 min) split by short micro-breaks
// (e.g. 2 min every 10 min) and followed by a long break (e.g. 10 min). The
// block length is wall-clock time: micro-breaks happen inside it.

var icons = {
  timer: String.fromCodePoint(0xF051B),
  play: String.fromCodePoint(0xF040A),
  pause: String.fromCodePoint(0xF03E4),
  stop: String.fromCodePoint(0xF04DB),
  skip: String.fromCodePoint(0xF04AD),
  coffee: String.fromCodePoint(0xF0176),
  eye: String.fromCodePoint(0xF0208),
  brain: String.fromCodePoint(0xF09D1),
  bell: String.fromCodePoint(0xF009A),
  volume: String.fromCodePoint(0xF057E),
  repeat: String.fromCodePoint(0xF0456),
  chart: String.fromCodePoint(0xF0128),
  minus: String.fromCodePoint(0xF0374),
  plus: String.fromCodePoint(0xF0415),
  reset: String.fromCodePoint(0xF0450),
  fire: String.fromCodePoint(0xF0238),
  flag: String.fromCodePoint(0xF023B),
  shield: String.fromCodePoint(0xF0498)
}

// Limits for each config field: [min, max, default].
var limits = {
  block: [5, 240, 60],
  longBreak: [0, 60, 10],
  microEvery: [1, 120, 10],
  microLength: [1, 30, 2]
}

function defaults() {
  return {
    config: {
      block: limits.block[2],
      longBreak: limits.longBreak[2],
      microEnabled: true,
      microEvery: limits.microEvery[2],
      microLength: limits.microLength[2]
    },
    settings: {
      autoRepeat: true,
      warnBeforeBreak: true,
      sounds: true,
      strictOverlay: false
    },
    run: {
      segments: [],
      index: -1,
      paused: false,
      pausedAt: 0,
      blockNumber: 0
    },
    stats: emptyStats("")
  }
}

function emptyStats(day) {
  return { day: day, blocks: 0, focusMinutes: 0, microBreaks: 0, breaksSkipped: 0 }
}

function clampInt(v, lo, hi, fallback) {
  var n = Math.round(Number(v))
  if (!isFinite(n)) return fallback
  return Math.max(lo, Math.min(hi, n))
}

function clampConfig(key, value) {
  var l = limits[key]
  return l ? clampInt(value, l[0], l[1], l[2]) : value
}

// Lays out one session starting at `start` (ms): focus / micro pairs while a
// micro-break still leaves at least a minute of focus before the block ends,
// then the last focus stretch, then the long break.
function buildSchedule(start, cfg) {
  var MIN = 60000
  var segs = []
  var t = start
  var blockEnd = start + cfg.block * MIN
  if (cfg.microEnabled) {
    while (true) {
      var focusEnd = t + cfg.microEvery * MIN
      var microEnd = focusEnd + cfg.microLength * MIN
      if (microEnd + MIN > blockEnd) break
      segs.push({ kind: "focus", start: t, end: focusEnd })
      segs.push({ kind: "micro", start: focusEnd, end: microEnd })
      t = microEnd
    }
  }
  segs.push({ kind: "focus", start: t, end: blockEnd })
  if (cfg.longBreak > 0) segs.push({ kind: "break", start: blockEnd, end: blockEnd + cfg.longBreak * MIN })
  return segs
}

function countMicro(cfg) {
  return buildSchedule(0, cfg).filter(function(s) { return s.kind === "micro" }).length
}

// Merge whatever was on disk over the defaults so a partial or older file
// never leaves a field undefined.
function normalize(raw) {
  var d = defaults()
  if (!raw || typeof raw !== "object") return d

  var c = raw.config || {}
  for (var key in limits) if (c[key] !== undefined) d.config[key] = clampConfig(key, c[key])
  if (typeof c.microEnabled === "boolean") d.config.microEnabled = c.microEnabled

  var s = raw.settings || {}
  for (var k in d.settings) if (typeof s[k] === "boolean") d.settings[k] = s[k]

  var r = raw.run || {}
  if (Array.isArray(r.segments) && r.segments.length > 0) {
    var segs = r.segments.filter(function(x) {
      return x && (x.kind === "focus" || x.kind === "micro" || x.kind === "break")
        && isFinite(Number(x.start)) && isFinite(Number(x.end))
    }).map(function(x) { return { kind: x.kind, start: Number(x.start), end: Number(x.end) } })
    var idx = clampInt(r.index, -1, segs.length, -1)
    if (segs.length > 0 && idx >= 0 && idx < segs.length) {
      d.run.segments = segs
      d.run.index = idx
      d.run.paused = r.paused === true
      d.run.pausedAt = Number(r.pausedAt) || 0
      d.run.blockNumber = clampInt(r.blockNumber, 0, 100000, 0)
    }
  }

  var st = raw.stats || {}
  d.stats.day = String(st.day || "")
  d.stats.blocks = clampInt(st.blocks, 0, 100000, 0)
  d.stats.focusMinutes = clampInt(st.focusMinutes, 0, 10000000, 0)
  d.stats.microBreaks = clampInt(st.microBreaks, 0, 100000, 0)
  d.stats.breaksSkipped = clampInt(st.breaksSkipped, 0, 100000, 0)
  return d
}

function dayKey(date) {
  var d = date || new Date()
  function pad(n) { return n < 10 ? "0" + n : String(n) }
  return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

// 754 -> "12:34", 3725 -> "1:02:05"
function clock(seconds) {
  var s = Math.max(0, Math.ceil(seconds))
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  var sec = s % 60
  function pad(n) { return n < 10 ? "0" + n : String(n) }
  return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : pad(m) + ":" + pad(sec)
}

// Compact bar label: "14m" while more than a minute remains, "0:42" after.
function compact(seconds) {
  var s = Math.max(0, Math.ceil(seconds))
  if (s >= 3600) {
    var m = Math.floor((s % 3600) / 60)
    return Math.floor(s / 3600) + "h" + (m > 0 ? m + "m" : "")
  }
  if (s > 60) return Math.ceil(s / 60) + "m"
  return "0:" + (s < 10 ? "0" + s : s)
}

// 75 -> "1h 15m", 45 -> "45m", 0 -> "0m"
function duration(minutes) {
  var m = Math.max(0, Math.round(minutes))
  var h = Math.floor(m / 60)
  var rest = m % 60
  if (h === 0) return rest + "m"
  return rest === 0 ? h + "h" : h + "h " + rest + "m"
}

function phaseLabel(kind) {
  if (kind === "focus") return "Focus"
  if (kind === "micro") return "Micro-break"
  if (kind === "break") return "Long break"
  return "Ready"
}

var microIdeas = [
  "Look at something 20 feet away for 20 seconds.",
  "Close your eyes and relax your jaw.",
  "Roll your shoulders and neck slowly.",
  "Take five slow, deep breaths.",
  "Stretch your wrists and fingers.",
  "Sit up straight and unclench your hands."
]

var breakIdeas = [
  "Stand up and stretch your back and shoulders.",
  "Drink a glass of water.",
  "Walk around for a few minutes.",
  "Open a window and get some fresh air.",
  "Refill your coffee or tea.",
  "Step outside if you can.",
  "Tidy one small thing on your desk."
]

function idea(kind, seed) {
  var list = kind === "micro" ? microIdeas : breakIdeas
  var n = Math.abs(Math.floor(Number(seed) || 0))
  return list[n % list.length]
}

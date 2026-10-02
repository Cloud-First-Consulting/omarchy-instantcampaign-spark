.pragma library

function num(n) {
  n = Number(n)
  if (!isFinite(n)) return "—"
  if (Math.abs(n) >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, "") + "M"
  if (Math.abs(n) >= 1e4) return (n / 1e3).toFixed(1).replace(/\.0$/, "") + "k"
  return String(Math.round(n))
}

function pct(v) {
  v = Number(v)
  if (!isFinite(v)) return "—"
  return (Math.round(v * 10) / 10) + "%"
}

// Change vs the previous period. null means "no basis for a comparison"
// (the previous period had nothing), which is not the same as 0%.
function change(c) {
  if (c === null || c === undefined || !isFinite(Number(c))) return ""
  c = Number(c)
  if (c === 0) return "no change"
  return (c > 0 ? "▲ " : "▼ ") + Math.abs(Math.round(c * 10) / 10) + "%"
}

function changeIsGood(c, lowerIsBetter) {
  if (c === null || c === undefined || !isFinite(Number(c)) || Number(c) === 0) return null
  return lowerIsBetter ? Number(c) < 0 : Number(c) > 0
}

function ago(iso, nowMs) {
  if (!iso) return ""
  var ms = nowMs - Date.parse(iso)
  if (!isFinite(ms) || ms < 0) return "just now"
  var s = Math.floor(ms / 1000)
  if (s < 60) return "just now"
  var m = Math.floor(s / 60)
  if (m < 60) return m + " min ago"
  var h = Math.floor(m / 60)
  if (h < 48) return h + " h ago"
  return Math.floor(h / 24) + " days ago"
}

function seconds(s) {
  s = Number(s)
  if (!isFinite(s) || s <= 0) return "—"
  if (s < 60) return Math.round(s) + "s"
  return Math.floor(s / 60) + "m " + Math.round(s % 60) + "s"
}

function statusWord(s) {
  switch (String(s || "")) {
    case "ACTIVE": return "active"
    case "DRAFT": return "draft"
    case "GENERATING": return "generating"
    case "COMPLETED": return "completed"
    case "FAILED": return "failed"
    default: return String(s || "").toLowerCase()
  }
}

function verdictWord(v) {
  switch (String(v || "")) {
    case "HEALTHY": return "healthy"
    case "WATCH": return "watch"
    case "AT_RISK": return "at risk"
    case "NO_DATA": return "no sends yet"
    default: return String(v || "").toLowerCase()
  }
}

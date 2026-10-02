import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// InstantCampaign Spark: the workspace's numbers, in the bar.
//
// Strictly a display. The collector in bin/ asks the InstantCampaign MCP
// endpoint four questions and writes one JSON file; this panel draws whatever
// is in that file and nothing else. The key never passes through QML: the
// collector reads it from a file only the user can read.
Panel {
  id: root
  moduleName: "instantcampaign.spark"
  ipcTarget: "instantcampaign.spark"
  //   omarchy-shell ipc call instantcampaign.spark toggle
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ---- Settings (from this widget's shell.json entry) ----
  readonly property int refreshIntervalSec: Math.max(60, Number(setting("refreshIntervalSec", 300)))
  readonly property int days: Math.max(1, Number(setting("days", "7")))
  readonly property string baseUrl: String(setting("baseUrl", "https://instantcampaign.ai")).replace(/\/+$/, "")

  // ---- Where things are ----
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string collector: pluginDir + "bin/omarchy-instantcampaign-spark"
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/instantcampaign/spark.json"

  // ---- State ----
  property var snapshot: null
  property bool fetching: false
  property double nowMs: Date.now()

  readonly property var err: snapshot && snapshot.error ? snapshot.error : null
  readonly property var overview: snapshot && snapshot.overview ? snapshot.overview : null
  readonly property var analytics: snapshot && snapshot.analytics ? snapshot.analytics : null
  readonly property var cur: analytics && analytics.current ? analytics.current : null
  readonly property var chg: analytics && analytics.change ? analytics.change : ({})
  readonly property var domains: snapshot && snapshot.deliverability && snapshot.deliverability.domains ? snapshot.deliverability.domains : []
  readonly property var web: snapshot && snapshot.web ? snapshot.web : null
  readonly property var webCur: web && web.current ? web.current : null
  readonly property var webChg: web && web.change ? web.change : ({})
  readonly property var campaigns: overview && overview.recentCampaigns ? overview.recentCampaigns : []
  readonly property bool hasData: !!cur

  // A domain that needs a hand: not verified, DNS drifted, warm-up paused, or
  // a reputation verdict of AT_RISK. That, not a bad open rate, is what lights
  // the bar icon — it is the thing you cannot see from the numbers alone.
  readonly property var troubledDomains: {
    var out = []
    for (var i = 0; i < domains.length; i++) {
      var d = domains[i]
      var why = ""
      if (d.status !== "verified") why = "not verified"
      else if (d.dnsDriftDetectedAt) why = "DNS drift"
      else if (d.warmup && d.warmup.pausedReason) why = "warm-up paused"
      else if (d.reputation && d.reputation.verdict === "AT_RISK") why = "reputation at risk"
      if (why) out.push({ domain: d.domain, why: why })
    }
    return out
  }
  readonly property bool alarming: troubledDomains.length > 0 || (!!err && err.kind !== "nokey")

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

  // The hero's pill is a word or two; the meta line is the sentence.
  function heroPill() {
    if (err) {
      switch (err.kind) {
        case "nokey": return "not connected"
        case "auth": return "key rejected"
        case "scope": return "no mcp scope"
        case "network": return "offline"
        default: return "error"
      }
    }
    if (!cur) return fetching ? "fetching" : "no data"
    return days + " days"
  }

  function heroMeta() {
    if (err) return err.message || ""
    if (!cur) return "Press r to fetch."
    return Model.num(cur.dispatched) + " sent · " + Model.pct(cur.openRate) + " opened · " + Model.ago(snapshot.fetchedAt, nowMs)
  }

  function countsLine() {
    if (!overview || !overview.counts) return ""
    var c = overview.counts
    return Model.num(c.contacts) + " contacts · " + Model.num(c.campaigns) + " campaigns · "
         + Model.num(c.contactLists) + " lists · " + Model.num(c.segments) + " segments"
  }

  function refreshNow() {
    if (fetchProc.running) return
    fetching = true
    fetchProc.command = [collector, "fetch", "--days", String(days), "--base-url", baseUrl]
    fetchProc.running = true
  }

  function openApp(page) {
    if (bar) bar.run("'" + collector + "' open --base-url '" + baseUrl + "' " + (page || "analytics"))
  }

  function runSetup() {
    if (bar) bar.run("omarchy-launch-terminal '" + collector + "' setup --base-url '" + baseUrl + "'")
    close()
  }

  // ---- Data plumbing ----
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.snapshot = JSON.parse(String(text() || "")) } catch (e) { /* half-written; keep the last good one */ }
    }
    onLoadFailed: root.snapshot = null
  }

  // The collector renames a temp file over the state file so a read is never
  // half of each; that rename also loses the watch, so re-read on a timer too.
  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: { stateFile.reload(); root.nowMs = Date.now() }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshNow()
  }

  Process {
    id: fetchProc
    running: false
    command: []
    onExited: { root.fetching = false; stateFile.reload() }
  }

  onOpenedChanged: if (opened) { root.nowMs = Date.now(); stateFile.reload() }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
  }

  // ---- Bar ----
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰇮"
    active: root.alarming
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.openApp("analytics")
      else if (buttonCode === Qt.MiddleButton) root.refreshNow()
      else root.toggle()
    }
  }

  // ---- Panel ----
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(700))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          flick.contentY = root.clamp(flick.contentY + dy * Style.space(56), 0, Math.max(0, flick.contentHeight - flick.height))
      }
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshNow()
        else if (t === "o" || t === "O") root.openApp("analytics")
        else if (t === "d" || t === "D") root.openApp("deliverability")
        else if (t === "c" || t === "C") root.openApp("campaigns")
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: flick.width
          spacing: Style.space(12)

          // ---------- Hero ----------
          PanelHero {
            width: parent.width
            title: "InstantCampaign"
            meta: root.heroMeta()
            detail: root.heroPill()
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Item {
                width: Style.font.display
                height: Style.font.display
                Image {
                  id: mark
                  anchors.fill: parent
                  source: Qt.resolvedUrl("assets/mark.svg")
                  sourceSize.width: Style.font.display * 2
                  sourceSize.height: Style.font.display * 2
                  fillMode: Image.PreserveAspectFit
                }
                Text {
                  anchors.centerIn: parent
                  visible: mark.status !== Image.Ready
                  text: "󰇮"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }

            trailingControl: Component {
              PanelActionButton {
                iconText: root.fetching ? "󰔟" : "󰑐"
                tooltipText: "Refresh (r)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: root.refreshNow()
              }
            }
          }

          Text {
            visible: root.hasData && root.countsLine() !== ""
            width: parent.width
            text: root.countsLine()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          // ---------- Not connected ----------
          Column {
            visible: !root.hasData && (!root.err || root.err.kind === "nokey" || root.err.kind === "auth" || root.err.kind === "scope")
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: root.err && root.err.kind !== "nokey"
                    ? "The stored API key did not work. Make a new one with the mcp scope and run setup again."
                    : "Connect this widget to your workspace with an API key that has the mcp scope. Setup asks for the key once and keeps it in a file only you can read."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Row {
              spacing: Style.space(8)
              PanelActionButton {
                iconText: "󰌆"
                tooltipText: "Enter an API key"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: root.runSetup()
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Set up in a terminal"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
            }
            Row {
              spacing: Style.space(8)
              PanelActionButton {
                iconText: "󰏌"
                tooltipText: "Open the API keys page"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: root.openApp("settings/api-keys")
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Create a key in InstantCampaign"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          // ---------- Email ----------
          Column {
            visible: root.hasData
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader { width: parent.width; text: "EMAIL"; foreground: root.foreground; fontFamily: root.fontFamily }

            Grid {
              width: parent.width
              columns: 2
              columnSpacing: Style.space(10)
              rowSpacing: Style.space(8)
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Sent"; value: root.cur ? Model.num(root.cur.dispatched) : "—"; delta: root.chg.dispatched }
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Delivered"; value: root.cur ? Model.pct(root.cur.deliveryRate) : "—"; delta: root.chg.deliveryRate }
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Open rate"; value: root.cur ? Model.pct(root.cur.openRate) : "—"; delta: root.chg.openRate }
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Click rate"; value: root.cur ? Model.pct(root.cur.clickRate) : "—"; delta: root.chg.clickRate }
            }

            RateRow { width: parent.width; label: "Opened"; rate: root.cur ? root.cur.openRate : -1 }
            RateRow { width: parent.width; label: "Clicked"; rate: root.cur ? root.cur.clickRate : -1 }
            RateRow { width: parent.width; label: "Bounced"; rate: root.cur ? root.cur.bounceRate : -1; bad: true; threshold: 2 }
          }

          PanelSeparator { visible: root.hasData && root.campaigns.length > 0; width: parent.width; foreground: root.foreground }

          // ---------- Campaigns ----------
          Column {
            visible: root.hasData && root.campaigns.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader { width: parent.width; text: "RECENT CAMPAIGNS"; foreground: root.foreground; fontFamily: root.fontFamily }

            Repeater {
              model: root.campaigns
              Item {
                width: column.width
                height: Style.space(24)
                Text {
                  anchors.left: parent.left
                  anchors.right: status.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  text: String(modelData.name || "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
                Text {
                  id: status
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.statusWord(modelData.status)
                  color: modelData.status === "FAILED" ? root.urgent
                       : modelData.status === "ACTIVE" ? root.accent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          PanelSeparator { visible: root.hasData && root.domains.length > 0; width: parent.width; foreground: root.foreground }

          // ---------- Deliverability ----------
          Column {
            visible: root.hasData && root.domains.length > 0
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader { width: parent.width; text: "SENDING DOMAINS"; foreground: root.foreground; fontFamily: root.fontFamily }

            Repeater {
              model: root.domains
              Column {
                width: column.width
                spacing: Style.space(4)
                readonly property var d: modelData
                readonly property var w: d.warmup || null
                readonly property var rep: d.reputation || null
                readonly property string trouble: {
                  for (var i = 0; i < root.troubledDomains.length; i++)
                    if (root.troubledDomains[i].domain === d.domain) return root.troubledDomains[i].why
                  return ""
                }

                Item {
                  width: parent.width
                  height: Style.space(20)
                  Text {
                    anchors.left: parent.left
                    anchors.right: verdict.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(d.domain || "")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideMiddle
                  }
                  Text {
                    id: verdict
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: trouble ? trouble : (rep ? Model.verdictWord(rep.verdict) : "")
                    color: trouble ? root.urgent : (rep && rep.verdict === "HEALTHY" ? root.accent : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Meter {
                  visible: !!w && Number(w.todayCap) > 0
                  width: parent.width
                  value: w && Number(w.todayCap) > 0 ? Number(w.sentToday) / Number(w.todayCap) : -1
                  alarming: parent.trouble !== ""
                }

                Text {
                  width: parent.width
                  text: w
                    ? (w.status === "COMPLETED" ? "warm-up complete · " : "warm-up day " + w.currentDay + " of " + w.totalDays + " · ")
                      + Model.num(w.sentToday) + " of " + Model.num(w.todayCap) + " today"
                      + (rep && rep.blocklistCount > 0 ? " · on " + rep.blocklistCount + " blocklist" + (rep.blocklistCount > 1 ? "s" : "") : "")
                    : (d.status || "")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }
          }

          PanelSeparator { visible: root.hasData && !!root.webCur; width: parent.width; foreground: root.foreground }

          // ---------- Website ----------
          Column {
            visible: root.hasData && !!root.webCur
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "WEBSITE" + (root.web && Number(root.web.live) > 0 ? " · " + root.web.live + " LIVE" : "")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              width: parent.width
              columns: 2
              columnSpacing: Style.space(10)
              rowSpacing: Style.space(8)
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Visitors"; value: root.webCur ? Model.num(root.webCur.visitors) : "—"; delta: root.webChg.visitors }
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Sessions"; value: root.webCur ? Model.num(root.webCur.sessions) : "—"; delta: root.webChg.sessions }
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Pageviews"; value: root.webCur ? Model.num(root.webCur.pageviews) : "—"; delta: root.webChg.pageviews }
              Kpi { width: (parent.width - Style.space(10)) / 2; label: "Bounce"; value: root.webCur ? Model.pct(root.webCur.bounceRate) : "—"; delta: root.webChg.bounceRate; lowerIsBetter: true }
            }

            Repeater {
              model: root.web && root.web.pages ? root.web.pages.slice(0, 3) : []
              Item {
                width: column.width
                height: Style.space(20)
                Text {
                  anchors.left: parent.left
                  anchors.right: views.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  text: String(modelData.label || modelData.path || modelData.key || "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                }
                Text {
                  id: views
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.num(modelData.pageviews !== undefined ? modelData.pageviews : (modelData.views !== undefined ? modelData.views : modelData.sessions))
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          // ---------- Footer ----------
          Text {
            width: parent.width
            topPadding: Style.space(4)
            text: root.hasData ? "r refresh · o analytics · c campaigns · d deliverability" : "r retry"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  // ---- Components ----

  // A number with its label and the change against the previous period.
  component Kpi: Column {
    id: kpi
    property string label: ""
    property string value: "—"
    property var delta: null
    property bool lowerIsBetter: false
    readonly property var good: Model.changeIsGood(delta, lowerIsBetter)
    spacing: Style.space(1)

    Text {
      text: kpi.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    Text {
      text: kpi.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
      font.weight: Font.DemiBold
    }
    Text {
      text: Model.change(kpi.delta)
      visible: text !== ""
      color: kpi.good === null ? root.dim : (kpi.good ? root.accent : root.urgent)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // A labelled rate with a meter; "bad" rates light up past a threshold.
  component RateRow: Column {
    id: rateRow
    property string label: ""
    property real rate: -1
    property bool bad: false
    property real threshold: 100
    readonly property bool alarming: bad && rate >= threshold
    spacing: Style.space(4)

    Item {
      width: parent.width
      height: Style.space(16)
      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: rateRow.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: rateRow.rate >= 0 ? Model.pct(rateRow.rate) : "—"
        color: rateRow.alarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    Meter { width: parent.width; value: rateRow.rate >= 0 ? rateRow.rate / 100 : -1; alarming: rateRow.alarming }
  }

  // Rounded track filled to a fraction.
  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    implicitHeight: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    Rectangle { id: meterTrack; anchors.fill: parent; radius: height / 2; color: root.track }
    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.alarming ? root.urgent : root.accent
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
  }
}

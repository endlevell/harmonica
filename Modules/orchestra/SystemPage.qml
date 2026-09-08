import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// CENTER page (default) — Immersive system metrics.
// Three interactive gauge cards (CPU/RAM/Battery) up top, a live network card
// with throughput, and a memory history strip. Centered, hover-reactive, animated.
Item {
    id: page

    Component.onCompleted: { CpuRam.acquire(); Network.acquire(); }
    Component.onDestruction: { CpuRam.release(); Network.release(); }

    function fmtKbs(v: real): string {
        return v >= 1024 ? (v / 1024).toFixed(1) + " MB/s" : v.toFixed(0) + " KB/s";
    }
    function fmtGb(kb: int): string {
        return (kb / 1048576).toFixed(1) + " GB";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceLg
        anchors.rightMargin: Theme.spaceLg
        anchors.topMargin: Theme.spaceMd
        anchors.bottomMargin: Theme.spaceMd
        spacing: Theme.spaceMd

        // ---- Gauge cards: CPU · RAM · Battery ----------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            spacing: Theme.spaceSm

            component GaugeCard: Rectangle {
                id: card
                property real value: 0
                property color accent: Theme.primary
                property string cardLabel: ""
                property string cardValue: ""

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: hov.hovered ? Theme.surfaceHover : Theme.surface

                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                // flat card, hover fill only (no borders anywhere)
                HoverHandler { id: hov }


                CircularGauge {
                    anchors.centerIn: parent
                    width: 92
                    height: 92
                    value: card.value
                    gaugeColor: card.accent
                    trackColor: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.15)
                    label: card.cardLabel
                    valueText: card.cardValue
                    lineWidth: 8
                    scale: hov.hovered ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                }
            }

            GaugeCard {
                value: CpuRam.cpuPct
                accent: Theme.colorOk
                cardLabel: "CPU"
                cardValue: Math.round(CpuRam.cpuPct * 100) + "%"
            }
            GaugeCard {
                value: CpuRam.memPct
                accent: Theme.primary
                cardLabel: "RAM"
                cardValue: Math.round(CpuRam.memPct * 100) + "%"
            }
            GaugeCard {
                value: Battery.present ? Battery.percentage / 100 : 1
                accent: Battery.present
                    ? (Battery.percentage > 60 ? Theme.colorOk : (Battery.percentage > 30 ? Theme.warn : Theme.danger))
                    : Theme.colorOk
                cardLabel: Battery.present ? (Battery.charging ? "CHARGING" : "BATTERY") : "POWER"
                cardValue: Battery.present ? Battery.percentage + "%" : "AC"
            }
        }

        // ---- Network card -----------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: Theme.radiusMd
            color: netHov.hovered ? Theme.surfaceHover : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            HoverHandler { id: netHov }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceMd
                spacing: Theme.spaceMd

                // status icon in a tinted disc
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Theme.radiusFull
                    color: Network.state === "disconnected"
                        ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        : Qt.rgba(Theme.colorNet.r, Theme.colorNet.g, Theme.colorNet.b, 0.2)
                    Behavior on color { ColorAnimation { duration: Theme.durNormal } }

                    Icon {
                        anchors.centerIn: parent
                        category: "status"
                        name: Network.state === "ethernet" ? "ethernet"
                            : Network.state === "wifi" ? "wifi" : "wifi-off"
                        size: 22
                        color: Network.state === "disconnected" ? Theme.outline : Theme.colorNet
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        Text {
                            text: Network.state === "ethernet" ? "Ethernet"
                                : Network.state === "wifi" ? (Network.ssid || "Wi-Fi")
                                : "Disconnected"
                            color: Theme.foreground
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        PulseRing {
                            Layout.preferredWidth: 9
                            Layout.preferredHeight: 9
                            ringColor: Theme.colorNet
                            active: Network.state !== "disconnected"
                        }
                    }

                    Text {
                        visible: Network.ip !== ""
                        text: Network.ip
                        color: Theme.dimText
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontMono
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // throughput
                ColumnLayout {
                    visible: Network.state !== "disconnected"
                    spacing: 4

                    component Rate: RowLayout {
                        property color tint: Theme.foreground
                        property bool up: false
                        property string rate: ""
                        spacing: Theme.spaceXs
                        Layout.alignment: Qt.AlignRight

                        // drawn triangle marker (down/up) — no glyph fonts
                        Shape {
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            Layout.alignment: Qt.AlignVCenter
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: "transparent"
                                fillColor: tint
                                startX: up ? 0 : 3.5
                                startY: up ? 7 : 0
                                PathLine { x: up ? 7 : 0; y: up ? 7 : 7 }
                                PathLine { x: up ? 3.5 : 7; y: up ? 0 : 7 }
                            }
                        }
                        Text {
                            text: rate
                            color: tint
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Medium
                        }
                    }

                    Rate { tint: Theme.colorOk; up: false; rate: page.fmtKbs(Network.downKBs) }
                    Rate { tint: Theme.warn; up: true; rate: page.fmtKbs(Network.upKBs) }
                }
            }
        }

        // ---- Memory history strip ---------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMd
            color: Theme.surface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceXs

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "MEMORY"
                        color: Theme.dimText
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.fontTrackingWide
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: page.fmtGb(CpuRam.memTotalKb - CpuRam.memAvailKb) + " / " + page.fmtGb(CpuRam.memTotalKb)
                        color: Theme.foreground
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.DemiBold
                    }
                }

                LineGraph {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    values: CpuRam.memHistory
                    lineColor: Theme.warn
                    normalizeMax: 1
                }
            }
        }
    }
}

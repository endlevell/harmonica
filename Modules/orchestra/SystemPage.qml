import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// CENTER page (default) — Immersive system metrics with radial gauges and fluid motion.
// Bold, data-dense, visually striking. Circular gauges for CPU/RAM/Battery, network stats,
// animated indicators for active states.
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
        anchors.leftMargin: Theme.spaceXl
        anchors.rightMargin: Theme.spaceXl
        anchors.topMargin: Theme.spaceMd
        anchors.bottomMargin: Theme.spaceLg
        spacing: Theme.spaceMd

        // Top Row: Circular Gauges for CPU, RAM, Battery -----------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            // CPU Gauge
            CircularGauge {
                Layout.alignment: Qt.AlignCenter
                width: 82
                height: 82
                value: CpuRam.cpuPct
                gaugeColor: Theme.primary
                label: "CPU"
                valueText: Math.round(CpuRam.cpuPct * 100) + "%"
                lineWidth: 7
            }

            // RAM Gauge
            CircularGauge {
                Layout.alignment: Qt.AlignCenter
                width: 82
                height: 82
                value: CpuRam.memPct
                gaugeColor: Theme.warn
                label: "RAM"
                valueText: Math.round(CpuRam.memPct * 100) + "%"
                lineWidth: 7
            }

            // Battery Gauge
            CircularGauge {
                Layout.alignment: Qt.AlignCenter
                width: 82
                height: 82
                value: Battery.present ? Battery.percentage / 100 : 0
                gaugeColor: Battery.percentage > 60 ? Theme.colorOk : (Battery.percentage > 30 ? Theme.warn : Theme.danger)
                label: Battery.present ? "BAT" : "AC"
                valueText: Battery.present ? Battery.percentage + "%" : "∞"
                lineWidth: 7
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.3
        }

        // Network Section with live indicators ---------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            // Network Header
            RowLayout {
                Layout.fillWidth: true

                Icon {
                    category: "status"
                    name: Network.state === "wifi" ? "wifi" : "wifi-off"
                    size: 18
                    color: Network.state === "wifi" ? Theme.colorNet : Theme.outline
                }

                Text {
                    text: "NETWORK"
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                PulseRing {
                    width: 10
                    height: 10
                    ringColor: Theme.colorNet
                    active: Network.state === "wifi"
                }
            }

            // Network Details Card
            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: Theme.radiusSm
                color: Theme.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    // SSID / Status
                    Text {
                        visible: Network.state === "wifi"
                        text: Network.ssid || "Connected"
                        color: Theme.foreground
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: Network.state !== "wifi"
                        text: "Disconnected"
                        color: Theme.dimText
                        font.pixelSize: Theme.fontMd
                        Layout.fillWidth: true
                    }

                    // Speed indicators
                    Row {
                        visible: Network.state === "wifi"
                        spacing: Theme.spaceMd

                        Row {
                            spacing: Theme.spaceXs
                            Icon { category: "arrows"; name: "arrow-down"; size: 12; color: Theme.colorOk; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: fmtKbs(Network.downKbs)
                                color: Theme.foreground
                                font.pixelSize: Theme.fontXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: Theme.spaceXs
                            Icon { category: "arrows"; name: "arrow-up"; size: 12; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: fmtKbs(Network.upKbs)
                                color: Theme.foreground
                                font.pixelSize: Theme.fontXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // IP Address
                    Text {
                        visible: Network.state === "wifi" && Network.ip !== ""
                        text: Network.ip
                        color: Theme.dimText
                        font.pixelSize: Theme.fontXs
                        font.family: "monospace"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Bottom: Memory Details Mini-Graph ------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Text {
                text: "MEMORY USAGE · " + fmtGb(CpuRam.memTotalKb - CpuRam.memAvailKb) + " / " + fmtGb(CpuRam.memTotalKb)
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                font.weight: Font.Medium
                font.letterSpacing: 1
            }

            LineGraph {
                Layout.fillWidth: true
                height: 24
                values: CpuRam.memHistory
                lineColor: Theme.warn
            }
        }
    }
}

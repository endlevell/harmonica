import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// CENTER page (default) — live CPU / RAM graphs, network, battery.
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

    Grid {
        anchors.fill: parent
        anchors.margins: Theme.spaceLg
        columns: 2
        columnSpacing: Theme.spaceXl
        rowSpacing: Theme.spaceMd

        // CPU ----------------------------------------------------------
        Column {
            width: (parent.width - parent.columnSpacing) / 2
            spacing: Theme.spaceXs

            Row {
                spacing: Theme.spaceSm
                Icon { category: "system"; name: "cpu"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "CPU"; color: Theme.dimText; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Math.round(CpuRam.cpuPct * 100) + "%"; color: Theme.foreground; font.pixelSize: Theme.fontSm; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            LineGraph { width: parent.width; height: 44; values: CpuRam.cpuHistory; lineColor: Theme.primary }
        }

        // RAM ----------------------------------------------------------
        Column {
            width: (parent.width - parent.columnSpacing) / 2
            spacing: Theme.spaceXs

            Row {
                spacing: Theme.spaceSm
                Icon { category: "system"; name: "ram"; size: 16; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "RAM"; color: Theme.dimText; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: fmtGb(CpuRam.memTotalKb - CpuRam.memAvailKb) + " / " + fmtGb(CpuRam.memTotalKb)
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            LineGraph { width: parent.width; height: 44; values: CpuRam.memHistory; lineColor: Theme.warn; normalizeMax: 1 }
        }

        // NET ----------------------------------------------------------
        Row {
            width: (parent.width - parent.columnSpacing) / 2
            spacing: Theme.spaceSm

            Icon {
                category: "status"
                name: Network.state === "ethernet" ? "ethernet" : Network.state === "wifi" ? "wifi" : "wifi-off"
                size: 18
                color: Network.state === "disconnected" ? Theme.dimText : Theme.success
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: Network.state === "ethernet" ? "Ethernet" : Network.state === "wifi" ? (Network.ssid || "Wi-Fi") : "Disconnected"
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.parent.width - 40)
                }
                Text {
                    visible: Network.ip !== ""
                    text: Network.ip + "  ·  ↓" + fmtKbs(Network.downKBs) + " ↑" + fmtKbs(Network.upKBs)
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                }
            }
        }

        // BATTERY ------------------------------------------------------
        Row {
            width: (parent.width - parent.columnSpacing) / 2
            spacing: Theme.spaceSm

            Icon {
                category: "status"
                name: Battery.iconName
                size: 18
                color: Battery.charging ? Theme.primary : Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    visible: Battery.present
                    text: Battery.percentage + "%" + (Battery.charging ? " · charging" : "")
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: !Battery.present
                    text: "No battery"
                    color: Theme.dimText
                    font.pixelSize: Theme.fontSm
                }
                Text {
                    visible: Battery.present && Battery.full
                    text: "Full"
                    color: Theme.success
                    font.pixelSize: Theme.fontXs
                }
            }
        }
    }
}

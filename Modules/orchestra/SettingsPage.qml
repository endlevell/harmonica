import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

// LEFT page — every Harmonica option lives here. Grows as features land.
Item {
    id: page

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceLg
        spacing: Theme.spaceSm

        Text {
            text: "Settings"
            color: Theme.dimText
            font.pixelSize: Theme.fontXs
            font.letterSpacing: 2
        }

        // --- General ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Text {
                text: "24-hour clock"
                color: Theme.foreground
                font.pixelSize: Theme.fontMd
                Layout.fillWidth: true
            }
            Toggle {
                checked: SettingsData.clock24h
                onToggled: SettingsData.clock24h = checked
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Text {
                text: "Show seconds"
                color: Theme.foreground
                font.pixelSize: Theme.fontMd
                Layout.fillWidth: true
            }
            Toggle {
                checked: SettingsData.showSeconds
                onToggled: SettingsData.showSeconds = checked
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            text: "harmonica v0.1 · settings persist to ~/.config/harmonica/config.json"
            color: Theme.outline
            font.pixelSize: Theme.fontXs
        }
    }
}

import QtQuick

// Neutral container — twitch disabled per user preference.
Item {
    id: tw

    default property alias content: holder.data
    function trigger(strength) { }

    Item {
        id: holder
        anchors.fill: parent
    }
}

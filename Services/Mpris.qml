pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Thin facade over Quickshell.Mpris — views bind to THESE properties only.
// All access null-guarded; no player connected → graceful empty states.
Singleton {
    id: root

    readonly property var players: Mpris.players?.values ?? []
    readonly property QtObject active: players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active ? (active.trackTitle || "Unknown title") : ""
    readonly property string artist: active ? (active.trackArtist || "") : ""
    readonly property string artUrl: active ? (active.trackArtUrl || "") : ""
    readonly property real lengthSecs: active?.length ?? 0
    readonly property real positionSecs: active?.position ?? 0
    readonly property bool canPlay: active?.canPlay ?? false
    readonly property bool canGoNext: active?.canGoNext ?? false
    readonly property bool canGoPrevious: active?.canGoPrevious ?? false

    function togglePlaying(): void { if (hasPlayer && canPlay) active.togglePlaying(); }
    function next(): void { if (canGoNext) active.next(); }
    function previous(): void { if (canGoPrevious) active.previous(); }

    // Docs pattern, verified: quickshell.org/docs/v0.3.0 MprisPlayer
    // ("emit the positionChanged signal manually using Timer when the
    // player is playing"); installed qmltypes confirm the position
    // property's notify signal is positionChanged. Re-emitting it
    // re-reads the value so progress bars move while playing.
    Timer {
        interval: 500
        running: root.playing
        repeat: true
        onTriggered: if (root.active) root.active.positionChanged()
    }
}

// Harmonica — composition root. Instantiates surfaces per screen; nothing else.
import QtQuick
import Quickshell
import qs.Modules.orchestra

Variants {
    model: Quickshell.screens
    Orchestra {}
}

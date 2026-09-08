pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Lock-screen controller: session lock state machine (ambient → auth →
// unlocking) with native PAM verification (no helpers, no setuid shims,
// no password-in-argv). Attempts counted locally with a 30s reset.
Singleton {
    id: root

    property bool engaged: false         // drives WlSessionLock.locked
    property string state: "ambient"     // ambient | auth | unlocking
    property int attemptsLeft: 3
    property string errorText: ""
    property bool checking: false
    property string _pending: ""
    readonly property string userName: {
        const u = Quickshell.env("USER");
        return (u && u.length > 0) ? u : "user";
    }

    function open(): void {
        engaged = true;
        state = "ambient";
        errorText = "";
        attemptsLeft = 3;
    }
    function wake(): void {
        if (engaged && state === "ambient") state = "auth";
    }
    function backToAmbient(): void {
        if (engaged && state === "auth") { state = "ambient"; errorText = ""; }
    }
    function submit(password: string): void {
        if (checking || !engaged || state !== "auth") return;
        if (password === "") return;
        checking = true;
        errorText = "";
        _pending = password;
        pam.abort();
        if (!pam.start()) {
            checking = false;
            _pending = "";
            errorText = "auth unavailable";
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: root.userName
        Component.onCompleted: {
            pam.pamMessage.connect(() => {
                if (pam.responseRequired && root._pending !== "") {
                    pam.respond(root._pending);
                    root._pending = "";
                } else if (pam.messageIsError && pam.message !== "") {
                    root.errorText = pam.message;
                }
            });
            pam.completed.connect(result => {
                root.checking = false;
                root._pending = "";
                if (result === PamResult.Success) {
                    root.state = "unlocking";
                    unlockTimer.restart();
                } else {
                    root.attemptsLeft--;
                    if (root.attemptsLeft <= 0 || result === PamResult.MaxTries) {
                        root.attemptsLeft = 0;
                        root.errorText = "No attempts left — wait 30s";
                        lockoutTimer.restart();
                    } else {
                        root.errorText = "Wrong password — " + root.attemptsLeft + " attempts left";
                    }
                }
            });
            pam.error.connect(error => {
                root.checking = false;
                root._pending = "";
                root.errorText = "auth unavailable";
            });
        }
    }

    Timer {
        id: unlockTimer
        interval: 260
        repeat: false
        onTriggered: root.engaged = false
    }
    Timer {
        id: lockoutTimer
        interval: 30000
        repeat: false
        onTriggered: { root.attemptsLeft = 3; root.errorText = ""; }
    }
}

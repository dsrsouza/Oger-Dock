import QtQuick

// R58.1: The Plasma configuration shell owns the top-level window. Keep it
// maximized without modifying its size constraints, flags, position or the
// separate nested edit dialogs. This non-visual helper is instantiated on
// EVERY selectable Punchi configuration page, so switching categories cannot
// accidentally re-enable restored-window editing.
QtObject {
    id: guard
    required property var hostWindow
    property bool updatePending: false
    // R62.6: record only unusually expensive KCM startup work. This is a
    // cheap, single-shot diagnostic, not a timer polling the GUI thread.
    property string diagnosticCategory: ""
    readonly property double diagnosticCreatedAt: Date.now()

    function reportSlowPageSetup() {
        const elapsed = Math.max(0, Date.now() - diagnosticCreatedAt)
        if (diagnosticCategory.length > 0 && elapsed >= 75) {
            console.warn("OgerDock Config [", diagnosticCategory,
                         "] page construction/event-loop:", elapsed, "ms")
        }
    }


    function enforceMaximized() {
        guard.updatePending = false
        const window = guard.hostWindow
        if (!window) return
        // Minimize, hide and close are deliberately not intercepted.
        // On Wayland, the compositor owns geometry; request maximization using
        // the public QQuickWindow API and only after a real visibility change.
        if (window.visibility === Window.Windowed
                || window.visibility === Window.FullScreen) {
            window.showMaximized()
        }
    }

    function scheduleMaximization() {
        if (guard.updatePending) return
        guard.updatePending = true
        Qt.callLater(guard.enforceMaximized)
    }

    onHostWindowChanged: scheduleMaximization()
    Component.onCompleted: {
        scheduleMaximization()
        Qt.callLater(guard.reportSlowPageSetup)
    }

    // Connections is an object-valued property, NOT a visual child; adding
    // this guard cannot affect Kirigami.SimpleKCM's content/layout selection.
    property Connections visibilityWatcher: Connections {
        target: guard.hostWindow
        function onVisibilityChanged() { guard.scheduleMaximization() }
    }
}

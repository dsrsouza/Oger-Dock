import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root
    property bool trayOnly: false
    property bool active: false
    property bool demandsAttention: false
    property int count: 0
    property int minimizedCount: 0
    property int maximizedCount: 0
    property bool motionEnabled: true
    property string type: "line"
    property string position: "bottom"
    property int thickness: 4
    property real indicatorOpacity: 1.0
    property color customColor: "transparent"
    property int iconSize: 48
    property bool neonEnabled: true
    property real neonIntensity: 0.65
    // No halo for closed launchers; the indicator is never created without windows.
    readonly property real glowAlpha: neonEnabled && count > 0
        ? Math.max(0, Math.min(1, neonIntensity)) : 0

    readonly property bool hiddenIndicator: type === "none" || count <= 0
    // The minimized state wins for a group containing mixed window states.
    readonly property string windowState: minimizedCount > 0 ? "minimized"
        : maximizedCount > 0 ? "maximized" : "normal"
    readonly property color baseColor: customColor.a > 0
        ? customColor : Kirigami.Theme.highlightColor
    // Mix foreground with the same hue towards the theme's light text.
    // No per-application rainbow palette and no hover-dependent states.
    readonly property color focusedColor: Qt.rgba(
        Math.min(1, baseColor.r * 0.75 + Kirigami.Theme.textColor.r * 0.25),
        Math.min(1, baseColor.g * 0.75 + Kirigami.Theme.textColor.g * 0.25),
        Math.min(1, baseColor.b * 0.75 + Kirigami.Theme.textColor.b * 0.25), 1)
    // Tray-only applications retain the same line/dot/ring, scale and neon
    // layers as ordinary tasks. Only the accent differs (no special tiny ring).
    readonly property color trayAccentColor: Qt.rgba(0.16, 0.82, 0.50, 1)
    readonly property color resolvedColor: demandsAttention ? Kirigami.Theme.negativeTextColor
        : (trayOnly ? trayAccentColor : (active ? focusedColor : baseColor))
    readonly property real resolvedOpacity: Math.max(0.0, Math.min(1.0, indicatorOpacity))
    readonly property real sizeHint: Math.max(2, thickness)
    // A background window gets a quiet 20%-width mark; the foreground
    // gets a readable, luminous mark. Neither scales with the app icon.
    readonly property real dimensionRatio: active ? (windowState === "minimized" ? 0.66 : 0.55) : 0.20
    readonly property real lineWidth: Math.max(sizeHint * 1.5,
        Math.min(iconSize * 0.82, iconSize * dimensionRatio
            + (active ? Math.min(3, Math.max(0, count - 1)) * 1.5 : 0)))
    readonly property real symbolScale: windowState === "minimized" ? 1.22
        : windowState === "maximized" ? 0.78 : 1.0
    readonly property real dotSize: Math.max(sizeHint + 3,
        Math.min(iconSize * 0.18, 12)) * symbolScale
    readonly property real ringSize: Math.max(sizeHint + 6,
        Math.min(iconSize * 0.2, 14)) * symbolScale
    readonly property real ringStrokeWidth: Math.max(1, Math.min(3, sizeHint * 0.45))

    visible: !hiddenIndicator
    opacity: resolvedOpacity

    // Three lightweight halo layers: visibly luminous without an expensive blur
    // texture per task. They render only for open windows.
    Rectangle {
        visible: root.neonEnabled && root.glowAlpha > 0
            && edgeIndicator.visible
        x: edgeIndicator.x - 8
        y: edgeIndicator.y - 5
        width: edgeIndicator.width + 16
        height: edgeIndicator.height + 10
        radius: Math.min(width, height) / 2
        color: root.resolvedColor
        opacity: root.glowAlpha * (root.active ? 0.46 : 0.24)
    }
    Rectangle {
        visible: root.neonEnabled && root.glowAlpha > 0
            && edgeIndicator.visible
        x: edgeIndicator.x - 5
        y: edgeIndicator.y - 3
        width: edgeIndicator.width + 10
        height: edgeIndicator.height + 6
        radius: Math.min(width, height) / 2
        color: root.resolvedColor
        opacity: root.glowAlpha * (root.active ? 0.75 : 0.40)
    }

    Rectangle {
        visible: root.neonEnabled && root.glowAlpha > 0
            && edgeIndicator.visible
        x: edgeIndicator.x - 2
        y: edgeIndicator.y - 1
        width: edgeIndicator.width + 4
        height: edgeIndicator.height + 2
        radius: Math.min(width, height) / 2
        color: root.resolvedColor
        opacity: root.glowAlpha * (root.active ? 0.90 : 0.55)
    }

    Rectangle {
        id: edgeIndicator
        objectName: "dockWindowStateIndicator"
        visible: root.type === "line" || root.type === "dot"
            || root.type === "square" || root.type === "ring"
        width: root.type === "line"
            ? ((root.position === "left" || root.position === "right")
                ? root.sizeHint : root.lineWidth)
            : (root.type === "ring" ? root.ringSize
                : root.dotSize + (root.type === "square" ? 2 : 0))
        height: root.type === "line"
            ? ((root.position === "left" || root.position === "right")
                ? root.lineWidth : root.sizeHint)
            : width
        x: root.position === "left" ? 1
            : root.position === "right" ? root.width - width - 1
            : Math.round((root.width - width) / 2)
        // Stay INSIDE the component's geometry. Previously this was placed
        // outside, so clipping by Plasma erased the line on maximization.
        y: root.position === "top" ? 1
            : root.position === "bottom" ? root.height - height - 1
            : Math.round((root.height - height) / 2)
        radius: root.type === "square" ? Math.max(2, root.dotSize * 0.28)
            : Math.min(width, height) / 2
        color: root.type === "ring" ? "transparent" : root.resolvedColor
        border.width: root.type === "ring" ? root.ringStrokeWidth : 0
        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        border.color: root.resolvedColor

        Behavior on width {
            enabled: root.motionEnabled && Kirigami.Units.longDuration > 0
            NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: root.motionEnabled && Kirigami.Units.longDuration > 0
            NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
        }
    }
}

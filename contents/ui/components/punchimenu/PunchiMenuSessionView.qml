import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Dedicated session page. Only three session actions; never rendered over
// the applications grid. No theme-dependent nested icon/text card layouts.
// qmllint disable unqualified
FocusScope {
    id: root
    required property string userName
    required property url userAvatar
    required property bool canLogout
    required property bool canRestart
    required property bool canShutdown
    signal logoutRequested()
    signal restartRequested()
    signal shutdownRequested()

    readonly property bool verticalActions: width < Kirigami.Units.gridUnit * 27
    readonly property int actionHeight: Math.max(62, Kirigami.Units.gridUnit * 3.8)

    function focusInitialAction(reason) {
        const focusReason = reason === undefined ? Qt.PopupFocusReason : reason
        if (logoutButton.enabled) logoutButton.forceActiveFocus(focusReason)
        else if (restartButton.enabled) restartButton.forceActiveFocus(focusReason)
        else if (shutdownButton.enabled) shutdownButton.forceActiveFocus(focusReason)
        else root.forceActiveFocus(focusReason)
    }

    Flickable {
        id: surface
        objectName: "punchiMenuSessionScroll"
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: Math.max(height, actionColumn.implicitHeight
            + Kirigami.Units.largeSpacing * 3)
        interactive: contentHeight > height

        ColumnLayout {
            id: actionColumn
            width: Math.max(0, surface.width - Kirigami.Units.largeSpacing * 2)
            x: (surface.width - width) / 2
            y: Math.max(Kirigami.Units.largeSpacing,
                (surface.height - implicitHeight) / 2)
            spacing: Kirigami.Units.largeSpacing * 1.25

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18nc("@title", "Session")
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                columns: root.verticalActions ? 1 : 3
                columnSpacing: Kirigami.Units.smallSpacing * 2
                rowSpacing: Kirigami.Units.smallSpacing * 2

                PlasmaComponents.ToolButton {
                    id: logoutButton
                    objectName: "punchiMenuLogoutButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.actionHeight
                    enabled: root.canLogout
                    text: i18nc("@action:button", "Log Out")
                    icon.name: "system-log-out"
                    display: PlasmaComponents.AbstractButton.TextUnderIcon
                    Accessible.name: text
                    background: Rectangle {
                        radius: 10
                        color: parent.down || parent.hovered
                            ? Qt.alpha(Kirigami.Theme.textColor, 0.18)
                            : "transparent"
                        border.width: parent.activeFocus ? 2 : 1
                        border.color: Qt.alpha(Kirigami.Theme.textColor,
                            parent.activeFocus ? 0.92 : 0.28)
                    }
                    hoverEnabled: true
                    onClicked: root.logoutRequested()
                    KeyNavigation.right: restartButton
                }
                PlasmaComponents.ToolButton {
                    id: restartButton
                    objectName: "punchiMenuRestartButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.actionHeight
                    enabled: root.canRestart
                    text: i18nc("@action:button", "Restart")
                    icon.name: "system-reboot"
                    display: PlasmaComponents.AbstractButton.TextUnderIcon
                    Accessible.name: text
                    background: Rectangle {
                        radius: 10
                        color: parent.down || parent.hovered
                            ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                            : "transparent"
                        border.width: parent.activeFocus ? 2 : 1
                        border.color: Qt.alpha(Kirigami.Theme.highlightColor,
                            parent.activeFocus ? 0.92 : 0.28)
                    }
                    hoverEnabled: true
                    onClicked: root.restartRequested()
                    KeyNavigation.left: logoutButton
                    KeyNavigation.right: shutdownButton
                }
                PlasmaComponents.ToolButton {
                    id: shutdownButton
                    objectName: "punchiMenuShutdownButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.actionHeight
                    enabled: root.canShutdown
                    text: i18nc("@action:button", "Shut Down")
                    icon.name: "system-shutdown"
                    display: PlasmaComponents.AbstractButton.TextUnderIcon
                    Accessible.name: text
                    background: Rectangle {
                        radius: 10
                        color: parent.down || parent.hovered
                            ? Qt.alpha(Kirigami.Theme.negativeTextColor, 0.18)
                            : "transparent"
                        border.width: parent.activeFocus ? 2 : 1
                        border.color: Qt.alpha(Kirigami.Theme.negativeTextColor,
                            parent.activeFocus ? 0.92 : 0.28)
                    }
                    hoverEnabled: true
                    onClicked: root.shutdownRequested()
                    KeyNavigation.left: restartButton
                }
            }
        }
    }
}
// qmllint enable unqualified

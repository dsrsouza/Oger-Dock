import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import "components"

// Translation helpers are supplied by the KCM context.
// qmllint disable unqualified
KCM.SimpleKCM {
    id: page

    // R62.6: immediate category switch; do not animate the entire KCM.
    // Whole-page transforms cannot shorten control creation and cost frames.

    // R58.1: only this applet's configuration pages request maximized mode.
    // The KDE-owned window still handles its own close/minimize/Save dialog.
    ConfigMaximizedWindowGuard {
        hostWindow: page.Window.window
        diagnosticCategory: "Atalhos adicionais"
    }

    title: i18n("Additional Shortcuts")
    implicitWidth: layoutMetrics.pageImplicitWidth
    implicitHeight: contentColumn.implicitHeight

    ConfigLayoutMetrics {
        id: layoutMetrics
        availableWidth: page.width
    }

    property string cfg_punchiMenuShortcut: ""
    property bool updatingShortcut: false

    readonly property int contentWidthHint: layoutMetrics.contentWidth
    readonly property int selectorWidthHint: layoutMetrics.selectorWidth

    function syncShortcutControl() {
        updatingShortcut = true
        shortcutItem.keySequence = cfg_punchiMenuShortcut
        updatingShortcut = false
    }

    onCfg_punchiMenuShortcutChanged: syncShortcutControl()

    Component.onCompleted: syncShortcutControl()

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        Kirigami.FormLayout {
            Layout.fillWidth: true

            KQuickControls.KeySequenceItem {
                id: shortcutItem
                Kirigami.FormData.label: i18n("Open or close Oger Dock menu:")
                Layout.preferredWidth: page.selectorWidthHint
                Layout.maximumWidth: page.selectorWidthHint
                showCancelButton: true
                // Keep the Plasma 6.0-compatible properties. ShortcutPattern was
                // introduced in a later KF6 release.
                // qmllint disable deprecated
                modifierOnlyAllowed: true
                modifierlessAllowed: false
                // qmllint enable deprecated
                Accessible.name: i18n("Oger Dock menu keyboard shortcut")
                Accessible.description: i18n(
                    "Opens or closes the Oger Dock menu independently from Plasma's widget activation shortcut.")
                onKeySequenceModified: {
                    if (!page.updatingShortcut) {
                        // QKeySequence exposes toString() at runtime, but the Qt
                        // QML metadata does not advertise the method to qmllint.
                        // qmllint disable missing-property
                        page.cfg_punchiMenuShortcut = keySequence.toString()
                        // qmllint enable missing-property
                    }
                }
            }

            Controls.Label {
                text: i18n(
                    "This shortcut is independent from Plasma's widget activation shortcut.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.maximumWidth: page.contentWidthHint
                leftPadding: layoutMetrics.helperIndent
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}
// qmllint enable unqualified

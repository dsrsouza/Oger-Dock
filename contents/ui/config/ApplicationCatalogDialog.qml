// SPDX-License-Identifier: GPL-2.0-or-later
// R61: visual KDE catalog. Uses existing SystemDiscoveryManager/KApplicationTrader
// cache; no launcher is executed, and no configuration is written here.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.Dialog {
    id: root
    objectName: "applicationCatalogDialog"
    property var applications: []
    property var filteredApplications: []
    property var selectedIds: []
    property bool loading: false
    property string destination: "dock"
    readonly property bool singleSelectionMode: root.destination === "draft-app"
        || root.destination === "existing-app"
    signal applicationsChosen(var apps, string destination)
    signal manualEntryRequested(string destination)
    title: root.singleSelectionMode
        ? i18nc("@title:window", "Choose an installed application")
        : i18nc("@title:window", "Choose installed applications") // qmllint disable unqualified
    modal: true
    closePolicy: Controls.Popup.CloseOnEscape
    parent: Controls.Overlay.overlay
    width: Math.min(parent ? Math.max(240, parent.width - Kirigami.Units.gridUnit * 2) : 820,
        Kirigami.Units.gridUnit * 44)
    height: Math.min(parent ? Math.max(240, parent.height - Kirigami.Units.gridUnit * 2) : 720,
        Kirigami.Units.gridUnit * 40)
    x: parent ? Math.max(0, (parent.width - width) / 2) : 0
    y: parent ? Math.max(0, (parent.height - height) / 2) : 0
    leftPadding: Kirigami.Units.largeSpacing
    rightPadding: Kirigami.Units.largeSpacing
    topPadding: Kirigami.Units.largeSpacing
    bottomPadding: Kirigami.Units.largeSpacing

    function appKey(app) { return String(app.storageId || app.appId || "") }
    function start(destination) {
        root.destination = destination || "dock"
        root.selectedIds = []
        searchField.text = ""
        categoryChoice.currentIndex = 0
        root.updateFilter()
        root.open()
        Qt.callLater(function() { searchField.forceActiveFocus() })
    }
    function toggle(app) {
        const key = root.appKey(app)
        if (!key) return
        if (root.singleSelectionMode) {
            root.selectedIds = root.selectedIds.length === 1
                && root.selectedIds[0] === key ? [] : [key]
            return
        }
        const next = root.selectedIds.slice()
        const found = next.indexOf(key)
        if (found >= 0) next.splice(found, 1)
        else next.push(key)
        root.selectedIds = next
    }
    function updateFilter() {
        const query = searchField ? String(searchField.text || "").toLocaleLowerCase().trim() : ""
        const category = categoryChoice ? String(categoryChoice.currentValue || "") : ""
        const results = []
        for (const app of root.applications || []) {
            if (!root.appKey(app) || !String(app.command || "").trim()) continue
            const categories = app.categories || []
            if (category && categories.indexOf(category) < 0) continue
            const searchable = String(app.name || "") + " "
                + String(app.description || "") + " " + String(app.storageId || "")
            if (query && searchable.toLocaleLowerCase().indexOf(query) < 0) continue
            results.push(app)
        }
        results.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")))
        root.filteredApplications = results
    }
    onApplicationsChanged: root.updateFilter()
    onAccepted: {
        const ids = root.selectedIds.slice()
        const chosen = (root.applications || []).filter(app =>
            ids.indexOf(root.appKey(app)) >= 0)
        if (chosen.length > 0) root.applicationsChosen(chosen, root.destination)
    }
    Component.onCompleted: root.updateFilter()

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        Controls.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.singleSelectionMode
                ? i18nc("@info", "Choose one installed application to fill the current item automatically. Oger Dock uses the launcher registered with KDE.")
                : i18nc("@info", "Select one or more applications. Oger Dock uses the icons and launchers registered with KDE.") // qmllint disable unqualified
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Controls.TextField {
                id: searchField
                objectName: "catalogSearch"
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Search applications by name...") // qmllint disable unqualified
                onTextChanged: root.updateFilter()
            }
            Controls.ComboBox {
                id: categoryChoice
                objectName: "catalogCategory"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                textRole: "label"
                valueRole: "key"
                model: [
                    {key: "", label: i18nc("@item", "All")},
                    {key: "Network", label: i18nc("@item", "Internet")},
                    {key: "Graphics", label: i18nc("@item", "Graphics")},
                    {key: "Development", label: i18nc("@item", "Development")},
                    {key: "Office", label: i18nc("@item", "Office")},
                    {key: "AudioVideo", label: i18nc("@item", "Multimedia")},
                    {key: "Game", label: i18nc("@item", "Games")},
                    {key: "System", label: i18nc("@item", "System")},
                    {key: "Utility", label: i18nc("@item", "Utilities")}
                ] // qmllint disable unqualified
                onActivated: root.updateFilter()
            }
        }
        Controls.Label {
            Layout.fillWidth: true
            text: root.loading
                ? i18nc("@info", "Loading application catalog...")
                : i18ncp("@info", "%1 application found", "%1 applications found", root.filteredApplications.length) // qmllint disable unqualified
            opacity: 0.7
        }
        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ListView {
                id: catalogList
                objectName: "catalogAppList"
                model: root.filteredApplications
                spacing: Kirigami.Units.smallSpacing / 2
                clip: true
                reuseItems: true
                delegate: Controls.ItemDelegate {
                    id: appRow
                    required property var modelData
                    required property int index
                    readonly property bool chosen: root.selectedIds.indexOf(
                        root.appKey(modelData)) >= 0
                    width: catalogList.width
                    height: Kirigami.Units.gridUnit * 3.5
                    highlighted: chosen
                    onClicked: root.toggle(modelData)
                    Accessible.name: String(modelData.name || "")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Layout.preferredWidth
                            source: String(appRow.modelData.icon || "application-x-executable")
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Controls.Label {
                                text: String(appRow.modelData.name || "")
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Controls.Label {
                                text: String(appRow.modelData.description || appRow.modelData.storageId || "")
                                opacity: 0.65
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                        Kirigami.Icon {
                            source: appRow.chosen ? "emblem-ok-symbolic" : "list-add-symbolic"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Layout.preferredWidth
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label {
                Layout.fillWidth: true
                text: i18ncp("@info", "%1 selected", "%1 selected", root.selectedIds.length) // qmllint disable unqualified
            }
            Controls.Button {
                visible: !root.singleSelectionMode
                text: i18nc("@action:button", "Add manually...") // qmllint disable unqualified
                onClicked: {
                    const destination = root.destination
                    root.close()
                    root.manualEntryRequested(destination)
                }
            }
        }
    }
    standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
    onOpened: {
        const ok = root.standardButton(Controls.Dialog.Ok)
        if (ok) ok.enabled = Qt.binding(function() { return root.selectedIds.length > 0 })
        if (ok) ok.text = root.singleSelectionMode
            ? i18nc("@action:button", "Use selected")
            : i18nc("@action:button", "Add selected") // qmllint disable unqualified
        const cancel = root.standardButton(Controls.Dialog.Cancel)
        if (cancel) cancel.text = i18nc("@action:button", "Cancel") // qmllint disable unqualified
    }
}

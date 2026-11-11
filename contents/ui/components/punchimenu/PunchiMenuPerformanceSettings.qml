import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Common per-item settings; all modes use the same performance policy.
ColumnLayout {
    id: root
    property string performanceMode: "automatic"
    property int performanceThreshold: 120
    signal settingChanged(string fieldName, var value)
    spacing: Kirigami.Units.smallSpacing

    Kirigami.Heading {
        level: 3
        text: i18nc("@title:group", "Performance and animations") // qmllint disable unqualified
        Layout.fillWidth: true
    }
    Controls.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: i18nc("@info", "Reduce expensive effects when many applications are available; the menu keeps the same layout.") // qmllint disable unqualified
        opacity: 0.72
    }
    RowLayout {
        Layout.fillWidth: true
        Controls.Label { text: i18n("Mode:") } // qmllint disable unqualified
        Controls.ComboBox {
            Layout.fillWidth: true
            objectName: "punchiMenuPerformanceModeSelector"
            textRole: "text"
            valueRole: "value"
            model: [
                { "value": "automatic", "text": i18nc("@option", "Automatic (recommended)") },
                { "value": "economy", "text": i18nc("@option", "Economy") },
                { "value": "visual", "text": i18nc("@option", "Full visual effects") }
            ]
            currentIndex: root.performanceMode === "economy" ? 1
                : root.performanceMode === "visual" ? 2 : 0
            onActivated: root.settingChanged("performanceMode", currentValue)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        enabled: root.performanceMode === "automatic"
        Controls.Label { text: i18n("Application limit:") } // qmllint disable unqualified
        Controls.SpinBox {
            objectName: "punchiMenuPerformanceThreshold"
            Layout.fillWidth: true
            from: 40
            to: 400
            stepSize: 10
            editable: true
            value: root.performanceThreshold
            onValueModified: root.settingChanged("performanceThreshold", value)
        }
    }
}

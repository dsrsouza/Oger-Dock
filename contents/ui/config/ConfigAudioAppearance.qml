import QtQuick
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "components"

// R62.8: One KCM per category, in the style of Plasma System Settings.
// The configuration shell reads/writes the cfg_ properties from this root.
KCM.SimpleKCM {
    id: page
    ConfigMaximizedWindowGuard {
        hostWindow: page.Window.window
        diagnosticCategory: "Multimídia"
    }
    implicitWidth: settings.implicitWidth
    implicitHeight: settings.implicitHeight
    property alias cfg_audioSpectrumEnabled: settings.cfg_audioSpectrumEnabled
    property alias cfg_audioSpectrumIntensity: settings.cfg_audioSpectrumIntensity
    property alias cfg_audioSpectrumUsePlasmaTheme: settings.cfg_audioSpectrumUsePlasmaTheme
    property alias cfg_audioSpectrumBarCount: settings.cfg_audioSpectrumBarCount
    property alias cfg_audioSpectrumStyle: settings.cfg_audioSpectrumStyle
    property alias cfg_audioSpectrumBackgroundMode: settings.cfg_audioSpectrumBackgroundMode
    property alias cfg_audioSpectrumOrigin: settings.cfg_audioSpectrumOrigin
    property alias cfg_audioSpectrumFlow: settings.cfg_audioSpectrumFlow

    ConfigAudioVisualizer {
        id: settings
        width: page.width
        height: implicitHeight
    }
}

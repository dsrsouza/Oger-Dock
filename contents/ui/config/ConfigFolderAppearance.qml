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
        diagnosticCategory: "Pastas"
    }
    implicitWidth: settings.implicitWidth
    implicitHeight: settings.implicitHeight
    property alias cfg_folderCategoryColorsJson: settings.cfg_folderCategoryColorsJson
    property alias cfg_dockItemsJson: settings.cfg_dockItemsJson
    property alias cfg_folderGridIconSize: settings.cfg_folderGridIconSize
    property alias cfg_folderGridAutoLayout: settings.cfg_folderGridAutoLayout
    property alias cfg_folderGridColumns: settings.cfg_folderGridColumns
    property alias cfg_folderGridRows: settings.cfg_folderGridRows
    property alias cfg_folderGridShowLabels: settings.cfg_folderGridShowLabels
    property alias cfg_folderGridFontFamily: settings.cfg_folderGridFontFamily
    property alias cfg_folderGridFontSize: settings.cfg_folderGridFontSize
    property alias cfg_folderListIconSize: settings.cfg_folderListIconSize
    property alias cfg_folderListRows: settings.cfg_folderListRows
    property alias cfg_folderListShowLabels: settings.cfg_folderListShowLabels
    property alias cfg_folderListFontFamily: settings.cfg_folderListFontFamily
    property alias cfg_folderListFontSize: settings.cfg_folderListFontSize
    property alias cfg_folderDetailedIconSize: settings.cfg_folderDetailedIconSize
    property alias cfg_folderDetailedRows: settings.cfg_folderDetailedRows
    property alias cfg_folderDetailedShowLabels: settings.cfg_folderDetailedShowLabels
    property alias cfg_folderDetailedFontFamily: settings.cfg_folderDetailedFontFamily
    property alias cfg_folderDetailedFontSize: settings.cfg_folderDetailedFontSize
    property alias cfg_folderFanMotionStyle: settings.cfg_folderFanMotionStyle
    property alias cfg_folderFanIconSize: settings.cfg_folderFanIconSize
    property alias cfg_folderFanRows: settings.cfg_folderFanRows
    property alias cfg_folderFanShowLabels: settings.cfg_folderFanShowLabels
    property alias cfg_folderFanFontFamily: settings.cfg_folderFanFontFamily
    property alias cfg_folderFanFontSize: settings.cfg_folderFanFontSize
    property alias cfg_folderFanScrollEnabled: settings.cfg_folderFanScrollEnabled
    property alias cfg_folderPopupExtraDistance: settings.cfg_folderPopupExtraDistance
    property alias cfg_folderPopupDistancePercent: settings.cfg_folderPopupDistancePercent
    property alias cfg_folderPopupScale: settings.cfg_folderPopupScale
    property alias cfg_folderPopupBackgroundOpacityPercent: settings.cfg_folderPopupBackgroundOpacityPercent
    property alias cfg_folderPopupShowHeader: settings.cfg_folderPopupShowHeader
    property alias cfg_popupBackgroundBlurEnabled: settings.cfg_popupBackgroundBlurEnabled
    property alias cfg_popupTextShadowsEnabled: settings.cfg_popupTextShadowsEnabled
    property alias cfg_folderPopupTextShadowPercent: settings.cfg_folderPopupTextShadowPercent
    property alias cfg_popupAnimation: settings.cfg_popupAnimation
    property alias cfg_popupAnimationSpeedPercent: settings.cfg_popupAnimationSpeedPercent
    property alias cfg_popupAnimationIntensity: settings.cfg_popupAnimationIntensity

    ConfigFolderPopups {
        id: settings
        width: page.width
        height: implicitHeight
    }
}

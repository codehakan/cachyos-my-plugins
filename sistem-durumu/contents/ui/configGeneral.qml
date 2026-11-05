import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showCpu: cpuCheck.checked
    property alias cfg_showGpu: gpuCheck.checked
    property alias cfg_showLiquid: liquidCheck.checked
    property alias cfg_liquidInterval: liquidSpin.value

    property bool cfg_showCpuDefault
    property bool cfg_showGpuDefault
    property bool cfg_showLiquidDefault
    property int cfg_liquidIntervalDefault

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: cpuCheck
            Kirigami.FormData.label: i18n("Panelde göster:")
            text: i18n("İşlemci")
        }

        QQC2.CheckBox {
            id: gpuCheck
            text: i18n("Ekran kartı")
        }

        QQC2.CheckBox {
            id: liquidCheck
            text: i18n("Sıvı soğutma (liquidctl)")
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: liquidCheck.checked
            text: i18n("Corsair Commander cihazları her okumada donanım moduna dönüp ışıklarını yeniden başlatır; ışıklar okuma aralığında bir sönüp yanar.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.neutralTextColor
        }

        QQC2.SpinBox {
            id: liquidSpin
            Kirigami.FormData.label: i18n("Sıvı soğutma okuma aralığı (saniye):")
            enabled: liquidCheck.checked
            from: 2
            to: 600
        }
    }
}

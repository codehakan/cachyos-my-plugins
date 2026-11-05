import QtQuick
import QtQuick.Controls as QQC2
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

        QQC2.SpinBox {
            id: liquidSpin
            Kirigami.FormData.label: i18n("Sıvı soğutma okuma aralığı (saniye):")
            from: 2
            to: 60
        }
    }
}

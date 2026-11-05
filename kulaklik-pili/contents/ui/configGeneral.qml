import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_interval: intervalSpin.value
    property alias cfg_lowThreshold: thresholdSpin.value
    property alias cfg_hideWhenOff: hideCheck.checked

    property int cfg_intervalDefault
    property int cfg_lowThresholdDefault
    property bool cfg_hideWhenOffDefault

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Okuma aralığı (saniye):")
            from: 10
            to: 600
            stepSize: 10
        }

        QQC2.SpinBox {
            id: thresholdSpin
            Kirigami.FormData.label: i18n("Düşük pil uyarısı (%):")
            from: 0
            to: 50
            stepSize: 5
        }

        QQC2.CheckBox {
            id: hideCheck
            Kirigami.FormData.label: i18n("Kulaklık kapalıyken:")
            text: i18n("Göstergeyi gizle")
        }
    }
}

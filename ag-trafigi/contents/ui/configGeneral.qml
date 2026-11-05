import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_interval: intervalSpin.value
    property alias cfg_useBits: bitsRadio.checked

    property int cfg_intervalDefault
    property bool cfg_useBitsDefault

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Güncelleme aralığı (ms):")
            from: 500
            to: 10000
            stepSize: 500
        }

        QQC2.RadioButton {
            id: bytesRadio
            Kirigami.FormData.label: i18n("Birim:")
            text: i18n("Bayt (KB/sn, MB/sn)")
            checked: !bitsRadio.checked
        }

        QQC2.RadioButton {
            id: bitsRadio
            text: i18n("Bit (Kbit/sn, Mbit/sn)")
        }
    }
}

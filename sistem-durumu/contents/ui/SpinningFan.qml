import QtQuick
import org.kde.kirigami as Kirigami

// Devri ile orantılı hızda dönen fan simgesi
Kirigami.Icon {
    id: fan

    property real rpm: 0

    source: Qt.resolvedUrl("../images/fan.svg")
    isMask: true

    RotationAnimator on rotation {
        from: 0
        to: 360
        // Gerçek hız göze görünmez; 1300 rpm ≈ 0,9 sn'de bir tur
        duration: Math.max(250, Math.min(4000, 1200000 / Math.max(1, fan.rpm)))
        loops: Animation.Infinite
        running: fan.rpm > 0 && fan.visible
    }
}

import QtQuick
import org.kde.plasma.components as PlasmaComponents3

// Trafik varken kendi kutusu içinde akan ok; hız arttıkça akış hızlanır
Item {
    id: arrow

    property string glyph: "↓"
    property color color
    property int pixelSize
    // 0 (boşta) … 1 (çok hızlı)
    property real activity: 0

    readonly property bool active: activity > 0
    readonly property int direction: glyph === "↑" ? -1 : 1
    // Hız 4 kademeye bölünür; her küçük değişimde animasyon baştan başlamasın
    readonly property int speedLevel: Math.ceil(activity * 4)

    onSpeedLevelChanged: {
        if (flow.running) {
            flow.restart();
        }
    }

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true

    PlasmaComponents3.Label {
        id: label
        text: arrow.glyph
        color: arrow.color
        font.pixelSize: arrow.pixelSize
        font.bold: true
        opacity: arrow.active ? 1 : 0.45

        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // Kutudan çıkan okun yerine arkadan gelen ikinci ok
    PlasmaComponents3.Label {
        id: trail
        visible: arrow.active
        text: arrow.glyph
        color: arrow.color
        font: label.font
        y: label.y - arrow.direction * arrow.height
    }

    NumberAnimation {
        id: flow
        target: label
        property: "y"
        running: arrow.active && arrow.visible
        loops: Animation.Infinite
        from: 0
        to: arrow.direction * arrow.height
        duration: 1600 - 300 * arrow.speedLevel
        onRunningChanged: {
            if (!running) {
                label.y = 0;
            }
        }
    }
}

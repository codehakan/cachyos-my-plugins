import QtQuick
import org.kde.kirigami as Kirigami

// İnce sayaç çubuğu: iz dolgunun soluk tonu, dolgu yumuşakça kayar
Rectangle {
    id: meter

    property real fraction: 0
    property color fillColor: Kirigami.Theme.highlightColor

    implicitHeight: Math.max(4, Math.round(Kirigami.Units.smallSpacing * 1.5))
    radius: height / 2
    color: Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.18)

    Rectangle {
        height: parent.height
        radius: parent.radius
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, meter.fraction)))
        color: meter.fillColor
        visible: meter.fraction > 0.005

        Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 500 } }
    }
}

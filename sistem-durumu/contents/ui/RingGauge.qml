import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// 270°'lik halka gösterge: iz aynı rengin soluk tonu, dolgu parlar,
// ortadaki sayı yeni değere sayarak geçer
Item {
    id: gauge

    property real value: 0
    property real from: 0
    property real to: 100
    property color color: Kirigami.Theme.highlightColor
    property int decimals: 0
    property string unit: "°"
    property bool pulsing: false

    readonly property real thickness: Math.max(4, Math.round(width * 0.075))
    readonly property real radius: (Math.min(width, height) - thickness * 3) / 2
    readonly property real fraction: Math.max(0, Math.min(1, (value - from) / (to - from)))

    property real shownFraction: fraction
    property real shownValue: value
    property color shownColor: color

    Behavior on shownFraction { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on shownValue { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on shownColor { ColorAnimation { duration: 500 } }

    implicitWidth: Kirigami.Units.gridUnit * 5
    implicitHeight: implicitWidth

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: gauge.withAlpha(gauge.shownColor, 0.18)
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: gauge.width / 2
                centerY: gauge.height / 2
                radiusX: gauge.radius
                radiusY: gauge.radius
                startAngle: 135
                sweepAngle: 270
            }
        }
    }

    Shape {
        id: valueArc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: gauge.shownFraction > 0.001

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: gauge.shownColor
            shadowBlur: 0.7
            shadowScale: 1.02
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: glow.opacity
        }

        ShapePath {
            strokeColor: gauge.shownColor
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: gauge.width / 2
                centerY: gauge.height / 2
                radiusX: gauge.radius
                radiusY: gauge.radius
                startAngle: 135
                sweepAngle: 270 * gauge.shownFraction
            }
        }
    }

    // Parıltının şiddeti; kritikte nabız gibi atar
    Item {
        id: glow
        opacity: 0.8

        SequentialAnimation on opacity {
            running: gauge.pulsing
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
        }
    }

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(gauge.height * 0.02)

        PlasmaComponents3.Label {
            text: Number(gauge.shownValue).toLocaleString(Qt.locale(), "f", gauge.decimals)
            font.pixelSize: Math.round(gauge.width * 0.27)
            font.weight: Font.DemiBold
        }
        PlasmaComponents3.Label {
            text: gauge.unit
            font.pixelSize: Math.round(gauge.width * 0.16)
            opacity: 0.7
        }
    }
}

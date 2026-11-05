import QtQuick
import QtQuick.Shapes
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Son N saniyenin tek seri çizgisi: yumuşak alan dolgusu, son nokta vurgulu,
// üzerine gelince o anın değeri
Item {
    id: spark

    property var values: []
    property int capacity: 60
    property color color: Kirigami.Theme.highlightColor
    property int decimals: 0
    property string unit: " °C"

    readonly property real lowest: values.length ? Math.min(...values) : 0
    readonly property real highest: values.length ? Math.max(...values) : 0
    // Düz bir çizgi ortada dursun diye aralığa pay bırakılır
    readonly property real minV: lowest - Math.max(1, (highest - lowest) * 0.15)
    readonly property real maxV: highest + Math.max(1, (highest - lowest) * 0.15)
    readonly property real step: width / Math.max(1, capacity - 1)
    readonly property real plotTop: 4
    readonly property real plotBottom: height - 4

    function px(i) {
        return width - (values.length - 1 - i) * step;
    }

    function py(v) {
        return plotBottom - (v - minV) / (maxV - minV) * (plotBottom - plotTop);
    }

    function format(v) {
        return Number(v).toLocaleString(Qt.locale(), "f", decimals) + unit;
    }

    readonly property var points: values.map((v, i) => Qt.point(px(i), py(v)))
    readonly property point lastPoint: points.length ? points[points.length - 1] : Qt.point(0, 0)

    readonly property int hoverIndex: {
        if (!hover.containsMouse || values.length === 0) {
            return -1;
        }
        const i = values.length - 1 - Math.round((width - hover.mouseX) / step);
        return Math.max(0, Math.min(values.length - 1, i));
    }

    implicitHeight: Kirigami.Units.gridUnit * 2.5

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: spark.points.length > 1

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: spark.plotTop
                x2: 0; y2: spark.height
                GradientStop { position: 0; color: Qt.rgba(spark.color.r, spark.color.g, spark.color.b, 0.3) }
                GradientStop { position: 1; color: Qt.rgba(spark.color.r, spark.color.g, spark.color.b, 0) }
            }
            PathPolyline {
                path: spark.points.length > 1
                      ? spark.points.concat([Qt.point(spark.lastPoint.x, spark.height),
                                             Qt.point(spark.points[0].x, spark.height)])
                      : []
            }
        }

        ShapePath {
            strokeColor: spark.color
            strokeWidth: 2
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: spark.points }
        }
    }

    // Son değer: zemin renginde halkalı vurgu noktası
    Rectangle {
        visible: spark.points.length > 0 && spark.hoverIndex < 0
        width: 8
        height: 8
        radius: 4
        x: spark.lastPoint.x - width / 2
        y: spark.lastPoint.y - height / 2
        color: spark.color
        border.color: Kirigami.Theme.backgroundColor
        border.width: 2
    }

    // Üzerine gelince dikey çizgi, nokta ve değer
    Rectangle {
        visible: spark.hoverIndex >= 0
        x: spark.hoverIndex >= 0 ? Math.round(spark.px(spark.hoverIndex)) : 0
        width: 1
        height: spark.height
        color: Kirigami.Theme.textColor
        opacity: 0.35
    }

    Rectangle {
        visible: spark.hoverIndex >= 0
        width: 8
        height: 8
        radius: 4
        x: spark.hoverIndex >= 0 ? spark.px(spark.hoverIndex) - width / 2 : 0
        y: spark.hoverIndex >= 0 ? spark.py(spark.values[spark.hoverIndex]) - height / 2 : 0
        color: spark.color
        border.color: Kirigami.Theme.backgroundColor
        border.width: 2
    }

    Rectangle {
        id: readout
        visible: spark.hoverIndex >= 0
        readonly property real anchorX: spark.hoverIndex >= 0 ? spark.px(spark.hoverIndex) : 0
        x: anchorX + width + 8 > spark.width ? anchorX - width - 6 : anchorX + 6
        y: 0
        width: readoutLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        height: readoutLabel.implicitHeight + Kirigami.Units.smallSpacing
        radius: Kirigami.Units.smallSpacing
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

        PlasmaComponents3.Label {
            id: readoutLabel
            anchors.centerIn: parent
            font: Kirigami.Theme.smallFont
            text: {
                if (spark.hoverIndex < 0) {
                    return "";
                }
                const ago = spark.values.length - 1 - spark.hoverIndex;
                const when = ago === 0 ? i18n("Şimdi") : i18n("%1 sn önce", ago);
                return when + " · " + spark.format(spark.values[spark.hoverIndex]);
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}

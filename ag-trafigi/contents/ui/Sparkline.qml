import QtQuick
import QtQuick.Shapes
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Son N saniyenin hız çizgisi: sıfırdan başlayan eksen, yumuşak alan dolgusu,
// son nokta vurgulu, üzerine gelince o anın değeri
Item {
    id: spark

    property var values: []
    property int capacity: 60
    property color color: Kirigami.Theme.linkColor
    // Değeri metne çeviren fonksiyon; dışarıdan verilir
    property var formatValue: v => String(v)
    // Boşta çizgi tabana yapışmasın diye eksenin en az bu kadar yüksek olması
    property real minimumMax: 1024

    readonly property real maxV: Math.max(minimumMax, values.length ? Math.max(...values) * 1.15 : 0)
    readonly property real step: width / Math.max(1, capacity - 1)
    readonly property real plotTop: 4
    readonly property real plotBottom: height - 2

    function px(i) {
        return width - (values.length - 1 - i) * step;
    }

    function py(v) {
        return plotBottom - Math.max(0, v) / maxV * (plotBottom - plotTop);
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

    implicitHeight: Kirigami.Units.gridUnit * 3

    // Taban çizgisi
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: spark.plotBottom
        height: 1
        color: Kirigami.Theme.textColor
        opacity: 0.12
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: spark.points.length > 1

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: spark.plotTop
                x2: 0; y2: spark.plotBottom
                GradientStop { position: 0; color: Qt.rgba(spark.color.r, spark.color.g, spark.color.b, 0.35) }
                GradientStop { position: 1; color: Qt.rgba(spark.color.r, spark.color.g, spark.color.b, 0.02) }
            }
            PathPolyline {
                path: spark.points.length > 1
                      ? spark.points.concat([Qt.point(spark.lastPoint.x, spark.plotBottom),
                                             Qt.point(spark.points[0].x, spark.plotBottom)])
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

    // Son değer: zemin renginde halkalı, nabız gibi atan vurgu noktası
    Rectangle {
        id: lastDot
        visible: spark.points.length > 0 && spark.hoverIndex < 0
        width: 8
        height: 8
        radius: 4
        x: spark.lastPoint.x - width / 2
        y: spark.lastPoint.y - height / 2
        color: spark.color
        border.color: Kirigami.Theme.backgroundColor
        border.width: 2

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: "transparent"
            border.color: spark.color
            border.width: 1.5

            NumberAnimation on scale {
                running: lastDot.visible
                loops: Animation.Infinite
                from: 1
                to: 2.6
                duration: 1400
                easing.type: Easing.OutCubic
            }
            NumberAnimation on opacity {
                running: lastDot.visible
                loops: Animation.Infinite
                from: 0.8
                to: 0
                duration: 1400
                easing.type: Easing.OutCubic
            }
        }
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
                return when + " · " + spark.formatValue(spark.values[spark.hoverIndex]);
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

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool useBits: Plasmoid.configuration.useBits
    readonly property real downRate: Number(downSensor.value) || 0
    readonly property real upRate: Number(upSensor.value) || 0
    readonly property var down: formatRate(downRate)
    readonly property var up: formatRate(upRate)

    // Seri renkleri; durum renkleri (turuncu/kırmızı) uyarıya ayrıldığı için kullanılmaz
    readonly property color downColor: Kirigami.Theme.linkColor
    readonly property color upColor: Kirigami.Theme.visitedLinkColor

    // Bu hızın altı "boşta" sayılır ve soluk gösterilir
    readonly property real idleRate: 1024

    // Açılır penceredeki grafikler için son 60 saniye
    readonly property int historySize: 60
    property var downHistory: []
    property var upHistory: []

    Plasmoid.icon: "network-transmit-receive"
    toolTipMainText: i18n("Ağ Trafiği")
    toolTipSubText: "↓ " + down.number + " " + down.unit + "   ↑ " + up.number + " " + up.unit

    // Genişlik sabit kalsın diye en fazla 3 karakterlik sayı üretir: "999", "99", "9,9"
    function formatRate(bytesPerSec) {
        const units = useBits ? ["bit/sn", "Kbit/sn", "Mbit/sn", "Gbit/sn"]
                              : ["B/sn", "KB/sn", "MB/sn", "GB/sn"];
        const base = useBits ? 1000 : 1024;
        let value = Math.max(0, bytesPerSec) * (useBits ? 8 : 1);
        let i = 0;
        while (value >= 1000 && i < units.length - 1) {
            value /= base;
            i++;
        }
        const decimals = i > 0 && value < 10 ? 1 : 0;
        return {
            number: Number(value).toLocaleString(Qt.locale(), "f", decimals),
            unit: units[i]
        };
    }

    function rateText(bytesPerSec) {
        const r = formatRate(bytesPerSec);
        return r.number + " " + r.unit;
    }

    function formatSize(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = Math.max(0, Number(bytes) || 0);
        let i = 0;
        while (value >= 1024 && i < units.length - 1) {
            value /= 1024;
            i++;
        }
        return Number(value).toLocaleString(Qt.locale(), "f", i > 0 ? 1 : 0) + " " + units[i];
    }

    function pushHistory(list, value) {
        const next = list.concat([value]);
        return next.length > historySize ? next.slice(next.length - historySize) : next;
    }

    Sensors.Sensor {
        id: downSensor
        sensorId: "network/all/download"
        updateRateLimit: Plasmoid.configuration.interval
    }

    Sensors.Sensor {
        id: upSensor
        sensorId: "network/all/upload"
        updateRateLimit: Plasmoid.configuration.interval
    }

    Sensors.Sensor {
        id: totalDownSensor
        sensorId: "network/all/totalDownload"
        enabled: root.expanded
    }

    Sensors.Sensor {
        id: totalUpSensor
        sensorId: "network/all/totalUpload"
        enabled: root.expanded
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.downHistory = root.pushHistory(root.downHistory, root.downRate);
            root.upHistory = root.pushHistory(root.upHistory, root.upRate);
        }
    }

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property int fontSize: Math.max(Kirigami.Theme.smallFont.pixelSize,
            Math.round(vertical ? width * 0.18 : height * 0.36))

        Layout.minimumWidth: vertical ? -1 : layout.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: vertical ? layout.implicitHeight + Kirigami.Units.smallSpacing * 2 : -1

        onClicked: root.expanded = !root.expanded

        // Sütun genişlikleri en geniş olası metne göre sabitlenir, panel titremez
        TextMetrics {
            id: numberMetrics
            font.pixelSize: compact.fontSize
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            text: "999"
        }

        TextMetrics {
            id: unitMetrics
            font.pixelSize: Math.round(compact.fontSize * 0.8)
            text: root.useBits ? "Mbit/sn" : "MB/sn"
        }

        GridLayout {
            id: layout
            anchors.centerIn: parent
            columns: 3
            rowSpacing: 0
            columnSpacing: Math.round(Kirigami.Units.smallSpacing / 2)

            // İndirme satırı
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                text: "↓"
                color: root.downColor
                opacity: root.downRate < root.idleRate ? 0.45 : 1
                font.pixelSize: compact.fontSize
                font.bold: true
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                Layout.preferredWidth: Math.ceil(numberMetrics.advanceWidth)
                horizontalAlignment: Text.AlignRight
                text: root.down.number
                opacity: root.downRate < root.idleRate ? 0.6 : 1
                font: numberMetrics.font
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                Layout.preferredWidth: Math.ceil(unitMetrics.advanceWidth)
                text: root.down.unit
                opacity: 0.7
                font: unitMetrics.font
            }

            // Yükleme satırı
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                text: "↑"
                color: root.upColor
                opacity: root.upRate < root.idleRate ? 0.45 : 1
                font.pixelSize: compact.fontSize
                font.bold: true
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                Layout.preferredWidth: Math.ceil(numberMetrics.advanceWidth)
                horizontalAlignment: Text.AlignRight
                text: root.up.number
                opacity: root.upRate < root.idleRate ? 0.6 : 1
                font: numberMetrics.font
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                Layout.preferredWidth: Math.ceil(unitMetrics.advanceWidth)
                text: root.up.unit
                opacity: 0.7
                font: unitMetrics.font
            }
        }
    }

    // Açılır penceredeki hız kartı: büyük değer, en yüksek hız ve 60 sn grafiği
    component RateCard: Card {
        id: rateCard

        property string title
        property string glyph
        property color seriesColor
        property real rate
        property var history: []
        property var formatRate
        property var rateText

        readonly property real peak: history.length ? Math.max(...history) : 0
        property real displayRate: rate
        readonly property var display: formatRate(displayRate)

        Behavior on displayRate { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                radius: width / 2
                color: Qt.rgba(rateCard.seriesColor.r, rateCard.seriesColor.g, rateCard.seriesColor.b, 0.18)

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    text: rateCard.glyph
                    color: rateCard.seriesColor
                    font.bold: true
                }
            }
            Kirigami.Heading {
                level: 4
                text: rateCard.title
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.Label {
                text: i18n("en yüksek %1", rateCard.rateText(rateCard.peak))
                font: Kirigami.Theme.smallFont
                opacity: 0.6
            }
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                text: rateCard.display.number
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 2.4)
                font.weight: Font.DemiBold
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignBaseline
                text: rateCard.display.unit
                opacity: 0.7
            }
        }

        Sparkline {
            Layout.fillWidth: true
            values: rateCard.history
            capacity: 60
            color: rateCard.seriesColor
            formatValue: rateCard.rateText
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: popup

        // Panel dışında (ör. plasmawindowed) expanded hep false kalabilir
        readonly property bool open: root.expanded || Plasmoid.formFactor === PlasmaCore.Types.Planar
        readonly property real totalDown: Number(totalDownSensor.value) || 0
        readonly property real totalUp: Number(totalUpSensor.value) || 0
        readonly property real downShare: totalDown + totalUp > 0 ? totalDown / (totalDown + totalUp) : 0.5

        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: cards.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.preferredHeight: cards.implicitHeight + Kirigami.Units.largeSpacing * 2

        contentItem: Item {
            ColumnLayout {
                id: cards
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                RateCard {
                    Layout.fillWidth: true
                    shown: popup.open
                    delay: 0
                    title: i18n("İndirme")
                    glyph: "↓"
                    seriesColor: root.downColor
                    rate: root.downRate
                    history: root.downHistory
                    formatRate: root.formatRate
                    rateText: root.rateText
                }

                RateCard {
                    Layout.fillWidth: true
                    shown: popup.open
                    delay: 90
                    title: i18n("Yükleme")
                    glyph: "↑"
                    seriesColor: root.upColor
                    rate: root.upRate
                    history: root.upHistory
                    formatRate: root.formatRate
                    rateText: root.rateText
                }

                // Açılıştan beri toplamlar ve indirme/yükleme oranı
                Card {
                    Layout.fillWidth: true
                    shown: popup.open
                    delay: 180

                    PlasmaComponents3.Label {
                        text: i18n("Açılıştan beri toplam")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: root.downColor
                        }
                        PlasmaComponents3.Label {
                            text: i18n("İndirilen")
                            opacity: 0.7
                        }
                        PlasmaComponents3.Label {
                            text: root.formatSize(popup.totalDown)
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: root.upColor
                        }
                        PlasmaComponents3.Label {
                            text: i18n("Yüklenen")
                            opacity: 0.7
                        }
                        PlasmaComponents3.Label {
                            text: root.formatSize(popup.totalUp)
                        }
                    }

                    // İki parçalı oran çubuğu; parçalar arasında 2 px boşluk
                    Item {
                        id: ratio
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6

                        readonly property real gap: 2
                        readonly property real usable: width - gap

                        Rectangle {
                            height: parent.height
                            radius: height / 2
                            width: Math.max(height, ratio.usable * popup.downShare)
                            color: root.downColor

                            Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            height: parent.height
                            radius: height / 2
                            width: Math.max(height, ratio.usable * (1 - popup.downShare))
                            color: root.upColor

                            Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}

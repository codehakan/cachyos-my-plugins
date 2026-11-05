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

    readonly property color downColor: Kirigami.Theme.highlightColor
    readonly property color upColor: Kirigami.Theme.neutralTextColor

    // Bu hızın altı "boşta" sayılır ve soluk gösterilir
    readonly property real idleRate: 1024

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

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 9

        contentItem: Item {
            GridLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("İndirme")
                    opacity: 0.7
                }
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 2
                    text: "↓ " + root.down.number + " " + root.down.unit
                    color: root.downColor
                }

                PlasmaComponents3.Label {
                    text: i18n("Yükleme")
                    opacity: 0.7
                }
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 2
                    text: "↑ " + root.up.number + " " + root.up.unit
                    color: root.upColor
                }

                Kirigami.Separator {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                PlasmaComponents3.Label {
                    Layout.columnSpan: 2
                    text: i18n("Açılıştan beri toplam")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }

                PlasmaComponents3.Label {
                    text: i18n("İndirilen")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: root.formatSize(totalDownSensor.value)
                }

                PlasmaComponents3.Label {
                    text: i18n("Yüklenen")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: root.formatSize(totalUpSensor.value)
                }

                Item {
                    Layout.columnSpan: 2
                    Layout.fillHeight: true
                }
            }
        }
    }
}

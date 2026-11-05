import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string liquidCommand: "liquidctl status --json"

    readonly property real cpuTemp: Number(cpuTempSensor.value) || 0
    readonly property real gpuTemp: Number(gpuTempSensor.value) || 0
    readonly property string gpuName: {
        // "AD104 [GeForce RTX 4070 Ti] Sıcaklık" → "GeForce RTX 4070 Ti"
        const match = /\[(.+)\]/.exec(gpuTempSensor.name || "");
        return match ? match[1] : i18n("Ekran kartı");
    }

    // liquidctl'den okunanlar; cihaz yoksa liquidAvailable false kalır
    property bool liquidAvailable: false
    property string liquidName: ""
    property real liquidTemp: 0
    property int pumpRpm: 0
    property var fanRpms: []

    readonly property bool showCpu: Plasmoid.configuration.showCpu
    readonly property bool showGpu: Plasmoid.configuration.showGpu
    readonly property bool showLiquid: Plasmoid.configuration.showLiquid && liquidAvailable

    // [uyarı, kritik] eşikleri, °C
    readonly property var cpuLimits: [85, 95]
    readonly property var gpuLimits: [80, 87]
    readonly property var liquidLimits: [45, 50]

    Plasmoid.icon: "temperature-normal"
    toolTipMainText: i18n("Sistem Durumu")
    toolTipSubText: {
        const parts = [i18n("CPU %1", formatTemp(cpuTemp, 0)), i18n("GPU %1", formatTemp(gpuTemp, 0))];
        if (liquidAvailable) {
            parts.push(i18n("Su %1", formatTemp(liquidTemp, 1)));
        }
        return parts.join("  ·  ");
    }

    function formatTemp(value, decimals) {
        return Number(value).toLocaleString(Qt.locale(), "f", decimals) + " °C";
    }

    function formatRpm(value) {
        return Number(value).toLocaleString(Qt.locale(), "f", 0) + " rpm";
    }

    function formatBytes(bytes) {
        return (Number(bytes) / 1024 / 1024 / 1024).toLocaleString(Qt.locale(), "f", 1) + " GB";
    }

    function tempColor(value, limits) {
        if (value >= limits[1]) {
            return Kirigami.Theme.negativeTextColor;
        }
        if (value >= limits[0]) {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.textColor;
    }

    function parseLiquid(stdout) {
        let devices;
        try {
            devices = JSON.parse(stdout);
        } catch (e) {
            liquidAvailable = false;
            return;
        }
        // Sıcaklık bildiren ilk cihaz (Corsair: "Water temperature", NZXT: "Liquid temperature")
        const device = (devices || []).find(d => (d.status || []).some(s => /temperature/i.test(s.key)));
        if (!device) {
            liquidAvailable = false;
            return;
        }
        const status = device.status;
        liquidName = device.description.replace(/\s*\(.*\)$/, "");
        liquidTemp = status.find(s => /temperature/i.test(s.key)).value;
        const pump = status.find(s => /pump speed/i.test(s.key));
        pumpRpm = pump ? pump.value : 0;
        fanRpms = status.filter(s => /fan speed/i.test(s.key) && s.value > 0).map(s => s.value);
        liquidAvailable = true;
    }

    Sensors.Sensor {
        id: cpuTempSensor
        sensorId: "cpu/all/maximumTemperature"
    }

    Sensors.Sensor {
        id: gpuTempSensor
        sensorId: "gpu/gpu0/temperature"
    }

    // Aşağıdakiler yalnızca açılır pencerede gösterilir
    Sensors.Sensor {
        id: cpuUsageSensor
        sensorId: "cpu/all/usage"
        enabled: root.expanded
    }

    Sensors.Sensor {
        id: gpuUsageSensor
        sensorId: "gpu/gpu0/usage"
        enabled: root.expanded
    }

    Sensors.Sensor {
        id: gpuPowerSensor
        sensorId: "gpu/gpu0/power"
        enabled: root.expanded
    }

    Sensors.Sensor {
        id: gpuUsedVramSensor
        sensorId: "gpu/gpu0/usedVram"
        enabled: root.expanded
    }

    Sensors.Sensor {
        id: gpuTotalVramSensor
        sensorId: "gpu/gpu0/totalVram"
        enabled: root.expanded
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (Plasmoid.configuration.showLiquid) {
                root.parseLiquid(data["stdout"]);
            }
        }
    }

    // Commander cihazları her okumada ışıklarını yeniden başlatır, bu yüzden
    // okuma yalnızca kullanıcı açıkça izin verdiğinde yapılır
    Timer {
        interval: Math.max(2, Plasmoid.configuration.liquidInterval) * 1000
        running: Plasmoid.configuration.showLiquid
        onRunningChanged: {
            if (!running) {
                root.liquidAvailable = false;
            }
        }
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.connectSource(root.liquidCommand)
    }

    // Panelde tek blok: üstte küçük başlık, altta büyük sıcaklık
    component TempBlock: ColumnLayout {
        property string caption
        property string value
        property color valueColor
        property int valueSize
        property real valueWidth

        spacing: 0

        PlasmaComponents3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: parent.caption
            font.pixelSize: Math.round(parent.valueSize * 0.55)
            opacity: 0.7
        }
        PlasmaComponents3.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.valueWidth
            horizontalAlignment: Text.AlignHCenter
            text: parent.value
            color: parent.valueColor
            font.pixelSize: parent.valueSize
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property int valueSize: Math.max(Kirigami.Theme.defaultFont.pixelSize,
            Math.round(vertical ? width * 0.3 : height * 0.5))

        Layout.minimumWidth: vertical ? -1 : layout.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: vertical ? layout.implicitHeight + Kirigami.Units.smallSpacing * 2 : -1

        onClicked: root.expanded = !root.expanded

        // Sıcaklık değişince blok genişliği oynamasın
        TextMetrics {
            id: valueMetrics
            font.pixelSize: compact.valueSize
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            text: "88°"
        }

        GridLayout {
            id: layout
            anchors.centerIn: parent
            flow: compact.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            TempBlock {
                visible: root.showCpu
                caption: "CPU"
                value: Math.round(root.cpuTemp) + "°"
                valueColor: root.tempColor(root.cpuTemp, root.cpuLimits)
                valueSize: compact.valueSize
                valueWidth: Math.ceil(valueMetrics.advanceWidth)
            }
            TempBlock {
                visible: root.showGpu
                caption: "GPU"
                value: Math.round(root.gpuTemp) + "°"
                valueColor: root.tempColor(root.gpuTemp, root.gpuLimits)
                valueSize: compact.valueSize
                valueWidth: Math.ceil(valueMetrics.advanceWidth)
            }
            TempBlock {
                visible: root.showLiquid
                caption: i18n("SU")
                value: Math.round(root.liquidTemp) + "°"
                valueColor: root.tempColor(root.liquidTemp, root.liquidLimits)
                valueSize: compact.valueSize
                valueWidth: Math.ceil(valueMetrics.advanceWidth)
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

        contentItem: Item {
            GridLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.largeSpacing
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                // İşlemci
                Kirigami.Heading {
                    Layout.columnSpan: 2
                    level: 4
                    text: i18n("İşlemci")
                }
                PlasmaComponents3.Label {
                    text: i18n("Sıcaklık")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: root.formatTemp(root.cpuTemp, 1)
                    color: root.tempColor(root.cpuTemp, root.cpuLimits)
                }
                PlasmaComponents3.Label {
                    text: i18n("Kullanım")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: "%" + Math.round(Number(cpuUsageSensor.value) || 0)
                }

                // Ekran kartı
                Kirigami.Heading {
                    Layout.columnSpan: 2
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    level: 4
                    text: root.gpuName
                }
                PlasmaComponents3.Label {
                    text: i18n("Sıcaklık")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: root.formatTemp(root.gpuTemp, 0)
                    color: root.tempColor(root.gpuTemp, root.gpuLimits)
                }
                PlasmaComponents3.Label {
                    text: i18n("Kullanım")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: "%" + Math.round(Number(gpuUsageSensor.value) || 0)
                }
                PlasmaComponents3.Label {
                    text: i18n("Güç")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: Math.round(Number(gpuPowerSensor.value) || 0) + " W"
                }
                PlasmaComponents3.Label {
                    text: i18n("Video belleği")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    text: Number(gpuTotalVramSensor.value) > 0
                          ? root.formatBytes(gpuUsedVramSensor.value) + " / " + root.formatBytes(gpuTotalVramSensor.value)
                          : root.formatBytes(gpuUsedVramSensor.value)
                }

                // Sıvı soğutma
                Kirigami.Heading {
                    Layout.columnSpan: 2
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: root.liquidAvailable
                    level: 4
                    text: root.liquidName || i18n("Sıvı soğutma")
                }
                PlasmaComponents3.Label {
                    visible: root.liquidAvailable
                    text: i18n("Su sıcaklığı")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    visible: root.liquidAvailable
                    text: root.formatTemp(root.liquidTemp, 1)
                    color: root.tempColor(root.liquidTemp, root.liquidLimits)
                }
                PlasmaComponents3.Label {
                    visible: root.liquidAvailable && root.pumpRpm > 0
                    text: i18n("Pompa")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    visible: root.liquidAvailable && root.pumpRpm > 0
                    text: root.formatRpm(root.pumpRpm)
                }
                PlasmaComponents3.Label {
                    visible: root.liquidAvailable && root.fanRpms.length > 0
                    text: i18n("Fanlar")
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    visible: root.liquidAvailable && root.fanRpms.length > 0
                    text: root.fanRpms.map(rpm => Number(rpm).toLocaleString(Qt.locale(), "f", 0)).join(" · ") + " rpm"
                }
            }
        }
    }
}

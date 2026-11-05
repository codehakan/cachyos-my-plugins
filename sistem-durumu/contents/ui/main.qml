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
    readonly property string cpuNameCommand: "grep -m1 'model name' /proc/cpuinfo"

    readonly property real cpuTemp: Number(cpuTempSensor.value) || 0
    readonly property real gpuTemp: Number(gpuTempSensor.value) || 0
    readonly property string gpuName: {
        // "AD104 [GeForce RTX 4070 Ti] Sıcaklık" → "GeForce RTX 4070 Ti"
        const match = /\[(.+)\]/.exec(gpuTempSensor.name || "");
        return match ? match[1] : i18n("Ekran kartı");
    }
    property string cpuName: ""

    // Açılır penceredeki grafikler için son 60 saniye
    readonly property int historySize: 60
    property var cpuHistory: []
    property var gpuHistory: []

    // liquidctl'den okunanlar; cihaz yoksa liquidAvailable false kalır
    property bool liquidAvailable: false
    property string liquidName: ""
    property real liquidTemp: 0
    property int pumpRpm: 0
    property var fanRpms: []

    readonly property bool showCpu: Plasmoid.configuration.showCpu
    readonly property bool showGpu: Plasmoid.configuration.showGpu
    readonly property bool showLiquid: Plasmoid.configuration.showLiquid && liquidAvailable

    // [uyarı, kritik] eşikleri ve göstergenin başladığı değer, °C
    readonly property var cpuLimits: [85, 95]
    readonly property var gpuLimits: [80, 87]
    readonly property var liquidLimits: [45, 50]
    readonly property real gaugeFloor: 25

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

    // Paneldeki rakam: normalde yazı rengi, eşiklerde turuncu/kırmızı
    function tempColor(value, limits) {
        if (value >= limits[1]) {
            return Kirigami.Theme.negativeTextColor;
        }
        if (value >= limits[0]) {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.textColor;
    }

    // Gösterge dolgusu: normalde vurgu rengi, eşiklerde turuncu/kırmızı
    function gaugeColor(value, limits) {
        return value >= limits[0] ? tempColor(value, limits) : Kirigami.Theme.highlightColor;
    }

    function heatFraction(value, limits) {
        return Math.max(0, Math.min(1, (value - gaugeFloor) / (limits[1] - gaugeFloor)));
    }

    function pushHistory(list, value) {
        const next = list.concat([value]);
        return next.length > historySize ? next.slice(next.length - historySize) : next;
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
            if (sourceName === root.cpuNameCommand) {
                // "model name : AMD Ryzen 9 9950X3D 16-Core Processor" → "AMD Ryzen 9 9950X3D"
                root.cpuName = (data["stdout"] || "").replace(/^[^:]*:\s*/, "")
                    .replace(/\s+\d+-Core Processor\s*$/, "").trim();
            } else if (Plasmoid.configuration.showLiquid) {
                root.parseLiquid(data["stdout"]);
            }
        }
    }

    Component.onCompleted: executable.connectSource(cpuNameCommand)

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (cpuTempSensor.value !== undefined) {
                root.cpuHistory = root.pushHistory(root.cpuHistory, root.cpuTemp);
            }
            if (gpuTempSensor.value !== undefined) {
                root.gpuHistory = root.pushHistory(root.gpuHistory, root.gpuTemp);
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

    // Panelde tek blok: küçük başlık, büyük sıcaklık, altında ısıyla dolan ince çubuk
    component TempBlock: ColumnLayout {
        id: block

        property string caption
        property real temperature
        property var limits
        property color valueColor
        property color barColor
        property real fraction
        property int valueSize
        property real valueWidth

        readonly property bool critical: temperature >= limits[1]

        spacing: 0

        PlasmaComponents3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: block.caption
            font.pixelSize: Math.round(block.valueSize * 0.5)
            opacity: 0.7
        }
        PlasmaComponents3.Label {
            id: valueLabel
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: block.valueWidth
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(block.temperature) + "°"
            color: block.valueColor
            font.pixelSize: block.valueSize
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }

            Behavior on color { ColorAnimation { duration: 500 } }

            // Kritik sıcaklıkta nabız gibi atar
            SequentialAnimation on opacity {
                running: block.critical
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.35; duration: 450; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
            }
        }
        MeterBar {
            Layout.preferredWidth: block.valueWidth
            Layout.preferredHeight: 2
            fraction: block.fraction
            fillColor: block.barColor
        }
    }

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property int valueSize: Math.max(Kirigami.Theme.defaultFont.pixelSize,
            Math.round(vertical ? width * 0.3 : height * 0.46))

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
                temperature: root.cpuTemp
                limits: root.cpuLimits
                valueColor: root.tempColor(root.cpuTemp, root.cpuLimits)
                barColor: root.gaugeColor(root.cpuTemp, root.cpuLimits)
                fraction: root.heatFraction(root.cpuTemp, root.cpuLimits)
                valueSize: compact.valueSize
                valueWidth: Math.ceil(valueMetrics.advanceWidth)
            }
            TempBlock {
                visible: root.showGpu
                caption: "GPU"
                temperature: root.gpuTemp
                limits: root.gpuLimits
                valueColor: root.tempColor(root.gpuTemp, root.gpuLimits)
                barColor: root.gaugeColor(root.gpuTemp, root.gpuLimits)
                fraction: root.heatFraction(root.gpuTemp, root.gpuLimits)
                valueSize: compact.valueSize
                valueWidth: Math.ceil(valueMetrics.advanceWidth)
            }
            TempBlock {
                visible: root.showLiquid
                caption: i18n("SU")
                temperature: root.liquidTemp
                limits: root.liquidLimits
                valueColor: root.tempColor(root.liquidTemp, root.liquidLimits)
                barColor: root.gaugeColor(root.liquidTemp, root.liquidLimits)
                fraction: root.heatFraction(root.liquidTemp, root.liquidLimits)
                valueSize: compact.valueSize
                valueWidth: Math.ceil(valueMetrics.advanceWidth)
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: popup

        // Panel dışında (ör. plasmawindowed) expanded hep false kalabilir
        readonly property bool open: root.expanded || Plasmoid.formFactor === PlasmaCore.Types.Planar

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

                // İşlemci
                Card {
                    Layout.fillWidth: true
                    shown: popup.open
                    delay: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        RingGauge {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                            value: root.cpuTemp
                            from: root.gaugeFloor
                            to: root.cpuLimits[1]
                            color: root.gaugeColor(root.cpuTemp, root.cpuLimits)
                            pulsing: root.cpuTemp >= root.cpuLimits[1]
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    source: Qt.resolvedUrl("../images/chip.svg")
                                    isMask: true
                                    color: root.gaugeColor(root.cpuTemp, root.cpuLimits)
                                }
                                Kirigami.Heading {
                                    level: 4
                                    text: i18n("İşlemci")
                                }
                            }
                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                visible: root.cpuName !== ""
                                text: root.cpuName
                                elide: Text.ElideRight
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Kirigami.Units.smallSpacing
                                PlasmaComponents3.Label {
                                    text: i18n("Kullanım")
                                    opacity: 0.7
                                }
                                Item { Layout.fillWidth: true }
                                PlasmaComponents3.Label {
                                    text: "%" + Math.round(Number(cpuUsageSensor.value) || 0)
                                }
                            }
                            MeterBar {
                                Layout.fillWidth: true
                                fraction: (Number(cpuUsageSensor.value) || 0) / 100
                            }
                        }
                    }

                    Sparkline {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        values: root.cpuHistory
                        capacity: root.historySize
                        decimals: 1
                        color: root.gaugeColor(root.cpuTemp, root.cpuLimits)
                    }
                    PlasmaComponents3.Label {
                        text: root.cpuHistory.length
                              ? i18n("Son %1 sn · en yüksek %2", root.cpuHistory.length,
                                     root.formatTemp(Math.max(...root.cpuHistory), 1))
                              : ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                }

                // Ekran kartı
                Card {
                    Layout.fillWidth: true
                    shown: popup.open
                    delay: 90

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        RingGauge {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                            value: root.gpuTemp
                            from: root.gaugeFloor
                            to: root.gpuLimits[1]
                            color: root.gaugeColor(root.gpuTemp, root.gpuLimits)
                            pulsing: root.gpuTemp >= root.gpuLimits[1]
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    source: Qt.resolvedUrl("../images/gpu.svg")
                                    isMask: true
                                    color: root.gaugeColor(root.gpuTemp, root.gpuLimits)
                                }
                                Kirigami.Heading {
                                    Layout.fillWidth: true
                                    level: 4
                                    text: root.gpuName
                                    elide: Text.ElideRight
                                }
                            }
                            PlasmaComponents3.Label {
                                text: i18n("%1 W", Math.round(Number(gpuPowerSensor.value) || 0))
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Kirigami.Units.smallSpacing
                                PlasmaComponents3.Label {
                                    text: i18n("Kullanım")
                                    opacity: 0.7
                                }
                                Item { Layout.fillWidth: true }
                                PlasmaComponents3.Label {
                                    text: "%" + Math.round(Number(gpuUsageSensor.value) || 0)
                                }
                            }
                            MeterBar {
                                Layout.fillWidth: true
                                fraction: (Number(gpuUsageSensor.value) || 0) / 100
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                PlasmaComponents3.Label {
                                    text: i18n("Video belleği")
                                    opacity: 0.7
                                }
                                Item { Layout.fillWidth: true }
                                PlasmaComponents3.Label {
                                    text: Number(gpuTotalVramSensor.value) > 0
                                          ? root.formatBytes(gpuUsedVramSensor.value) + " / " + root.formatBytes(gpuTotalVramSensor.value)
                                          : root.formatBytes(gpuUsedVramSensor.value)
                                }
                            }
                            MeterBar {
                                Layout.fillWidth: true
                                visible: Number(gpuTotalVramSensor.value) > 0
                                fraction: Number(gpuUsedVramSensor.value) / Math.max(1, Number(gpuTotalVramSensor.value))
                            }
                        }
                    }

                    Sparkline {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        values: root.gpuHistory
                        capacity: root.historySize
                        color: root.gaugeColor(root.gpuTemp, root.gpuLimits)
                    }
                    PlasmaComponents3.Label {
                        text: root.gpuHistory.length
                              ? i18n("Son %1 sn · en yüksek %2", root.gpuHistory.length,
                                     root.formatTemp(Math.max(...root.gpuHistory), 0))
                              : ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                }

                // Sıvı soğutma
                Card {
                    Layout.fillWidth: true
                    visible: root.liquidAvailable
                    shown: popup.open && root.liquidAvailable
                    delay: 180

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        RingGauge {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                            value: root.liquidTemp
                            from: root.gaugeFloor
                            to: root.liquidLimits[1]
                            decimals: 1
                            color: root.gaugeColor(root.liquidTemp, root.liquidLimits)
                            pulsing: root.liquidTemp >= root.liquidLimits[1]
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Heading {
                                Layout.fillWidth: true
                                level: 4
                                text: root.liquidName || i18n("Sıvı soğutma")
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                visible: root.pumpRpm > 0
                                spacing: Kirigami.Units.smallSpacing
                                SpinningFan {
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                                    rpm: root.pumpRpm
                                    color: Kirigami.Theme.highlightColor
                                }
                                PlasmaComponents3.Label {
                                    text: i18n("Pompa")
                                    opacity: 0.7
                                }
                                PlasmaComponents3.Label {
                                    text: root.formatRpm(root.pumpRpm)
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.largeSpacing

                                Repeater {
                                    model: root.fanRpms.length

                                    delegate: Row {
                                        required property int index
                                        spacing: Kirigami.Units.smallSpacing

                                        SpinningFan {
                                            width: Kirigami.Units.iconSizes.small
                                            height: Kirigami.Units.iconSizes.small
                                            anchors.verticalCenter: parent.verticalCenter
                                            rpm: root.fanRpms[index] || 0
                                            color: Kirigami.Theme.textColor
                                        }
                                        PlasmaComponents3.Label {
                                            text: Number(root.fanRpms[index] || 0).toLocaleString(Qt.locale(), "f", 0)
                                            font: Kirigami.Theme.smallFont
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

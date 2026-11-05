import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string readCommand: "headsetcontrol -b -o json"

    // unknown | notInstalled | noReceiver | offline | available | charging | error
    property string batteryState: "unknown"
    property int level: -1
    property string deviceName: ""
    property string errorText: ""
    property var lastUpdate: null
    property bool lowNotified: false

    readonly property bool online: batteryState === "available" || batteryState === "charging"
    readonly property bool charging: batteryState === "charging"
    readonly property bool low: batteryState === "available" && level <= Plasmoid.configuration.lowThreshold
    // Hata durumları gizlenmez ki sorun fark edilsin
    readonly property bool hiddenWhenOff: Plasmoid.configuration.hideWhenOff
                                          && ["unknown", "noReceiver", "offline"].includes(batteryState)

    readonly property string percentText: online ? "%" + level : "—"
    readonly property string batteryIcon: {
        if (!online) {
            return "battery-missing-symbolic";
        }
        const step = String(Math.round(level / 10) * 10).padStart(3, "0");
        return "battery-" + step + (charging ? "-charging" : "") + "-symbolic";
    }
    readonly property string statusText: {
        switch (batteryState) {
        case "unknown": return i18n("Okunuyor…");
        case "notInstalled": return i18n("headsetcontrol kurulu değil");
        case "noReceiver": return i18n("Alıcı takılı değil");
        case "offline": return i18n("Kulaklık kapalı");
        case "charging": return i18n("Şarj oluyor");
        case "available": return low ? i18n("Pil azaldı") : i18n("Şarj olmuyor");
        default: return i18n("Okunamadı");
        }
    }

    Plasmoid.icon: batteryIcon
    Plasmoid.status: {
        if (hiddenWhenOff) {
            return PlasmaCore.Types.HiddenStatus;
        }
        if (low) {
            return PlasmaCore.Types.NeedsAttentionStatus;
        }
        return online ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus;
    }

    toolTipMainText: deviceName || i18n("Kulaklık Pili")
    toolTipSubText: online ? percentText + " · " + statusText : statusText

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Şimdi yenile")
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        }
    ]

    function refresh() {
        executable.connectSource(readCommand);
    }

    function parseOutput(exitCode, stdout, stderr) {
        lastUpdate = new Date();
        let json;
        try {
            json = JSON.parse(stdout);
        } catch (e) {
            // 127: kabuk komutu bulamadı
            batteryState = exitCode === 127 ? "notInstalled" : "error";
            errorText = (stderr || stdout || "").trim();
            level = -1;
            return;
        }

        const devices = json.devices || [];
        const dev = devices.find(d => (d.capabilities_str || []).includes("battery")) || devices[0];
        if (!dev) {
            batteryState = "noReceiver";
            level = -1;
            return;
        }

        deviceName = dev.product || dev.device || "";
        const bat = dev.battery;
        if (!bat || bat.status === "BATTERY_UNAVAILABLE" || bat.level < 0) {
            batteryState = "offline";
            level = -1;
        } else {
            level = bat.level;
            batteryState = bat.status === "BATTERY_CHARGING" ? "charging" : "available";
        }
        errorText = "";
        checkLowBattery();
    }

    function checkLowBattery() {
        if (low && !lowNotified) {
            const name = (deviceName || i18n("Kulaklık")).replace(/'/g, "");
            executable.connectSource("notify-send -a 'Kulaklık Pili' -i battery-010 '"
                + i18n("Kulaklık pili azaldı") + "' '"
                + i18n("%1 pili %2. Şarja takmayı unutma.", name, "%" + level) + "'");
        }
        lowNotified = low;
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (sourceName === root.readCommand) {
                root.parseOutput(data["exit code"], data["stdout"], data["stderr"]);
            }
        }
    }

    Timer {
        interval: Math.max(10, Plasmoid.configuration.interval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onExpandedChanged: isExpanded => {
        if (isExpanded) {
            refresh();
        }
    }

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property int digitSize: Math.max(Kirigami.Theme.defaultFont.pixelSize,
            Math.round(vertical ? width * 0.45 : height * 0.62))
        readonly property color textColor: root.low ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor

        Layout.minimumWidth: vertical ? -1 : layout.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: vertical ? layout.implicitHeight + Kirigami.Units.smallSpacing * 2 : -1

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.refresh();
            } else {
                root.expanded = !root.expanded;
            }
        }

        GridLayout {
            id: layout
            anchors.centerIn: parent
            flow: compact.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 0
            columnSpacing: Kirigami.Units.smallSpacing
            opacity: root.online ? 1 : 0.5

            // Şarj şimşeği, genişlik eklememek için simgenin köşesinde rozet
            Item {
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

                Kirigami.Icon {
                    anchors.fill: parent
                    source: "audio-headset-symbolic"
                    active: compact.containsMouse
                }

                Kirigami.Icon {
                    visible: root.charging
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: Math.round(parent.width * 0.5)
                    height: width
                    source: Qt.resolvedUrl("../images/bolt.svg")
                    isMask: true
                    color: Kirigami.Theme.positiveTextColor
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignCenter
                spacing: 0

                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignBaseline
                    visible: root.online
                    text: "%"
                    color: compact.textColor
                    font.pixelSize: Math.round(compact.digitSize * 0.55)
                    opacity: 0.8
                }

                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignBaseline
                    text: root.online ? root.level : "—"
                    color: compact.textColor
                    font.pixelSize: compact.digitSize
                    font.weight: root.low ? Font.Bold : Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 7
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

        contentItem: Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                        source: root.batteryIcon
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: root.deviceName || i18n("Kulaklık")
                            elide: Text.ElideRight
                            opacity: 0.8
                        }
                        Kirigami.Heading {
                            level: 1
                            text: root.percentText
                            color: root.low ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        }
                        PlasmaComponents3.Label {
                            text: root.statusText
                            opacity: 0.7
                        }
                    }

                    PlasmaComponents3.ToolButton {
                        Layout.alignment: Qt.AlignTop
                        icon.name: "view-refresh"
                        onClicked: root.refresh()
                        PlasmaComponents3.ToolTip.text: i18n("Şimdi yenile")
                        PlasmaComponents3.ToolTip.visible: hovered
                    }
                }

                PlasmaComponents3.ProgressBar {
                    Layout.fillWidth: true
                    visible: root.online
                    from: 0
                    to: 100
                    value: Math.max(0, root.level)
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    visible: root.errorText !== ""
                    text: root.errorText
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }

                Item { Layout.fillHeight: true }

                PlasmaComponents3.Label {
                    text: root.lastUpdate
                          ? i18n("Son güncelleme: %1", Qt.formatTime(root.lastUpdate, "HH:mm:ss"))
                          : ""
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
            }
        }
    }
}

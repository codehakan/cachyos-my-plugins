import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Açılır penceredeki kart; pencere açılınca gecikmeli olarak kayıp belirir
Rectangle {
    id: card

    property bool shown: false
    property int delay: 0
    default property alias content: inner.data

    readonly property color tint: Kirigami.Theme.textColor

    implicitHeight: inner.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.largeSpacing
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.05)
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.08)
    opacity: 0
    transform: Translate { id: shift; y: Kirigami.Units.gridUnit }

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
    }

    SequentialAnimation {
        id: enter
        PauseAnimation { duration: card.delay }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 350; easing.type: Easing.OutCubic }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function reset() {
        enter.stop();
        card.opacity = 0;
        shift.y = Kirigami.Units.gridUnit;
    }

    onShownChanged: shown ? enter.restart() : reset()
    Component.onCompleted: {
        if (shown) {
            enter.restart();
        }
    }
}

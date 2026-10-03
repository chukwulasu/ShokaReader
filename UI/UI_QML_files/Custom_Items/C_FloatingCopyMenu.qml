import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: copyMenu

    signal copyTriggered()

    implicitWidth: 80
    implicitHeight: 32
    color: "#FFFFFF"
    radius: 4
    border.color: "#D0D0D0"
    border.width: 1

    // Drop shadow styling
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 5
        color: "#18000000"
        z: -1
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "Copy"
            color: "#1A1A1A"
            font.pixelSize: 12
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            copyMenu.copyTriggered();
        }
    }
}
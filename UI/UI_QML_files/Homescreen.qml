import QtQuick
import QtQuick.Layouts

Rectangle {
    id: homeRoot
    color: "#16261B"

    Item {
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: "../assets/images/Homescreen.png"
            fillMode: Image.Stretch
        }
    }
}
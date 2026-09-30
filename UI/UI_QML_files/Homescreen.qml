import QtQuick
import QtQuick.Layouts

Item {
    id: homeScreen
    anchors.fill: parent

    Image {
        anchors.fill: parent
        source: "../assets/images/Homescreen.png"
        fillMode: Image.PreserveAspectCrop
        cache: true
    }
}
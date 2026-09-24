import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: toolbarButton
    property alias source: iconImage.source
    property alias shortcut: keyShortcut.sequence
    property string toolTipText: ""

    signal clicked()

    Layout.preferredWidth: 40
    Layout.preferredHeight: 40

    Image {
        id: iconImage
        anchors.centerIn: parent
        width: 24
        height: 24
        fillMode: Image.PreserveAspectFit
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: toolbarButton.clicked()
        ToolTip.visible: mouseArea.containsMouse && toolbarButton.toolTipText !== ""
        ToolTip.text: toolbarButton.toolTipText
        ToolTip.delay: 300
    }

    Shortcut {
            id: keyShortcut
            onActivated: toolbarButton.clicked()
        }

}

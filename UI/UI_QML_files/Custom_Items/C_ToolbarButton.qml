import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ToolbarButton.qml
Item {
    id: root
    property alias source: iconImage.source
    property alias shortcut: keyShortcut.sequence
    property string toolTipText: ""

    signal clicked()

    Layout.preferredWidth: 50
    Layout.preferredHeight: 50

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
        onClicked: root.clicked()
        ToolTip.visible: mouseArea.containsMouse && root.toolTipText !== ""
        ToolTip.text: root.toolTipText
        ToolTip.delay: 300
    }

    Shortcut {
            id: keyShortcut
            onActivated: root.clicked()
        }

}

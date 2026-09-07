import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: readerScreen
    objectName: "readerView"
    color: "#121212"

    property int currentPage: 0
    property int totalPages: documentManager.activeDocument ? documentManager.activeDocument.totalPageNumber : 0

    function goToNextPage() {
        if (listView.currentIndex < totalPages - 1) {
            listView.currentIndex++;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Beginning);
        }
    }

    function goToPreviousPage() {
        if (listView.currentIndex > 0) {
            listView.currentIndex--;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Beginning);
        }
    }

    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
            goToNextPage();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
            goToPreviousPage();
            event.accepted = true;
        }
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 24
        model: totalPages

        onContentYChanged: {
            let idx = listView.indexAt(contentX, contentY + 20);
            if (idx >= 0) {
                currentPage = idx;
            }
        }

        // Explicitly add a visible vertical scrollbar
        ScrollBar.vertical: ScrollBar {
            id: vbar
            active: true
            policy: ScrollBar.AlwaysOn
        }

        delegate: Item {
            width: listView.width
            // Account for card padding margins in total delegate height
            height: (documentManager.activeDocument ? documentManager.activeDocument.nativePageSize(index).height * scaleFactor : 1131) + 40

            property real scaleFactor: 1.2

            // White paper card container to fix transparent PDF blending and text overlap
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20

                width: documentManager.activeDocument ? documentManager.activeDocument.nativePageSize(index).width * scaleFactor : 800
                height: documentManager.activeDocument ? documentManager.activeDocument.nativePageSize(index).height * scaleFactor : 1131

                color: "#FFFFFF"
                border.color: "#333333"
                border.width: 1

                Image {
                    id: pageImage
                    anchors.fill: parent
                    anchors.margins: 1

                    source: "image://documentProvider/page_" + index

                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                }
            }
        }
    }
}
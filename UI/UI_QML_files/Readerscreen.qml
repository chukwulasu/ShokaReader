import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: readerScreen
    objectName: "readerView"
    color: "#121212"

    property int currentPage: 0
    property int totalPages: documentManager.activeDocument ? documentManager.activeDocument.totalPageNumber : 0
    property real currentZoom: 1.2

    function zoomIn() {
        if (currentZoom < 3.0) currentZoom += 0.2;
    }

    function zoomOut() {
        if (currentZoom > 0.6) currentZoom -= 0.2;
    }

    function goToNextPage() {
        if (listView.currentIndex < totalPages - 1) {
            listView.currentIndex++;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Center);
        }
    }

    function goToPreviousPage() {
        if (listView.currentIndex > 0) {
            listView.currentIndex--;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Center);
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
        spacing: 0
        model: documentManager.activeDocument ? documentManager.activeDocument.pageModel : null

        onContentYChanged: {
            let idx = listView.indexAt(contentX, contentY + 20);
            if (idx >= 0) {
                currentPage = idx;
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: vbar
            active: true
            policy: ScrollBar.AlwaysOn
        }

        delegate: Item {
                    id: pageDelegate
                    width: listView.width
                    property real uniformWidth: listView.width * 0.65
                    property real uniformHeight: uniformWidth * 1.414
                    property real scaledWidth: uniformWidth * currentZoom
                    property real scaledHeight: uniformHeight * currentZoom

                    height: scaledHeight

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: scaledWidth
                        height: scaledHeight
                        color: "#FFFFFF"
                        border.color: "#333333"
                        border.width: 1

                        Image {
                            id: pageImage
                            anchors.fill: parent
                            anchors.margins: 1
                            cache: false
                            source: "image://documentProvider/page_" + index
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                }
    }
}
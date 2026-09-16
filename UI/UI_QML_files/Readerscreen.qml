import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: readerScreen
    objectName: "readerView"
    color: "#121212"

    property int currentPage: 1
    property int totalPages: documentManager.activeDocument ? documentManager.activeDocument.totalPageNumber : 0
    property real currentZoom: 1
    property real pageRotation: 0

    focus: true
    activeFocusOnTab: true

    Component.onCompleted: {
        forceActiveFocus();
    }

    function zoomIn() {
        if (currentZoom < 3.0) currentZoom += 0.2;
    }

    function zoomOut() {
        if (currentZoom > 0.6) currentZoom -= 0.2;
    }

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

    function jumpToPage(pageNum) {
        let index = pageNum - 1;
        if (index >= 0 && index < totalPages) {
            listView.currentIndex = index;
            listView.positionViewAtIndex(index,ListView.Beginning);
            currentPage = pageNum;
        }
    }

    function rotateRight(){
        if(pageRotation === 270){
                pageRotation = 0;
        }
        else{
            pageRotation += 90;
        }
    }

    function rotateLeft(){
        if(pageRotation === 0){
            pageRotation = 270;
        }
        else{
            pageRotation -= 90;
        }
    }

    Keys.onPressed: (event) => {
        let scrollStep = 60;
        if(event.key === Qt.Key_Up){
            listView.contentY = Math.max(listView.contentY - scrollStep, 0);
            event.accepted = true;
        }
        else if(event.key === Qt.Key_Down){
            listView.contentY = Math.min(listView.contentY + scrollStep, listView.contentHeight - listView.height);
            event.accepted = true;
        }
        else if (event.key === Qt.Key_PageUp) {
            goToPreviousPage();
            event.accepted = true;
        }
        else if (event.key === Qt.Key_PageDown) {
            goToNextPage();
            event.accepted = true;
        }
        else if(event.key === Qt.Key_Home){
            listView.positionViewAtBeginning();
            event.accepted = true;
        }
        else if(event.key === Qt.Key_End){
            listView.positionViewAtEnd();
            event.accepted = true;
        }
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 0
        model: documentManager.activeDocument ? documentManager.activeDocument.pageModel : null

        WheelHandler {
                id: zoomWheelHandler
                // Trackpads send pinch-to-zoom as wheel events with the Ctrl modifier
                acceptedModifiers: Qt.ControlModifier

                onWheel: (event) => {
                    // event.angleDelta.y indicates zoom direction on trackpad pinch
                    if (event.angleDelta.y > 0) {
                        zoomIn();
                    } else if (event.angleDelta.y < 0) {
                        zoomOut();
                    }
                    event.accepted = true; // Stop it from scrolling the page when zooming
                }
        }

        onContentYChanged: {
            let idx = listView.indexAt(contentX, contentY + 20);
            if (idx >= 0 && idx < totalPages) {
                currentPage = idx + 1;
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: vbar
            active: true
            policy: ScrollBar.AlwaysOn
        }

        delegate: Item {
                    id: pageDelegate
                    property real uniformWidth: listView.width * 0.65
                    property real uniformHeight: uniformWidth * 1.414
                    property real scaledWidth: uniformWidth * currentZoom
                    property real scaledHeight: uniformHeight * currentZoom
                    width: listView.width
                    height: (pageRotation === 90 || pageRotation === 270) ? scaledWidth : scaledHeight

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.centerIn: parent
                        width: scaledWidth
                        height: scaledHeight
                        rotation: pageRotation
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
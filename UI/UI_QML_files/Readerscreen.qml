import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Custom_Items"
Rectangle {
    id: readerScreen
    objectName: "readerView"
    color: "#121212"

    property int currentPage: 1
    property int totalPages: documentManager.activeDocument ? documentManager.activeDocument.totalPageNumber : 0
    property real currentZoom: 1
    property real pageRotation: 0
    property bool isTableOfContentsVisible: false

    focus: true
    activeFocusOnTab: true

    Component.onCompleted: {
        forceActiveFocus();
    }

    function zoomIn() {
        if (currentZoom < 6.0)
            currentZoom += 0.2;
    }

    function zoomOut() {
        if (currentZoom > 0.6)
            currentZoom -= 0.2;
    }

    function goToNextPage() {
        if (currentPage < totalPages) {
            currentPage++;
            listView.currentIndex = currentPage - 1;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Beginning);
        }
    }

    function goToPreviousPage() {
        if (currentPage > 1) {
            currentPage--;
            listView.currentIndex = currentPage - 1;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Beginning);
        }
    }

    function jumpToPage(pageNum) {
        currentPage = pageNum;
        if (currentPage > 0 && currentPage <= totalPages) {
            listView.currentIndex = currentPage - 1;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Beginning);
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
        else if(event.key === Qt.Key_Left){
            listView.contentX = Math.max(listView.contentX - scrollStep, 0);
            event.accepted = true;
        }
        else if(event.key === Qt.Key_Right){
            listView.contentX = Math.min(listView.contentX + scrollStep, listView.contentWidth - listView.width);
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
            currentPage = 1;
            listView.currentIndex = 0;
            listView.positionViewAtBeginning();
            event.accepted = true;
        }
        else if(event.key === Qt.Key_End){
            currentPage = totalPages;
            listView.currentIndex = totalPages - 1;
            listView.positionViewAtEnd();
            event.accepted = true;
        }
    }

    Item{ /*RowLayout not used because the rectangle on the scroll bar was out
            of place and ran into other issues trying to work around using the
            RowLayout */
            anchors.fill: parent
            C_TableOfContentsSidebar{
                id:tableOfContents
                visible: isTableOfContentsVisible
                reader: readerScreen
                anchors{
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
            }

            ListView {
                id: listView
                anchors {
                    left: isTableOfContentsVisible ? tableOfContents.right : parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                clip: true
                spacing: 0
                model: documentManager.activeDocument ? documentManager.activeDocument : null

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


            flickableDirection: Flickable.HorizontalAndVerticalFlick

            // This forces the horizontal scrollbar handle to shrink and stops it from snapping back.
            contentWidth: {
                let maxW = listView.width;
                for (let i = 0; i < contentItem.children.length; ++i) {
                    let child = contentItem.children[i];
                    if (child.width && child.width > maxW) {
                        maxW = child.width;
                    }
                }
                return maxW;
            }

            ScrollBar.vertical: ScrollBar {
                id: vbar
                parent: listView.parent
                x: listView.x + listView.width - width
                y: listView.y
                height: listView.height
                active: true
                policy: ScrollBar.AlwaysOn
                stepSize: 1 / totalPages
                z: 100
            }

            ScrollBar.horizontal: ScrollBar {
                id: hbar
                parent: listView.parent
                x: listView.x
                y: listView.y + listView.height - height
                width: listView.width - vbar.width
                active: true
                policy: ScrollBar.AlwaysOn
                z: 100
            }
            delegate: Item {
                id: pageDelegate
                property real uniformWidth: listView.width * 0.65
                property real uniformHeight: uniformWidth * 1.414
                property real scaledWidth: uniformWidth * currentZoom
                property real scaledHeight: uniformHeight * currentZoom
                property real effectivePageWidth: (pageRotation === 90 || pageRotation === 270) ? scaledHeight : scaledWidth
                property real effectivePageHeight: (pageRotation === 90 || pageRotation === 270) ? scaledWidth : scaledHeight
                width: Math.max(listView.width, effectivePageWidth + 80)
                height: effectivePageHeight + 40

                Rectangle {
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
}
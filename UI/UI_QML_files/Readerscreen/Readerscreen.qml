import QtQuick
import QtQuick.Layouts
import ShokaReader

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
            documentPageView.currentIndex = currentPage - 1;
            documentPageView.positionViewAtIndex(documentPageView.currentIndex, ListView.Beginning);
        }
    }

    function goToPreviousPage() {
        if (currentPage > 1) {
            currentPage--;
            documentPageView.currentIndex = currentPage - 1;
            documentPageView.positionViewAtIndex(documentPageView.currentIndex, ListView.Beginning);
        }
    }

    function jumpToPage(pageNum) {
        if (pageNum > 0 && pageNum <= totalPages) {
            currentPage = pageNum;
            documentPageView.currentIndex = currentPage - 1;
            documentPageView.positionViewAtIndex(documentPageView.currentIndex, ListView.Beginning);
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

    function goToFirstPage(){
        currentPage = 1;
        documentPageView.currentIndex = 0;
        documentPageView.positionViewAtBeginning();
    }

    function goToLastPage(){
        currentPage = totalPages;
        documentPageView.currentIndex = totalPages - 1;
        documentPageView.positionViewAtEnd();
    }

    Keys.onPressed: (event) => {
        let scrollStep = 60;
        if(event.key === Qt.Key_Up){
            documentPageView.contentY = Math.max(documentPageView.contentY - scrollStep, 0);
            event.accepted = true;
        }
        else if(event.key === Qt.Key_Down){
            documentPageView.contentY = Math.min(documentPageView.contentY + scrollStep, documentPageView.contentHeight - documentPageView.height);
            event.accepted = true;
        }
        else if(event.key === Qt.Key_Left){
            documentPageView.contentX = Math.max(documentPageView.contentX - scrollStep, 0);
            event.accepted = true;
        }
        else if(event.key === Qt.Key_Right){
            documentPageView.contentX = Math.min(documentPageView.contentX + scrollStep, documentPageView.contentWidth - documentPageView.width);
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
            goToFirstPage();
            event.accepted = true;
        }
        else if(event.key === Qt.Key_End){
            goToLastPage();
            event.accepted = true;
        }
    }

    Item{ /*RowLayout not used because the rectangle on the scroll bar was out
            of place and ran into other issues trying to work around using the
            RowLayout */
            anchors.fill: parent
            TableOfContentsSidebar{
                id:tableOfContents
                visible: isTableOfContentsVisible
                reader: readerScreen
            }

            DocumentPageView{
                id:documentPageView
            }
    }
}
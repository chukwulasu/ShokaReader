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

    function goToFirstPage(){
        currentPage = 1;
        listView.currentIndex = 0;
        listView.positionViewAtBeginning();
    }

    function goToLastPage(){
        currentPage = totalPages;
        listView.currentIndex = totalPages - 1;
        listView.positionViewAtEnd();
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
                cacheBuffer: 1000 // Keeps delegates instantiated outside the visible area for smoother scrolling
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
                property var textRects: []
                property var pageSizePoints: Qt.size(0, 0)

                property real uniformWidth: listView.width * 0.65
                property real pageAspectRatio:
                    pageSizePoints.width > 0
                        ? pageSizePoints.height / pageSizePoints.width
                        : 1.414

                property real uniformHeight: uniformWidth * pageAspectRatio
                property real scaledWidth: uniformWidth * currentZoom
                property real scaledHeight: uniformHeight * currentZoom
                property real effectivePageWidth: (pageRotation === 90 || pageRotation === 270) ? scaledHeight : scaledWidth
                property real effectivePageHeight: (pageRotation === 90 || pageRotation === 270) ? scaledWidth : scaledHeight

                width: Math.max(listView.width, effectivePageWidth + 80)
                height: effectivePageHeight + 40

                Component.onCompleted: {
                    if (documentManager.activeDocument) {
                        textRects = documentManager.activeDocument.getPageTextRects(index);
                        pageSizePoints = documentManager.activeDocument.getPageSizePoints(index);
                    }
                }
                Rectangle {
                    id: pageContainer
                    anchors.centerIn: parent
                    width: scaledWidth
                    height: scaledHeight
                    rotation: pageRotation
                    color: "#FFFFFF"
                    border.color: "#333333"
                    border.width: 1

                    property bool isSelecting: false
                    property int selectionStartIndex: -1
                    property int selectionEndIndex: -1
                    property string extractedText: ""

                    function mapMouseToPdf(mx, my) {
                        let pw = pageContainer.width;
                        let ph = pageContainer.height;
                        let unrotatedX = mx;
                        let unrotatedY = my;

                        if (pageRotation === 90) {
                            unrotatedX = my;
                            unrotatedY = pw - mx;
                        } else if (pageRotation === 180) {
                            unrotatedX = pw - mx;
                            unrotatedY = ph - my;
                        } else if (pageRotation === 270) {
                            unrotatedX = ph - my;
                            unrotatedY = mx;
                        }

                        let scaleX = pageSizePoints.width / pw;
                        let scaleY = pageSizePoints.height / ph;
                        return Qt.point(unrotatedX * scaleX, unrotatedY * scaleY);
                    }

                    // Rectangle-aware hit testing to prevent selection jumping
                    function findNearestWordIndex(pt) {
                        if (textRects.length === 0)
                            return -1;

                        // First: exact hit test inside box bounds
                        for (let i = 0; i < textRects.length; ++i) {
                            let box = textRects[i];
                            if (pt.x >= box.x && pt.x <= box.x + box.width &&
                                pt.y >= box.y && pt.y <= box.y + box.height) {
                                return i;
                            }
                        }

                        // Second: nearest rectangle scoring
                        let bestIndex = -1;
                        let bestScore = Number.MAX_VALUE;

                        for (let i = 0; i < textRects.length; ++i) {
                            let box = textRects[i];

                            let xDistance = pt.x < box.x ? box.x - pt.x : (pt.x > box.x + box.width ? pt.x - (box.x + box.width) : 0);
                            let yDistance = pt.y < box.y ? box.y - pt.y : (pt.y > box.y + box.height ? pt.y - (box.y + box.height) : 0);

                            let score = yDistance * 10 + xDistance;

                            if (score < bestScore) {
                                bestScore = score;
                                bestIndex = i;
                            }
                        }

                        return bestIndex;
                    }

                    function boxesAreOnSameLine(a, b) {
                        let aBottom = a.y + a.height;
                        let bBottom = b.y + b.height;
                        let overlapTop = Math.max(a.y, b.y);
                        let overlapBottom = Math.min(aBottom, bBottom);
                        let overlap = Math.max(0, overlapBottom - overlapTop);
                        let smallerHeight = Math.min(a.height, b.height);
                        return smallerHeight > 0 && overlap >= smallerHeight * 0.5;
                    }

                    // Computes continuous line spans based on actual vertical overlap relationships
                    function getSelectedLineSpans() {
                        if (selectionStartIndex === -1 || selectionEndIndex === -1 || textRects.length === 0)
                            return [];

                        let minIdx = Math.min(selectionStartIndex, selectionEndIndex);
                        let maxIdx = Math.max(selectionStartIndex, selectionEndIndex);

                        let selectedBoxes = [];
                        for (let i = minIdx; i <= maxIdx; i++) {
                            selectedBoxes.push(textRects[i]);
                        }

                        let lines = [];
                        for (let box of selectedBoxes) {
                            let placed = false;
                            for (let line of lines) {
                                if (boxesAreOnSameLine(line[0], box)) {
                                    line.push(box);
                                    placed = true;
                                    break;
                                }
                            }
                            if (!placed) {
                                lines.push([box]);
                            }
                        }

                        let spans = [];
                        let invScaleX = pageContainer.width / pageSizePoints.width;
                        let invScaleY = pageContainer.height / pageSizePoints.height;

                        for (let lineBoxes of lines) {
                            lineBoxes.sort((a, b) => a.x - b.x);

                            let lastIdx = lineBoxes.length - 1;
                            let minX = lineBoxes[0].x;
                            let maxX = lineBoxes[lastIdx].x + lineBoxes[lastIdx].width;
                            let minY = lineBoxes[0].y;
                            let minH = lineBoxes[0].height;

                            for (let b of lineBoxes) {
                                minY = Math.min(minY, b.y);
                                minH = Math.max(minH, b.height);
                            }

                            spans.push({
                                x: minX * invScaleX,
                                y: minY * invScaleY,
                                width: (maxX - minX) * invScaleX,
                                height: minH * invScaleY
                            });
                        }
                        return spans;
                    }

                    Image {
                        id: pageImage
                        anchors.fill: parent
                        cache: false // Keeping image cache disabled per user setup
                        retainWhileLoading: true // Keeps previous image visible during asynchronous source changes to reduce flashing
                        source: "image://documentProvider/page_" + index
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    // CONTINUOUS HIGHLIGHTER: Repaints whenever selection indexes update
                    Repeater {
                        model: {
                            let s1 = pageContainer.selectionStartIndex;
                            let s2 = pageContainer.selectionEndIndex;
                            return pageContainer.getSelectedLineSpans();
                        }
                        delegate: Rectangle {
                            required property var modelData

                            x: modelData.x
                            y: modelData.y
                            width: modelData.width
                            height: modelData.height

                            color: "#400000FF" // Smooth semi-transparent blue highlight ribbon
                            border.color: "transparent"
                        }
                    }

                    MouseArea {
                        id: dragSelectionArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true

                        onPressed: (mouse) => {
                            if (textRects.length === 0) return;
                            // Clear previous selection and start fresh on press for trackpad/mouse compatibility
                            pageContainer.isSelecting = true;
                            let pt = pageContainer.mapMouseToPdf(mouse.x, mouse.y);
                            let idx = pageContainer.findNearestWordIndex(pt);
                            pageContainer.selectionStartIndex = idx;
                            pageContainer.selectionEndIndex = idx;
                            pageContainer.extractedText = "";
                        }

                        onPositionChanged: (mouse) => {
                            if (!pageContainer.isSelecting) return;
                            let pt = pageContainer.mapMouseToPdf(mouse.x, mouse.y);
                            let idx = pageContainer.findNearestWordIndex(pt);
                            if (idx >= 0)
                                pageContainer.selectionEndIndex = idx;
                        }

                        onReleased: (mouse) => {
                            if (!pageContainer.isSelecting) return;
                            pageContainer.isSelecting = false;

                            let minIdx = Math.min(pageContainer.selectionStartIndex, pageContainer.selectionEndIndex);
                            let maxIdx = Math.max(pageContainer.selectionStartIndex, pageContainer.selectionEndIndex);

                            // If start and end index are identical (just a click without dragging), clear selection
                            if (minIdx === maxIdx) {
                                pageContainer.selectionStartIndex = -1;
                                pageContainer.selectionEndIndex = -1;
                                pageContainer.extractedText = "";
                                return;
                            }

                            let collectedText = "";
                            for (let i = minIdx; i <= maxIdx; i++) {
                                collectedText += textRects[i].text + " ";
                            }

                            if (collectedText.trim().length > 0) {
                                pageContainer.extractedText = collectedText.trim();
                                console.log("[QML] Range Selection Success! Copied text: " + pageContainer.extractedText);
                            }
                        }
                    }
                }
            }
        }
    }
}
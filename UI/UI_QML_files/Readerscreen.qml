import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Custom_Items"

Rectangle {
    id: readerScreen
    objectName: "readerScreen"
    color: "#121212"

    property int currentPage: 1
    property int totalPages: (documentManager.activeDocument !== null) ? documentManager.activeDocument.totalPageNumber : 0
    property real currentZoom: 1
    property real pageRotation: 0
    property bool isTableOfContentsVisible: false

    // Multi-page document selection tracking
    property int selStartPage: -1
    property int selStartWord: -1
    property int selEndPage: -1
    property int selEndWord: -1
    property bool isSelectingGlobal: false
    property string activeSelectedText: ""

    // Auto-scroll state during selection
    property real autoScrollSpeed: 0

    Timer {
        id: autoScrollTimer
        interval: 16 // ~60 FPS smooth scrolling
        running: autoScrollSpeed !== 0
        repeat: true
        onTriggered: {
            if (autoScrollSpeed !== 0) {
                let newY = listView.contentY + autoScrollSpeed;
                listView.contentY = Math.max(0, Math.min(newY, listView.contentHeight - listView.height));
            }
        }
    }

    // Global hit-test helper to find which page and which word is under the pointer
    function hitTestGlobal(scenePt) {
        let contentPt = listView.contentItem.mapFromItem(null, scenePt.x, scenePt.y);
        let targetIndex = listView.indexAt(contentPt.x, contentPt.y);
        if (targetIndex < 0 || targetIndex >= totalPages) return null;

        let delegateItem = listView.itemAtIndex(targetIndex);
        if (!delegateItem) return null;

        let pageBox = delegateItem.pageContainerRef;
        if (!pageBox) return null;

        let pdfPt = pageBox.mapMouseToPdf(scenePt);
        let wordIdx = pageBox.findNearestWordIndex(pdfPt);

        return {
            page: targetIndex,
            word: wordIdx
        };
    }

    function escapeHtml(str) {
        return str.replace(/&/g, "&amp;")
                  .replace(/</g, "&lt;")
                  .replace(/>/g, "&gt;")
                  .replace(/"/g, "&quot;")
                  .replace(/'/g, "&#039;");
    }

    // Collects text preserving line wraps, paragraph structure, alignment, and proportional font size
    function collectGlobalText() {
        if (selStartPage === -1 || selEndPage === -1 || !documentManager.activeDocument) {
            return "";
        }

        let isForward = (selStartPage < selEndPage) || (selStartPage === selEndPage && selStartWord <= selEndWord);
        let pStart = isForward ? selStartPage : selEndPage;
        let pEnd   = isForward ? selEndPage : selStartPage;
        let wStart = isForward ? selStartWord : selEndWord;
        let wEnd   = isForward ? selEndWord : selStartWord;

        let htmlOutput = "";

        for (let p = pStart; p <= pEnd; ++p) {
            let rects = documentManager.activeDocument.getPageTextRects(p);
            if (!rects || rects.length === 0) continue;

            let pageSize = (typeof documentManager.activeDocument.getPageSizePoints === "function")
                           ? documentManager.activeDocument.getPageSizePoints(p)
                           : Qt.size(612, 792);
            let pageWidth = (pageSize && pageSize.width > 0) ? pageSize.width : 612;

            let firstW = (p === pStart) ? Math.max(0, wStart) : 0;
            let lastW  = (p === pEnd)   ? Math.min(rects.length - 1, wEnd) : rects.length - 1;

            if (firstW > lastW) continue;

            // 1. Group selected boxes on this page into visual lines
            let lines = [];
            let currentLine = [];

            for (let w = firstW; w <= lastW; ++w) {
                let box = rects[w];
                if (!box || !box.text) continue;

                if (currentLine.length === 0) {
                    currentLine.push(box);
                } else {
                    let prevBox = currentLine[currentLine.length - 1];
                    let overlapTop = Math.max(prevBox.y, box.y);
                    let overlapBottom = Math.min(prevBox.y + prevBox.height, box.y + box.height);
                    let overlap = Math.max(0, overlapBottom - overlapTop);
                    let minH = Math.min(prevBox.height, box.height);
                    let sameLine = (minH > 0 && overlap >= minH * 0.45);

                    if (sameLine) {
                        currentLine.push(box);
                    } else {
                        lines.push(currentLine);
                        currentLine = [box];
                    }
                }
            }
            if (currentLine.length > 0) {
                lines.push(currentLine);
            }

            if (lines.length === 0) continue;

            // 2. Identify the standard body text left margin for this page
            let bodyLeftMargin = 999999;
            for (let ln of lines) {
                let minX = ln[0].x;
                for (let b of ln) {
                    if (b.x < minX) minX = b.x;
                }
                if (ln.length >= 3 && minX < bodyLeftMargin) {
                    bodyLeftMargin = minX;
                }
            }
            if (bodyLeftMargin === 999999) {
                bodyLeftMargin = 72;
            }

            // 3. Process each line, capturing text alignment and font size in points
            let prevLineInfo = null;
            let currentParagraphLines = [];
            let currentParagraphIsCentered = false;
            let currentParagraphFontSize = 11;

            function flushParagraph() {
                if (currentParagraphLines.length === 0) return;
                let textContent = currentParagraphLines.join(currentParagraphIsCentered ? "<br/>" : " ");

                let style = "margin: 6px 0; font-size: " + currentParagraphFontSize + "pt;";
                if (currentParagraphIsCentered) {
                    style += " text-align: center;";
                    htmlOutput += "<p align=\"center\" style=\"" + style + "\">" + textContent + "</p>";
                } else {
                    style += " text-align: left;";
                    htmlOutput += "<p align=\"left\" style=\"" + style + "\">" + textContent + "</p>";
                }

                currentParagraphLines = [];
            }

            for (let ln of lines) {
                let lineMinX = ln[0].x;
                let lineMaxX = ln[0].x + ln[0].width;
                let lineMinY = ln[0].y;
                let lineMaxY = ln[0].y + ln[0].height;
                let words = [];
                let maxWordHeight = 0;

                for (let b of ln) {
                    if (b.x < lineMinX) lineMinX = b.x;
                    if (b.x + b.width > lineMaxX) lineMaxX = b.x + b.width;
                    if (b.y < lineMinY) lineMinY = b.y;
                    if (b.y + b.height > lineMaxY) lineMaxY = b.y + b.height;
                    if (b.height > maxWordHeight) maxWordHeight = b.height;
                    words.push(escapeHtml(b.text));
                }

                let lineText = words.join(" ");
                let leftMargin = lineMinX;
                let rightMargin = pageWidth - lineMaxX;
                let marginDiff = Math.abs(leftMargin - rightMargin);
                let lineWidth = lineMaxX - lineMinX;

                // Center alignment check
                let isCentered = (marginDiff < 32) && (leftMargin > bodyLeftMargin + 18 || lineWidth < pageWidth * 0.65);

                // Line font size in points directly from word bounding heights
                let lineFontSize = Math.max(6, Math.round(maxWordHeight));

                let isNewBlock = false;
                if (!prevLineInfo) {
                    isNewBlock = true;
                } else {
                    let vGap = lineMinY - prevLineInfo.maxY;
                    let prevH = prevLineInfo.maxY - prevLineInfo.minY;
                    let fontDiff = Math.abs(lineFontSize - prevLineInfo.fontSize);

                    // Break paragraph if alignment switches, vertical gap is large, or font size shifts noticeably (>= 3pt)
                    if (isCentered !== prevLineInfo.isCentered || vGap > prevH * 0.55 || fontDiff >= 3) {
                        isNewBlock = true;
                    }
                }

                if (isNewBlock) {
                    flushParagraph();
                    currentParagraphIsCentered = isCentered;
                    currentParagraphFontSize = lineFontSize;
                }

                currentParagraphLines.push(lineText);

                prevLineInfo = {
                    minY: lineMinY,
                    maxY: lineMaxY,
                    isCentered: isCentered,
                    fontSize: lineFontSize
                };
            }

            flushParagraph();
        }

        return htmlOutput;
    }

    // Clipboard helper for QML with RichText support
    TextEdit {
        id: clipboardBridge
        visible: false
        textFormat: TextEdit.RichText
    }

    function copyToClipboard(textToCopy) {
        if (!textToCopy || textToCopy.length === 0) return;
        clipboardBridge.textFormat = TextEdit.RichText;
        clipboardBridge.text = textToCopy;
        clipboardBridge.selectAll();
        clipboardBridge.copy();
        console.log("[Clipboard] Copied formatted text with alignment and font sizes preserved.");
    }

    focus: true
    activeFocusOnTab: true

    Component.onCompleted: {
        forceActiveFocus();
    }

    // When the TOC is closed, return keyboard focus to the reader so the
    // navigation keys immediately control the document again.
    onIsTableOfContentsVisibleChanged: {
        if (!isTableOfContentsVisible) {
            forceActiveFocus();
        }
    }

    //TODO: remove later after you are done with the product, to be used to test lifecycle of stackview items
    Component.onDestruction: {
        console.log("[Lifecycle] Readerscreen has been destroyed and freed from memory.");
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
        if (pageNum > 0 && pageNum <= totalPages) {
            currentPage = pageNum;
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

    // Global Ctrl+C Shortcut
    Shortcut {
        sequence: [StandardKey.Copy]
        enabled: readerScreen.activeSelectedText.length > 0
        onActivated: {
            readerScreen.copyToClipboard(readerScreen.activeSelectedText);
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

            // Global TapHandler to dismiss selection on a plain left-click
            TapHandler {
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.DragThreshold
                onTapped: {
                    readerScreen.forceActiveFocus();
                    readerScreen.selStartPage = -1;
                    readerScreen.selStartWord = -1;
                    readerScreen.selEndPage = -1;
                    readerScreen.selEndWord = -1;
                    readerScreen.activeSelectedText = "";
                    globalFloatingCopyMenu.visible = false;
                }
            }

            // Global Right-Click Handler for Floating Copy Menu
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    if (readerScreen.activeSelectedText.length === 0) return;

                    let hit = readerScreen.hitTestGlobal(point.scenePosition);
                    if (!hit || hit.word < 0) {
                        globalFloatingCopyMenu.visible = false;
                        return;
                    }

                    // Position the menu relative to the ListView viewport
                    let localPos = listView.mapFromItem(null, point.scenePosition.x, point.scenePosition.y);
                    globalFloatingCopyMenu.x = Math.max(8, Math.min(localPos.x, listView.width - globalFloatingCopyMenu.width - 8));
                    globalFloatingCopyMenu.y = (localPos.y - globalFloatingCopyMenu.height - 4 < 0)
                                               ? (localPos.y + 4)
                                               : (localPos.y - globalFloatingCopyMenu.height - 4);
                    globalFloatingCopyMenu.visible = true;
                }
            }

            // GLOBAL DRAG HANDLER: Spans across page delegates and boundaries
            DragHandler {
                id: globalDragSelection
                target: null
                acceptedButtons: Qt.LeftButton
                dragThreshold: 0
                grabPermissions: PointerHandler.CanTakeOverFromItems

                onActiveChanged: {
                    if (active) {
                        readerScreen.forceActiveFocus();
                        globalFloatingCopyMenu.visible = false;

                        let hit = readerScreen.hitTestGlobal(centroid.scenePosition);
                        if (!hit || hit.word < 0) {
                            readerScreen.isSelectingGlobal = false;
                            readerScreen.selStartPage = -1;
                            readerScreen.selStartWord = -1;
                            readerScreen.selEndPage = -1;
                            readerScreen.selEndWord = -1;
                            readerScreen.activeSelectedText = "";
                            return;
                        }

                        readerScreen.isSelectingGlobal = true;
                        readerScreen.selStartPage = hit.page;
                        readerScreen.selStartWord = hit.word;
                        readerScreen.selEndPage = hit.page;
                        readerScreen.selEndWord = hit.word;
                        readerScreen.activeSelectedText = "";
                    } else {
                        readerScreen.autoScrollSpeed = 0;
                        readerScreen.forceActiveFocus();

                        if (!readerScreen.isSelectingGlobal) return;
                        readerScreen.isSelectingGlobal = false;

                        let text = readerScreen.collectGlobalText();
                        if (text.length > 0) {
                            readerScreen.activeSelectedText = text;
                        } else {
                            readerScreen.selStartPage = -1;
                            readerScreen.selStartWord = -1;
                            readerScreen.selEndPage = -1;
                            readerScreen.selEndWord = -1;
                            readerScreen.activeSelectedText = "";
                        }
                    }
                }

                onCentroidChanged: {
                    if (!active || !readerScreen.isSelectingGlobal) {
                        readerScreen.autoScrollSpeed = 0;
                        return;
                    }

                    // 1. Edge Proximity Auto-Scroll Detection
                    let viewPos = listView.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
                    let margin = 50;

                    if (viewPos.y < margin) {
                        let factor = Math.max(0, 1 - (viewPos.y / margin));
                        readerScreen.autoScrollSpeed = -(10 + factor * 25);
                    } else if (viewPos.y > (listView.height - margin)) {
                        let factor = Math.max(0, (viewPos.y - (listView.height - margin)) / margin);
                        readerScreen.autoScrollSpeed = 10 + factor * 25;
                    } else {
                        readerScreen.autoScrollSpeed = 0;
                    }

                    // 2. Global page & word coordinate tracking across boundaries
                    let hit = readerScreen.hitTestGlobal(centroid.scenePosition);
                    if (hit && hit.page >= 0) {
                        readerScreen.selEndPage = hit.page;

                        if (hit.word >= 0) {
                            readerScreen.selEndWord = hit.word;
                        }
                    }
                }
            }

            // Global floating copy menu inside the ListView viewport
            C_FloatingCopyMenu {
                id: globalFloatingCopyMenu
                visible: false
                z: 200

                onCopyTriggered: {
                    readerScreen.copyToClipboard(readerScreen.activeSelectedText);
                    visible = false;
                }
            }

            delegate: Item {
                id: pageDelegate
                property var textRects: []
                property var pageSizePoints: Qt.size(0, 0)
                property alias pageContainerRef: pageContainer

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

                    function mapMouseToPdf(scenePoint) {
                        // Convert the pointer from scene coordinates into the
                        // pageContainer's local coordinates. Qt performs the
                        // rotation/position/transform conversion for us.
                        let localPoint = pageContainer.mapFromItem(
                            null,
                            scenePoint.x,
                            scenePoint.y
                        );

                        let scaleX = pageSizePoints.width / pageContainer.width;
                        let scaleY = pageSizePoints.height / pageContainer.height;

                        return Qt.point(
                            localPoint.x * scaleX,
                            localPoint.y * scaleY
                        );
                    }

                    // Geometry-aware hit testing to prevent premature selection jumping
                    function findNearestWordIndex(pt) {
                        if (textRects.length === 0) return -1;

                        // 1. Exact hit test inside box bounds
                        for (let i = 0; i < textRects.length; ++i) {
                            let box = textRects[i];
                            if (pt.x >= box.x && pt.x <= box.x + box.width &&
                                pt.y >= box.y && pt.y <= box.y + box.height) {
                                return i;
                            }
                        }

                        // 2. Pointer is strictly above the first text line on this page
                        if (pt.y < textRects[0].y) {
                            return 0;
                        }

                        // 3. Pointer is strictly below the last text line on this page
                        let lastBox = textRects[textRects.length - 1];
                        if (pt.y > lastBox.y + lastBox.height) {
                            return textRects.length - 1;
                        }

                        // 4. Pointer is on a line but within horizontal whitespace
                        let closestIdx = -1;
                        let minDistance = 999999;

                        for (let i = 0; i < textRects.length; ++i) {
                            let box = textRects[i];
                            if (pt.y >= box.y - 4 && pt.y <= box.y + box.height + 4) {
                                let dist = Math.abs(pt.x - (box.x + box.width / 2));
                                if (dist < minDistance) {
                                    minDistance = dist;
                                    closestIdx = i;
                                }
                            }
                        }

                        return closestIdx;
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

                    // Computes line spans for this specific page based on the global selection range
                    function getSelectedLineSpans() {
                        let sPage = readerScreen.selStartPage;
                        let ePage = readerScreen.selEndPage;
                        let sWord = readerScreen.selStartWord;
                        let eWord = readerScreen.selEndWord;

                        if (sPage === -1 || ePage === -1 || sWord === -1 || eWord === -1 || textRects.length === 0)
                            return [];

                        let isForward = (sPage < ePage) || (sPage === ePage && sWord <= eWord);
                        let pStart = isForward ? sPage : ePage;
                        let pEnd   = isForward ? ePage : sPage;
                        let wStart = isForward ? sWord : eWord;
                        let wEnd   = isForward ? eWord : sWord;

                        if (index < pStart || index > pEnd)
                            return [];

                        let firstWord = (index === pStart) ? Math.max(0, wStart) : 0;
                        let lastWord  = (index === pEnd)   ? Math.min(textRects.length - 1, wEnd) : textRects.length - 1;

                        if (firstWord > lastWord) return [];

                        let selectedBoxes = [];
                        for (let i = firstWord; i <= lastWord; i++) {
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

                    // Highlights react to global selection page & word updates
                    Repeater {
                        model: {
                            let _trigger1 = readerScreen.selStartPage;
                            let _trigger2 = readerScreen.selStartWord;
                            let _trigger3 = readerScreen.selEndPage;
                            let _trigger4 = readerScreen.selEndWord;
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
                }
            }
        }
    }
}
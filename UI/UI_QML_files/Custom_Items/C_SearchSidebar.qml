import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: searchSidebar
    property var reader: null
    implicitWidth: 300
    implicitHeight: parent.height
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 1

    property var searchResults: []
    property bool isSearching: false
    property bool matchCase: false
    property bool matchWholeWord: false

    function triggerSearch() {
        if (!documentManager.activeDocument || searchField.text.trim().length === 0) {
            searchResults = [];
            isSearching = false;
            if (documentManager.activeDocument) {
                documentManager.activeDocument.cancelSearch();
            }
            if (searchSidebar.reader) {
                searchSidebar.reader.searchPhrase = "";
            }
            return;
        }

        let query = searchField.text.trim();
        if (searchSidebar.reader) {
            searchSidebar.reader.searchPhrase = query;
            searchSidebar.reader.searchMatchCase = matchCase;
            searchSidebar.reader.searchMatchWholeWord = matchWholeWord;
        }

        isSearching = true;
        documentManager.activeDocument.startSearch(query, matchCase, matchWholeWord);
    }

    Connections {
        target: documentManager.activeDocument
        ignoreUnknownSignals: true
        function onSearchResultsReady(query, results) {
            if (query === searchField.text.trim()) {
                searchSidebar.searchResults = results;
                searchSidebar.isSearching = false;
            }
        }
    }

    Timer {
        id: searchDebounceTimer
        interval: 250
        repeat: false
        onTriggered: searchSidebar.triggerSearch()
    }

    onVisibleChanged: {
        if (visible) {
            searchField.forceActiveFocus();
            searchField.selectAll();
            if (searchField.text.trim().length > 0) {
                searchDebounceTimer.restart();
            }
        } else {
            if (documentManager.activeDocument) {
                documentManager.activeDocument.cancelSearch();
            }
            if (searchSidebar.reader) {
                searchSidebar.reader.searchPhrase = "";
            }
            isSearching = false;
        }
    }

    TapHandler {
        onTapped: {
            if (searchField.activeFocus) {
                if (searchSidebar.reader) {
                    searchSidebar.reader.forceActiveFocus();
                } else {
                    searchSidebar.forceActiveFocus();
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        // Header Row
        RowLayout {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            Text {
                text: "Search"
                font.bold: true
                font.pixelSize: 14
                color: "#333333"
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "✕"
                flat: true
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                onClicked: {
                    if (searchSidebar.reader) {
                        searchSidebar.reader.isSearchSidebarVisible = false;
                    }
                }
            }
        }

        // Search Input Box
        Rectangle {
            id: searchInputBox
            anchors.top: headerRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            radius: 4
            color: "#FFFFFF"
            border.color: searchField.activeFocus ? "#80bdff" : "#ced4da"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 4

                Text {
                    text: "🔍"
                    font.pixelSize: 12
                    color: "#6c757d"
                    Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "Search document..."
                    font.pixelSize: 12
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    background: Item {}

                    onTextChanged: searchDebounceTimer.restart()

                    Keys.onEscapePressed: (event) => {
                        if (searchSidebar.reader) {
                            searchSidebar.reader.isSearchSidebarVisible = false;
                        }
                        event.accepted = true;
                    }
                }

                Text {
                    text: "✕"
                    font.pixelSize: 11
                    color: "#6c757d"
                    visible: searchField.text.length > 0
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: {
                            searchField.text = "";
                            searchSidebar.searchResults = [];
                            searchSidebar.isSearching = false;
                            if (documentManager.activeDocument) {
                                documentManager.activeDocument.cancelSearch();
                            }
                            if (searchSidebar.reader) {
                                searchSidebar.reader.searchPhrase = "";
                            }
                        }
                    }
                }

                // Match Case Button ("Aa")
                Rectangle {
                    width: 24
                    height: 22
                    radius: 3
                    color: searchSidebar.matchCase ? "#d0d7de" : (caseHover.containsMouse ? "#eceff1" : "transparent")
                    border.color: searchSidebar.matchCase ? "#57606a" : "transparent"
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "Aa"
                        font.pixelSize: 11
                        font.bold: true
                        color: searchSidebar.matchCase ? "#24292f" : "#6c757d"
                    }

                    MouseArea {
                        id: caseHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchSidebar.matchCase = !searchSidebar.matchCase;
                            searchSidebar.triggerSearch();
                        }
                    }

                    ToolTip.visible: caseHover.containsMouse
                    ToolTip.text: "Match Case"
                    ToolTip.delay: 300
                }

                // Match Whole Word Button ("ab")
                Rectangle {
                    width: 24
                    height: 22
                    radius: 3
                    color: searchSidebar.matchWholeWord ? "#d0d7de" : (wordHover.containsMouse ? "#eceff1" : "transparent")
                    border.color: searchSidebar.matchWholeWord ? "#57606a" : "transparent"
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "ab"
                            font.pixelSize: 11
                            font.bold: true
                            color: searchSidebar.matchWholeWord ? "#24292f" : "#6c757d"
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 12
                            height: 1.5
                            color: searchSidebar.matchWholeWord ? "#24292f" : "#6c757d"
                        }
                    }

                    MouseArea {
                        id: wordHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchSidebar.matchWholeWord = !searchSidebar.matchWholeWord;
                            searchSidebar.triggerSearch();
                        }
                    }

                    ToolTip.visible: wordHover.containsMouse
                    ToolTip.text: "Match Whole Word"
                    ToolTip.delay: 300
                }
            }
        }

        // Search Status Label
        Text {
            id: countLabel
            anchors.top: searchInputBox.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            text: searchSidebar.isSearching
                  ? "Searching..."
                  : ("Search results (" + searchSidebar.searchResults.length + ")")
            font.bold: true
            font.pixelSize: 13
            color: searchSidebar.isSearching ? "#0d6efd" : "#212529"
            visible: searchField.text.trim().length > 0
        }

        // No matches label
        Text {
            anchors.top: countLabel.bottom
            anchors.topMargin: 20
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "No matches found"
            font.pixelSize: 13
            color: "#6c757d"
            visible: searchField.text.trim().length > 0 &&
                     !searchSidebar.isSearching &&
                     searchSidebar.searchResults.length === 0
        }

        // Virtualized Results ListView (scales to thousands of matches without lag)
        ListView {
            id: resultsListView
            anchors.top: countLabel.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            clip: true
            spacing: 3
            visible: searchSidebar.searchResults.length > 0
            model: searchSidebar.searchResults

            ScrollBar.vertical: ScrollBar {
                id: vbar
                active: true
                policy: ScrollBar.AlwaysOn
                width: 6

                background: Rectangle {
                    radius: 3
                    color: "#e1e4e8"
                }

                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: vbar.pressed ? "#505a69" : (vbar.hovered ? "#788290" : "#9da4ad")
                }
            }

            delegate: Rectangle {
                width: resultsListView.width - 8
                height: Math.max(34, contentRow.implicitHeight + 8)
                color: itemHover.containsMouse ? "#eceff1" : "transparent"
                radius: 4

                MouseArea {
                    id: itemHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (searchField.activeFocus && searchSidebar.reader) {
                            searchSidebar.reader.forceActiveFocus();
                        }
                        if (searchSidebar.reader) {
                            searchSidebar.reader.jumpToPage(modelData.pageNum);
                        }
                    }
                }

                RowLayout {
                    id: contentRow
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    // Snippet: beforeText + [highlighted pill] + afterText
                    Row {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4
                        clip: true

                        Text {
                            text: modelData.textBefore
                            font.pixelSize: 12
                            color: "#495057"
                            elide: Text.ElideLeft
                            maximumLineCount: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            height: matchTextLabel.implicitHeight + 2
                            width: matchTextLabel.implicitWidth + 6
                            radius: 2
                            color: "#fff3cd"
                            border.color: "#ffeeba"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: matchTextLabel
                                anchors.centerIn: parent
                                text: modelData.matchText
                                font.pixelSize: 12
                                font.bold: true
                                color: "#856404"
                            }
                        }

                        Text {
                            text: modelData.textAfter
                            font.pixelSize: 12
                            color: "#495057"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Page Number
                    Text {
                        text: modelData.pageNum.toString()
                        font.pixelSize: 11
                        color: "#868e96"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
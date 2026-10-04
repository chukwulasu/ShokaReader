import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: activeReadingRoot
    objectName: "activelyReadingscreen"
    color: "#181818"

    signal requestOpenDocument(string filePath, int page, real zoom, real rotation, string fingerprint)

    property bool isGridView: true
    property bool isSearchBarVisible: false
    property string searchQuery: ""

    onIsSearchBarVisibleChanged: {
        if (isSearchBarVisible) {
            searchInput.forceActiveFocus();
        }
    }

    // Filtered list based on search query
    property var displayedList: {
        let raw = (typeof libraryManager !== "undefined" && libraryManager) ? libraryManager.activelyReadingList : [];
        if (!raw) return [];
        if (!searchQuery || searchQuery.trim() === "") {
            return raw;
        }
        let q = searchQuery.toLowerCase().trim();
        return raw.filter(doc => doc.title && doc.title.toLowerCase().includes(q));
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Top Action Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 12

            Text {
                text: "Actively Reading"
                font.bold: true
                font.pixelSize: 22
                color: "#FFFFFF"
            }

            Text {
                text: "(" + (activeReadingRoot.displayedList ? activeReadingRoot.displayedList.length : 0) + ")"
                font.pixelSize: 14
                color: "#888888"
                Layout.alignment: Qt.AlignBaseline
            }

            Item { Layout.fillWidth: true }

            // Inline Search Bar (Toggled via Ctrl+F or search button)
            Rectangle {
                visible: activeReadingRoot.isSearchBarVisible
                Layout.preferredWidth: 240
                Layout.preferredHeight: 32
                color: "#242424"
                radius: 4
                border.color: searchInput.activeFocus ? "#3B82F6" : "#383838"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "🔍"
                        font.pixelSize: 11
                        color: "#888888"
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Filter books..."
                        placeholderTextColor: "#666666"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        background: Item {}

                        onTextChanged: activeReadingRoot.searchQuery = text

                        Keys.onEscapePressed: (event) => {
                            activeReadingRoot.isSearchBarVisible = false;
                            activeReadingRoot.searchQuery = "";
                            text = "";
                            event.accepted = true;
                        }
                    }

                    Text {
                        text: "✕"
                        font.pixelSize: 11
                        color: "#888888"
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: {
                                searchInput.text = "";
                                activeReadingRoot.searchQuery = "";
                            }
                        }
                    }
                }
            }

            // View Mode Toggle (Grid / List)
            Row {
                spacing: 2

                Button {
                    id: gridToggleBtn
                    width: 32
                    height: 32
                    checkable: true
                    checked: activeReadingRoot.isGridView
                    onClicked: activeReadingRoot.isGridView = true
                    ToolTip.visible: hovered
                    ToolTip.text: "Grid View"

                    background: Rectangle {
                        color: gridToggleBtn.checked ? "#333333" : (gridToggleBtn.hovered ? "#282828" : "#1F1F1F")
                        radius: 4
                    }
                    contentItem: Text {
                        text: "⊞"
                        font.pixelSize: 15
                        color: gridToggleBtn.checked ? "#FFFFFF" : "#888888"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: listToggleBtn
                    width: 32
                    height: 32
                    checkable: true
                    checked: !activeReadingRoot.isGridView
                    onClicked: activeReadingRoot.isGridView = false
                    ToolTip.visible: hovered
                    ToolTip.text: "List View"

                    background: Rectangle {
                        color: listToggleBtn.checked ? "#333333" : (listToggleBtn.hovered ? "#282828" : "#1F1F1F")
                        radius: 4
                    }
                    contentItem: Text {
                        text: "☰"
                        font.pixelSize: 15
                        color: listToggleBtn.checked ? "#FFFFFF" : "#888888"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Empty State Notice
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: activeReadingRoot.displayedList.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: activeReadingRoot.searchQuery.length > 0 ? "No matching books found" : "No books currently being read"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#CCCCCC"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: activeReadingRoot.searchQuery.length > 0 ? "Try clearing your search filter." : "Books you navigate past page 1 will automatically appear here."
                    font.pixelSize: 13
                    color: "#777777"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // GRID VIEW
        Flickable {
            id: gridFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: gridFlow.height
            clip: true
            visible: activeReadingRoot.isGridView && activeReadingRoot.displayedList.length > 0

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Flow {
                id: gridFlow
                width: gridFlickable.width
                spacing: 24

                Repeater {
                    model: activeReadingRoot.displayedList

                    delegate: Rectangle {
                        width: 190
                        height: 310
                        radius: 6
                        color: cardHover.containsMouse ? "#242424" : "#1E1E1E"
                        border.color: cardHover.containsMouse ? "#3E3E3E" : "#2A2A2A"
                        border.width: 1

                        MouseArea {
                            id: cardHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                activeReadingRoot.requestOpenDocument(
                                    modelData.filePath,
                                    modelData.currentPage,
                                    modelData.zoom,
                                    modelData.rotation,
                                    modelData.fingerprint
                                );
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // Thumbnail Cover
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 210
                                color: "#141414"
                                radius: 4
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.thumbnailPath ? ("file:///" + modelData.thumbnailPath) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true

                                    // Fallback cover placeholder if thumbnail is missing
                                    Text {
                                        anchors.centerIn: parent
                                        text: "📖"
                                        font.pixelSize: 32
                                        visible: parent.status !== Image.Ready
                                    }
                                }

                                // Mark as Finished button on hover
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: finishBtnHover.containsMouse ? "#DC2626" : "#80000000"
                                    visible: cardHover.containsMouse

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "#FFFFFF"
                                        font.bold: true
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: finishBtnHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        ToolTip.visible: containsMouse
                                        ToolTip.text: "Mark as Finished"
                                        onClicked: libraryManager.markAsFinished(modelData.fingerprint)
                                    }
                                }
                            }

                            // Book Title
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || ""
                                font.pixelSize: 12
                                font.bold: true
                                color: "#E0E0E0"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // Progress Bar
                            ProgressBar {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                from: 0
                                to: Math.max(1, modelData.totalPages)
                                value: modelData.currentPage

                                background: Rectangle {
                                    color: "#2C2C2C"
                                    radius: 2
                                }
                                contentItem: Item {
                                    Rectangle {
                                        width: parent.width * (modelData.totalPages > 0 ? Math.min(1.0, modelData.currentPage / modelData.totalPages) : 0)
                                        height: parent.height
                                        color: "#3B82F6"
                                        radius: 2
                                    }
                                }
                            }

                            // Page Counter
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Page " + modelData.currentPage + " of " + modelData.totalPages
                                    font.pixelSize: 11
                                    color: "#888888"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round((modelData.currentPage / Math.max(1, modelData.totalPages)) * 100) + "%"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#3B82F6"
                                }
                            }
                        }
                    }
                }
            }
        }

        // LIST VIEW
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            visible: !activeReadingRoot.isGridView && activeReadingRoot.displayedList.length > 0
            model: activeReadingRoot.displayedList

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: listView.width
                height: 72
                radius: 6
                color: listRowHover.containsMouse ? "#242424" : "#1E1E1E"
                border.color: listRowHover.containsMouse ? "#3E3E3E" : "#2A2A2A"
                border.width: 1

                MouseArea {
                    id: listRowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        activeReadingRoot.requestOpenDocument(
                            modelData.filePath,
                            modelData.currentPage,
                            modelData.zoom,
                            modelData.rotation,
                            modelData.fingerprint
                        );
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 16

                    // Mini Thumbnail
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 52
                        radius: 3
                        color: "#141414"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: modelData.thumbnailPath ? ("file:///" + modelData.thumbnailPath) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }

                    // Metadata
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || ""
                            font.pixelSize: 13
                            font.bold: true
                            color: "#E0E0E0"
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ProgressBar {
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 4
                                from: 0
                                to: Math.max(1, modelData.totalPages)
                                value: modelData.currentPage

                                background: Rectangle {
                                    color: "#2C2C2C"
                                    radius: 2
                                }
                                contentItem: Item {
                                    Rectangle {
                                        width: parent.width * (modelData.totalPages > 0 ? Math.min(1.0, modelData.currentPage / modelData.totalPages) : 0)
                                        height: parent.height
                                        color: "#3B82F6"
                                        radius: 2
                                    }
                                }
                            }

                            Text {
                                text: "Page " + modelData.currentPage + " / " + modelData.totalPages +
                                      " (" + Math.round((modelData.currentPage / Math.max(1, modelData.totalPages)) * 100) + "%)"
                                font.pixelSize: 11
                                color: "#888888"
                            }
                        }
                    }

                    // Mark Finished Button
                    Button {
                        id: listFinishBtn
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 110
                        text: "Mark Finished"
                        onClicked: libraryManager.markAsFinished(modelData.fingerprint)

                        background: Rectangle {
                            radius: 4
                            color: listFinishBtn.hovered ? "#333333" : "#262626"
                            border.color: "#3E3E3E"
                        }
                        contentItem: Text {
                            text: listFinishBtn.text
                            font.pixelSize: 11
                            color: "#CCCCCC"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
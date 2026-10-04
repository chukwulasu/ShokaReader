import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: bookmarkSidebar
    property var reader: null
    implicitWidth: 300
    implicitHeight: parent.height
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 1

    property string documentFingerprint: ""
    property var rawBookmarks: []
    property int selectedPage: -1

    function refreshBookmarks() {
        if (!documentManager.activeDocument) {
            rawBookmarks = [];
            documentFingerprint = "";
            selectedPage = -1;
            return;
        }

        documentFingerprint = libraryManager.getDocumentFingerprint(documentManager.activeDocument);
        rawBookmarks = libraryManager.getBookmarks(documentFingerprint);

        // Deselect if the selected page was removed
        let exists = false;
        for (let i = 0; i < rawBookmarks.length; ++i) {
            if (rawBookmarks[i].page === selectedPage) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            selectedPage = -1;
        }
    }

    function saveBookmark() {
        if (bookmarkSidebar.documentFingerprint !== "") {
            let targetPage = bookmarkSidebar.reader ? bookmarkSidebar.reader.currentPage : 1;
            let title = bookmarkTitleInput.text.trim();
            libraryManager.addBookmark(bookmarkSidebar.documentFingerprint, targetPage, title);
            bookmarkSidebar.selectedPage = targetPage;
        }
        addBookmarkDialog.close();
    }

    Connections {
        target: libraryManager
        function onLibraryChanged() {
            bookmarkSidebar.refreshBookmarks();
        }
    }

    onVisibleChanged: {
        if (visible) {
            refreshBookmarks();
            searchField.forceActiveFocus();
        } else {
            selectedPage = -1;
            searchField.text = "";
        }
    }

    // Dismiss focus when clicking on the sidebar background
    TapHandler {
        onTapped: {
            if (searchField.activeFocus) {
                if (bookmarkSidebar.reader) {
                    bookmarkSidebar.reader.forceActiveFocus();
                } else {
                    bookmarkSidebar.forceActiveFocus();
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        // Header
        RowLayout {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            Text {
                text: "Bookmark"
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
                    if (bookmarkSidebar.reader) {
                        bookmarkSidebar.reader.isBookmarkSidebarVisible = false;
                    }
                }
            }
        }

        // Search Field
        Rectangle {
            id: searchBox
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
                anchors.rightMargin: 8
                spacing: 6

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
                    placeholderText: "Search bookmarks"
                    font.pixelSize: 12
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    background: Item {}
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
                        onClicked: searchField.text = ""
                    }
                }
            }
        }

        // Action Buttons Row (Add Bookmark & Remove Bookmark)
        RowLayout {
            id: actionsRow
            anchors.top: searchBox.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            // Add Bookmark Button
            Button {
                id: addBtn
                Layout.preferredHeight: 30
                contentItem: Row {
                    spacing: 4
                    anchors.centerIn: parent
                    Text {
                        text: "🔖+"
                        font.pixelSize: 11
                    }
                    Text {
                        text: "Add Bookmark"
                        font.pixelSize: 11
                        color: "#333333"
                    }
                }
                background: Rectangle {
                    radius: 4
                    color: addBtn.hovered ? "#e9ecef" : "#FFFFFF"
                    border.color: "#ced4da"
                    border.width: 1
                }
                onClicked: {
                    bookmarkTitleInput.text = "Page " + (bookmarkSidebar.reader ? bookmarkSidebar.reader.currentPage : 1);
                    addBookmarkDialog.open();
                }
            }

            // Remove Bookmark Button
            Button {
                id: removeBtn
                Layout.preferredHeight: 30
                enabled: bookmarkSidebar.selectedPage !== -1
                opacity: enabled ? 1.0 : 0.5
                contentItem: Row {
                    spacing: 4
                    anchors.centerIn: parent
                    Text {
                        text: "Remove Bookmark"
                        font.pixelSize: 11
                        color: removeBtn.enabled ? "#333333" : "#888888"
                    }
                }
                background: Rectangle {
                    radius: 4
                    color: removeBtn.hovered && removeBtn.enabled ? "#e9ecef" : "#FFFFFF"
                    border.color: "#ced4da"
                    border.width: 1
                }
                onClicked: {
                    if (bookmarkSidebar.selectedPage !== -1 && bookmarkSidebar.documentFingerprint !== "") {
                        libraryManager.removeBookmark(bookmarkSidebar.documentFingerprint, bookmarkSidebar.selectedPage);
                        bookmarkSidebar.selectedPage = -1;
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Empty State
        Text {
            anchors.centerIn: parent
            text: "The document has no bookmarks"
            font.pixelSize: 13
            color: "#6c757d"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: bookmarkSidebar.rawBookmarks.length === 0
        }

        // Filtered Results List
        Flickable {
            id: bookmarksFlickable
            anchors.top: actionsRow.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            contentWidth: width
            contentHeight: bookmarksColumn.height
            clip: true
            visible: bookmarkSidebar.rawBookmarks.length > 0

            ScrollBar.vertical: ScrollBar {
                id: vbar
                parent: bookmarksFlickable.parent
                x: bookmarksFlickable.x + bookmarksFlickable.width - width - 2
                y: bookmarksFlickable.y
                height: bookmarksFlickable.height
                active: true
                policy: ScrollBar.AlwaysOn
                width: 6
                z: 1000

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

            Column {
                id: bookmarksColumn
                width: parent.width - vbar.width - 8
                spacing: 4

                Repeater {
                    model: {
                        let query = searchField.text.trim().toLowerCase();
                        if (query === "") return bookmarkSidebar.rawBookmarks;
                        return bookmarkSidebar.rawBookmarks.filter(bm => {
                            return (bm.title && bm.title.toLowerCase().includes(query)) ||
                                   String(bm.page).includes(query);
                        });
                    }

                    delegate: Rectangle {
                        id: bmRow
                        width: bookmarksColumn.width
                        height: 36
                        radius: 4

                        property bool isSelected: bookmarkSidebar.selectedPage === modelData.page
                        color: isSelected ? "#d0e1fd" : (itemHover.containsMouse ? "#eceff1" : "transparent")

                        MouseArea {
                            id: itemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bookmarkSidebar.selectedPage = modelData.page;
                                if (bookmarkSidebar.reader) {
                                    bookmarkSidebar.reader.jumpToPage(modelData.page);
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "🔖"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.title
                                font.pixelSize: 12
                                color: bmRow.isSelected ? "#0d6efd" : "#212529"
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.page.toString()
                                font.pixelSize: 12
                                color: bmRow.isSelected ? "#0d6efd" : "#6c757d"
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // Modal Dialog to prompt for Bookmark Title
    Dialog {
        id: addBookmarkDialog
        title: "Add Bookmark"
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                text: "Add bookmark for Page " + (bookmarkSidebar.reader ? bookmarkSidebar.reader.currentPage : 1) + ":"
                font.pixelSize: 12
            }

            TextField {
                id: bookmarkTitleInput
                Layout.fillWidth: true
                selectByMouse: true
                focus: true
                onAccepted: {
                    bookmarkSidebar.saveBookmark();
                }
            }
        }

        footer: RowLayout {
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                onClicked: addBookmarkDialog.close()
            }
            Button {
                text: "Save"
                onClicked: bookmarkSidebar.saveBookmark()
            }
        }
    }
}
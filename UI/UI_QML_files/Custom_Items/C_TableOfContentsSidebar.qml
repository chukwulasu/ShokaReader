import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQml.Models

Rectangle {
    id: tocSidebar
    property var reader: null
    implicitWidth: 300
    implicitHeight: parent.height
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 1

    property var expansionState: ({})

    // Clicking anywhere on the sidebar background dismisses focus and the cursor
    TapHandler {
        onTapped: {
            if (searchField.activeFocus) {
                if (tocSidebar.reader) {
                    tocSidebar.reader.forceActiveFocus();
                } else {
                    tocSidebar.forceActiveFocus();
                }
            }
        }
    }

    function getFlattenedToc(items, query, parentPath) {
        if (items === null){
            return [];
        }

        let result = [];
        let lowerQuery = query ? query.toLowerCase().trim() : "";

        for (let i = 0; i < items.length; ++i) {
            let item = items[i];
            let currentPath = parentPath ? (parentPath + "." + i) : String(i);

            function hasMatch(node, q) {
                if (!q) {
                    return true;
                }

                if (node.title && node.title.toLowerCase().includes(q)) return true;
                if (node.TocItemChildren) {
                    for (let c = 0; c < node.TocItemChildren.length; ++c) {
                        if (hasMatch(node.TocItemChildren[c], q)) return true;
                    }
                }

                return false;
            }

            if (!hasMatch(item, lowerQuery)) continue;

            let hasKids = item.TocItemChildren && item.TocItemChildren.length > 0;
            let isExpanded = lowerQuery.length > 0 ? true : (expansionState[currentPath] === true);

            result.push({
                title: item.title,
                pageNum: item.pageNum,
                hasChildren: hasKids,
                level: parentPath ? parentPath.split('.').length : 0,
                path: currentPath,
                expanded: isExpanded
            });

            if (hasKids && isExpanded) {
                let childItems = getFlattenedToc(item.TocItemChildren, query, currentPath);
                for (let j = 0; j < childItems.length; ++j) {
                    result.push(childItems[j]);
                }
            }
        }

        return result;
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        RowLayout {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            Text {
                text: "Table Of Contents"
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
                    if (tocSidebar.reader) {
                        tocSidebar.reader.isTableOfContentsVisible = false;
                    }
                }
            }
        }

        TextField {
            id: searchField
            anchors.top: headerRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            placeholderText: "Search bookmarks"
            leftPadding: 32
            rightPadding: 30
            verticalAlignment: TextInput.AlignVCenter

            // Cursor only renders when the field has active keyboard focus
            cursorVisible: activeFocus

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: (event) => {
                if(tocSidebar.reader !== null){
                    if(event.key === Qt.Key_Home){
                        tocSidebar.reader.goToFirstPage();
                        event.accepted = true;
                    }

                    else if(event.key === Qt.Key_End){
                        tocSidebar.reader.goToLastPage();
                        event.accepted = true;
                    }

                    else if(event.key === Qt.Key_Left){
                        if(searchField.cursorPosition > 0){
                            searchField.cursorPosition -= 1;
                        }
                        event.accepted = true;
                    }

                    else if(event.key === Qt.Key_Right){
                        if(searchField.cursorPosition < searchField.text.length){
                            searchField.cursorPosition += 1;
                        }
                        event.accepted = true;
                    }
                }
            }

            Text {
                text: "🔍"
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 12
                color: "#6c757d"
            }

            Text {
                text: "✕"
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 12
                color: "#6c757d"
                visible: searchField.text.length > 0

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    onClicked: {
                        searchField.text = "";
                    }
                }
            }
        }

        Text {
            anchors.top: searchField.bottom
            anchors.topMargin: 30
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Table Of Contents is Unavailable for this document"
            font.pixelSize: 13
            color: "#6c757d"
            visible: {
                let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                return !rawToc || rawToc.length === 0;
            }
        }

        Flickable {
            id: tocFlickable
            anchors.top: searchField.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            contentWidth: width
            contentHeight: tocColumn.height
            clip: true
            visible: {
                let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                return rawToc && rawToc.length > 0;
            }

            ScrollBar.vertical: ScrollBar {
                id: vbar
                parent: tocFlickable.parent
                x: tocFlickable.x + tocFlickable.width - width - 2
                y: tocFlickable.y
                height: tocFlickable.height

                active: true
                policy: ScrollBar.AlwaysOn
                width: 6
                z: 1000

                padding: 0
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0

                topInset: 0
                bottomInset: 0
                leftInset: 0
                rightInset: 0

                background: Rectangle {
                    radius: 3
                    color: "#e1e4e8"
                }

                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: vbar.pressed
                           ? "#505a69"
                           : (vbar.hovered ? "#788290" : "#9da4ad")
                }
            }

            Column {
                id: tocColumn
                width: parent.width - vbar.width - 8
                spacing: 2

                Repeater {
                    model: {
                        let _trigger = tocSidebar.expansionState;
                        let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                        return getFlattenedToc(rawToc, searchField.text, "");
                    }

                    delegate: Rectangle {
                        id: itemRow
                        width: tocColumn.width
                        height: Math.max(32, contentRow.implicitHeight + 10)
                        color: rowHover.containsMouse ? "#eceff1" : "transparent"
                        radius: 4

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // Steal focus from the search field so the cursor disappears
                                if (searchField.activeFocus) {
                                    if (tocSidebar.reader) {
                                        tocSidebar.reader.forceActiveFocus();
                                    }
                                }

                                if (modelData.pageNum !== undefined && modelData.pageNum > 0 && tocSidebar.reader) {
                                    tocSidebar.reader.jumpToPage(modelData.pageNum);
                                }
                            }
                        }

                        RowLayout {
                            id: contentRow
                            anchors.fill: parent
                            anchors.leftMargin: 8 + (modelData.level * 16)
                            anchors.rightMargin: 8
                            spacing: 6

                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                visible: modelData.hasChildren

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.expanded ? "▼" : "▶"
                                    font.pixelSize: 9
                                    color: "#6c757d"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: {
                                        let newState = Object.assign({}, tocSidebar.expansionState);
                                        newState[modelData.path] = !modelData.expanded;
                                        tocSidebar.expansionState = newState;
                                    }
                                }
                            }

                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignTop
                                visible: !modelData.hasChildren
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.title ? modelData.title : ""
                                font.pixelSize: modelData.level === 0 ? 13 : 12
                                color: modelData.level === 0 ? "#212529" : "#495057"
                                font.weight: modelData.level === 0 ? Font.Medium : Font.Normal
                                wrapMode: Text.Wrap
                            }

                            Item { Layout.fillWidth: false }

                            Text {
                                Layout.preferredWidth: implicitWidth
                                Layout.alignment: Qt.AlignVCenter
                                text: (modelData.pageNum !== undefined && modelData.pageNum > 0) ? modelData.pageNum : ""
                                font.pixelSize: 11
                                color: "#868e96"
                            }
                        }
                    }
                }
            }
        }
    }
}
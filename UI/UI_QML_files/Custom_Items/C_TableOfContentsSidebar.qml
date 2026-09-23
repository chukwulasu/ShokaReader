import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

Rectangle {
    id: tocSidebar
    property var reader: null
    width: 300
    height: parent.height
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 1

    // Tracks expanded state of nodes by their unique path (e.g. "0", "0.2", "0.2.1")
    property var expansionState: ({})

    // Recursive tree-flattening & search-filtering function supporting infinite depth
    function getFlattenedToc(items, query, parentPath) {
        if (!items) return [];
        let result = [];
        let lowerQuery = query ? query.toLowerCase().trim() : "";

        for (let i = 0; i < items.length; ++i) {
            let item = items[i];
            let currentPath = parentPath ? (parentPath + "." + i) : String(i);

            // Helper to check if this node or any of its infinite descendants match the search query
            function hasMatch(node, q) {
                if (!q) return true;
                if (node.title && node.title.toLowerCase().includes(q)) return true;
                if (node.children) {
                    for (let c = 0; c < node.children.length; ++c) {
                        if (hasMatch(node.children[c], q)) return true;
                    }
                }
                return false;
            }

            if (!hasMatch(item, lowerQuery)) continue;

            let hasKids = item.children && item.children.length > 0;
            // Auto-expand all matching branches when searching, otherwise respect user toggle
            let isExpanded = lowerQuery.length > 0 ? true : (expansionState[currentPath] === true);

            // Push the current node
            result.push({
                title: item.title,
                pageNum: item.pageNum,
                hasChildren: hasKids,
                level: parentPath ? parentPath.split('.').length : 0,
                path: currentPath,
                expanded: isExpanded
            });

            // If expanded and has children, recursively flatten and append them
            if (hasKids && isExpanded) {
                let childItems = getFlattenedToc(item.children, query, currentPath);
                for (let j = 0; j < childItems.length; ++j) {
                    result.push(childItems[j]);
                }
            }
        }
        return result;
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Header Title and Close Row
        RowLayout {
            width: parent.width
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

        // Table of Contents Search Bar
        TextField {
            id: searchField
            width: parent.width
            height: 36
            placeholderText: "Search bookmarks"
            leftPadding: 32
            rightPadding: 30
            verticalAlignment: TextInput.AlignVCenter
            Keys.onPressed: (event) => {
                if(event.key === Qt.Key_Home){
                    tocSidebar.reader.goToFirstPage();
                    event.accepted = true;
                }
                else if(event.key === Qt.Key_End){
                    tocSidebar.reader.goToLastPage();
                    event.accepted = true;
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

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    onClicked: {
                        searchField.text = "";
                    }
                }
            }
        }

        // Unavailable message when document has no table of contents
        Text {
            width: parent.width
            topPadding: 30
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Table Of Contents is Unavailable for this document"
            font.pixelSize: 13
            color: "#6c757d"
            visible: {
                let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                return rawToc.length === 0;
            }
        }

        // Scrollable Area handling infinite depth via flattened model
        Flickable {
            id: tocFlickable
            width: parent.width
            height: parent.height - 130
            contentWidth: width
            contentHeight: tocColumn.height
            clip: true
            visible: {
                let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                return rawToc.length > 0;
            }

            Column {
                id: tocColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: {
                        let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                        return getFlattenedToc(rawToc, searchField.text, "");
                    }

                    delegate: Item {
                        width: tocColumn.width
                        height: 32

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.pageNum !== undefined && modelData.pageNum >= 0 && tocSidebar.reader) {
                                    tocSidebar.reader.jumpToPage(modelData.pageNum);
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 6
                            // Dynamic indentation based on tree depth level (level 0 = root, level 1 = sub, level 2 = sub-sub, etc.)
                            leftPadding: 10 + (modelData.level * 16)

                            // Expand/Collapse Toggle Button
                            Text {
                                text: modelData.hasChildren ? (modelData.expanded ? "▼ " : "▶ ") : ""
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#6c757d"

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    onClicked: {
                                        if (modelData.hasChildren) {
                                            // Toggle expansion state in dictionary and force re-evaluation
                                            let newState = Object.assign({}, tocSidebar.expansionState);
                                            newState[modelData.path] = !modelData.expanded;
                                            tocSidebar.expansionState = newState;
                                        }
                                    }
                                }
                            }

                            // Title text with appropriate weight and contrast per level
                            Text {
                                text: (modelData.title !== undefined) ? modelData.title : ""
                                font.pixelSize: modelData.level === 0 ? 13 : 12
                                color: modelData.level === 0 ? "#212529" : "#343a40"
                                font.weight: modelData.level === 0 ? Font.Medium : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (75 + (modelData.level * 16))
                                elide: Text.ElideRight
                            }

                            // Page Number
                            Text {
                                text: (modelData.pageNum !== undefined && modelData.pageNum >= 0) ? modelData.pageNum : ""
                                font.pixelSize: 11
                                color: "#6c757d"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
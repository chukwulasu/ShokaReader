import QtQuick
import QtQuick.Controls
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

    function getFlattenedToc(items, query, parentPath) {
        if (!items) return [];
        let result = [];
        let lowerQuery = query ? query.toLowerCase().trim() : "";

        for (let i = 0; i < items.length; ++i) {
            let item = items[i];
            let currentPath = parentPath ? (parentPath + "." + i) : String(i);

            function hasMatch(node, q) {
                if (!q) return true;
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

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

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

        TextField {
            id: searchField
            width: parent.width
            height: 36
            placeholderText: "Search bookmarks"
            leftPadding: 32
            rightPadding: 30
            verticalAlignment: TextInput.AlignVCenter

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
            width: parent.width
            topPadding: 30
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
            width: parent.width
            height: parent.height - 130
            contentWidth: width
            contentHeight: tocColumn.height
            clip: true
            visible: {
                let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                return rawToc && rawToc.length > 0;
            }

            Column {
                id: tocColumn
                width: parent.width
                spacing: 2

                Repeater {
                    // Explicitly depend on expansionState so toggles force a re-evaluation
                    model: {
                        let _trigger = tocSidebar.expansionState;
                        let rawToc = documentManager.activeDocument ? documentManager.activeDocument.tableOfContents : [];
                        return getFlattenedToc(rawToc, searchField.text, "");
                    }

                    delegate: Rectangle {
                        id: itemRow
                        width: tocColumn.width
                        height: 32
                        color: rowHover.containsMouse ? "#eceff1" : "transparent"
                        radius: 4

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.pageNum !== undefined && modelData.pageNum > 0 && tocSidebar.reader) {
                                    tocSidebar.reader.jumpToPage(modelData.pageNum);
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8 + (modelData.level * 16)
                            anchors.rightMargin: 8
                            spacing: 6

                            // Toggle chevron button
                            Item {
                                width: 16
                                height: parent.height
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

                            // Spacer for items without children to align titles
                            Item {
                                width: 16
                                height: parent.height
                                visible: !modelData.hasChildren
                            }

                            Text {
                                text: modelData.title ? modelData.title : ""
                                font.pixelSize: modelData.level === 0 ? 13 : 12
                                color: modelData.level === 0 ? "#212529" : "#495057"
                                font.weight: modelData.level === 0 ? Font.Medium : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 50 - (modelData.level * 16)
                                elide: Text.ElideRight
                            }

                            Item { width: 1; height: 1 } // flex filler

                            Text {
                                text: (modelData.pageNum !== undefined && modelData.pageNum > 0) ? modelData.pageNum : ""
                                font.pixelSize: 11
                                color: "#868e96"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
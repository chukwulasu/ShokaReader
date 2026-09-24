import QtQuick
import QtQuick.Layouts
import ShokaReader

Rectangle {
    id: activityBar
    property var stackViewRef: null
    property var fileOpenDialogRef: null
    property bool isReaderScreenActive : stackViewRef !== null && stackViewRef.currentItem !== null && stackViewRef.currentItem.objectName === "readerView"
    Layout.preferredWidth: 50
    Layout.fillHeight: true
    color: "#181818"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        C_ToolbarButton {
            id: homeButton
            source: "qrc:/qt/qml/ShokaReader/UI/assets/images/HomeIcon.png"
            toolTipText: "Home"
            onClicked: {
                if (stackViewRef !== null) {
                    stackViewRef.clear();
                    stackViewRef.push("qrc:/qt/qml/ShokaReader/UI/UI_QML_files/Homescreen.qml");
                }
                documentManager.releaseDocument();
            }
        }

        C_ToolbarButton{
            id: lastReadButton
            source: "qrc:/qt/qml/ShokaReader/UI/assets/images/LastRead.png"
            toolTipText: "Last Read File"
        }

        C_ToolbarButton{
            id: filesButton
            source: "qrc:/qt/qml/ShokaReader/UI/assets/images/Files.png"
            shortcut: "Ctrl+O"
            onClicked: {
                if (fileOpenDialogRef !== null){
                    fileOpenDialogRef();
                }
            }
            toolTipText: "Open File (Ctrl+O)"
        }

        C_ToolbarButton{
            id: activelyReadingButton
            source: "qrc:/qt/qml/ShokaReader/UI/assets/images/ActiveReading.png"
            toolTipText: "Actively Reading"
        }

        // Spacer item to push all buttons to the top and absorb remaining space when in Homescreen
        Item{
            visible: (isReaderScreenActive === false)
            Layout.fillHeight: true
        }

        // ReaderScreen specific buttons
        ColumnLayout{
            spacing: 0
            visible: isReaderScreenActive

            C_ToolbarButton{
                id: bookMarkButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/Bookmarks.png"
                toolTipText: "Bookmarks"
            }

            C_ToolbarButton{
                id: tableOfContentsButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/Table_of_contents.png"
                toolTipText: "Table of Contents"
                onClicked: {
                    if (isReaderScreenActive === true){
                        stackViewRef.currentItem.isTableOfContentsVisible = !stackViewRef.currentItem.isTableOfContentsVisible
                    }
                }
            }

            C_ToolbarButton{
                id: searchButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/SearchIcon.png"
                toolTipText: "Search Document(Ctrl + F)"
            }

            C_ToolbarButton{
                id: zoomInButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/ZoomIn.png"
                shortcut: "Ctrl + Shift + ="
                toolTipText: "Zoom In(Ctrl + Shift + =)"
                onClicked:{
                    if (isReaderScreenActive === true){
                        stackViewRef.currentItem.zoomIn();
                    }
                }
            }

            C_ToolbarButton{
                id: zoomOutButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/ZoomOut.png"
                shortcut: "Ctrl + Shift + -"
                toolTipText: "Zoom Out(Ctrl + Shift + -)"
                onClicked:{
                    if (isReaderScreenActive === true){
                        stackViewRef.currentItem.zoomOut();
                    }
                }
            }

            C_ToolbarButton{
                id: rotateLeftButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/RotateLeft.png"
                shortcut: "Ctrl + L"
                toolTipText: "Rotate Left(Ctrl + L)"
                onClicked: {
                    if (isReaderScreenActive === true){
                        stackViewRef.currentItem.rotateLeft();
                    }
                }
            }

            C_ToolbarButton{
                id: rotateRigthButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/RotateRight.png"
                shortcut: "Ctrl + R"
                toolTipText: "Rotate Right(Ctrl + R)"
                onClicked:{
                    if (isReaderScreenActive === true){
                        stackViewRef.currentItem.rotateRight();
                    }
                }
            }

            C_ToolbarButton{
                id: ttsButton
                source: "qrc:/qt/qml/ShokaReader/UI/assets/images/TTSImage.png"
                toolTipText: "TTS"
            }

            Item{
                Layout.fillHeight: true
            }

            C_PageViewer {
                id: pageViewer
                Layout.preferredWidth: 47
                Layout.preferredHeight: 24
                reader: stackViewRef !== null ? stackViewRef.currentItem : null
            }
        }
    }
}
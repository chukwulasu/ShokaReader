import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "Custom_Items"

ApplicationWindow {
    id: root
    width: 700
    height: 800
    visible: true
    visibility: Window.Maximized
    title: (documentManager.activeDocument !== null && stackView.currentItem !== null && stackView.currentItem.objectName === "readerView")
           ? documentManager.activeDocument.title
           : "ShokaReader"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        //Global Activity Bar
        Rectangle {
            id: activityBar
            Layout.preferredWidth: 50
            Layout.fillHeight: true
            color: "#181818"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                C_ToolbarButton {
                    id: homeButton
                    source: "../../assets/images/HomeIcon.png"
                    toolTipText: "Home"
                    onClicked: {
                        stackView.clear();
                        stackView.push("Homescreen.qml");
                    }
                }

                C_ToolbarButton{
                    id:lastReadButton
                    source: "../../assets/images/LastRead.png"
                    toolTipText: "Last Read File"
                }

                C_ToolbarButton{
                    id:filesButton
                    source: "../../assets/images/Files.png"
                    shortcut: "Ctrl+O"
                    onClicked: fileOpenDialog.open()
                    toolTipText: "Open File (Ctrl+O)"
                }

                C_ToolbarButton{
                    id:activelyReadingButton
                    source: "../../assets/images/ActiveReading.png"
                    toolTipText: "Actively Reading"
                }

                C_ToolbarButton{
                    id:bookMarkButton
                    source: "../../assets/images/Bookmarks.png"
                    toolTipText: "Bookmarks"
                }

                // Spacer item to push all buttons to the top and absorb remaining space when in Homescreen
                Item{
                    visible: !(stackView.currentItem && stackView.currentItem.objectName === "readerView")
                    Layout.fillHeight: true
                }

                //ReaderScreen specific buttons
                ColumnLayout{
                    spacing: 0
                    visible: stackView.currentItem && stackView.currentItem.objectName === "readerView"

                    C_ToolbarButton{
                        id:tableOfContentsButton
                        source: "../../assets/images/Table_of_contents.png"
                        toolTipText: "Table of Contents"
                    }

                    C_ToolbarButton{
                        id:searchButton
                        source: "../../assets/images/SearchIcon.png"
                        toolTipText: "Search Document(Ctrl + F)"
                    }

                    C_ToolbarButton{
                        id:zoomInButton
                        source: "../../assets/images/ZoomIn.png"
                        toolTipText: "Zoom In"
                        onClicked:{
                            if (stackView.currentItem && typeof stackView.currentItem.zoomIn === "function")
                                stackView.currentItem.zoomIn();
                        }
                    }

                    C_ToolbarButton{
                        id:zoomOutButton
                        source: "../../assets/images/ZoomOut.png"
                        toolTipText: "Zoom Out"
                        onClicked:{
                            if (stackView.currentItem && typeof stackView.currentItem.zoomOut === "function")
                                stackView.currentItem.zoomOut();
                        }
                    }

                    C_ToolbarButton{
                        id:rotateLeftButton
                        source: "../../assets/images/RotateLeft.png"
                        toolTipText: "Rotate Left"
                        onClicked: {
                            if (stackView.currentItem && typeof stackView.currentItem.rotateLeft === "function")
                                stackView.currentItem.rotateLeft();
                        }
                    }

                    C_ToolbarButton{
                        id:rotateRigthButton
                        source: "../../assets/images/RotateRight.png"
                        toolTipText: "Rotate Right"
                        onClicked:{
                            if (stackView.currentItem && typeof stackView.currentItem.rotateRight === "function")
                                stackView.currentItem.rotateRight();
                        }
                    }

                    C_ToolbarButton{
                        id:ttsButton
                        source: "../../assets/images/TTSImage.png"
                        toolTipText: "TTS"
                    }

                    // Spacer item to push all buttons to the top and absorb remaining space when in Readerscreen
                    Item{
                        Layout.fillHeight: true
                    }

                    // Page Number Viewer
                    //TODO: come back here to finish up with pageNumber viewer, just keeping a static one for now here
                    Item {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 40

                        Text {
                            anchors.centerIn: parent
                            text: (stackView.currentItem && stackView.currentItem.currentPage !== undefined) ? stackView.currentItem.currentPage : "1"
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                }

            }
        }

        //Central Dynamic Workspace (Managed by StackView)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: true
            StackView {
                id: stackView
                anchors.fill: parent
                initialItem: Homescreen {}
            }
        }
    }

    FileDialog {
        id: fileOpenDialog
        title: "Select EPUB or PDF File"
        nameFilters: ["Documents (*.pdf *.epub)", "All Files (*.*)"]
        onAccepted: {
            console.log("Selected file: " + selectedFile);
            documentManager.openDocument(selectedFile);
        }
    }

    Connections {
        target: documentManager

        function onActiveDocumentChanged() {
            if (documentManager.activeDocument === null) return;

            console.log("[QML] Backend confirmed load success for: " + documentManager.activeDocument.source);
            stackView.clear();
            stackView.push("Readerscreen.qml");
        }

        function onErrorOccurred(errorMessage) {
            errorDialogText.text = errorMessage;
            errorDialogWindow.open();
        }
    }

    Dialog {
        id: errorDialogWindow
        title: "Loading Error"
        standardButtons: Dialog.Ok
        anchors.centerIn: parent

        contentItem: Label {
            id: errorDialogText
            text: ""
            padding: 20
        }
    }
}
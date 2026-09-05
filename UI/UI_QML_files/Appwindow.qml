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
    title: "ShokaReader"

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

                C_ToolbarButton{
                    id:lastReadButton
                    source: "../../assets/images/LastRead.png"
                }

                C_ToolbarButton{
                    id:filesButton
                    source: "../../assets/images/Files.png"
                    shortcut: "Ctrl+O"
                    onClicked: fileOpenDialog.open()
                    toolTipText: "Open File (Ctrl+O)"
                }

                C_ToolbarButton{
                    id:readingButton
                    source: "../../assets/images/Reading.png"
                }

                C_ToolbarButton{
                    id:bookMarkButton
                    source: "../../assets/images/Bookmarks.png"
                }

                // Spacer item to push all buttons to the top and absorb remaining space
                Item{
                    Layout.fillHeight: true
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

        function onFileUrlChanged() {
            if (documentManager.getFileUrl.toString() === "") return;

            console.log("[QML] Backend confirmed load success for: " + documentManager.getFileUrl);

            stackView.clear();
            stackView.push("Readerscreen.qml", {
                documentSource: documentManager.getFileUrl
            });
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
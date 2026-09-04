import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 700
    height: 800
    visible: true
    visibility: Window.Maximized
    title: "ShokaReader"

    // Master layout wrapping the persistent activity bar and the dynamic stack view
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Persistent Global Activity Bar
        Rectangle {
            id: activityBar
            Layout.preferredWidth: 50
            Layout.fillHeight: true
            color: "#181818"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.preferredWidth: 50; Layout.preferredHeight: 50
                    Image { anchors.centerIn: parent; width: 24; height: 24; source: "../assets/images/LastRead.png"; fillMode: Image.PreserveAspectFit }
                }
                Item {
                    Layout.preferredWidth: 50; Layout.preferredHeight: 50
                    Image { anchors.centerIn: parent; width: 24; height: 24; source: "../assets/images/Files.png"; fillMode: Image.PreserveAspectFit }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: fileOpenDialog.open()
                    }
                 Action {
                        shortcut: "Ctrl+O"
                        onTriggered: fileOpenDialog.open()
                    }
                }
                Item {
                    Layout.preferredWidth: 50; Layout.preferredHeight: 50
                    Image { anchors.centerIn: parent; width: 24; height: 24; source: "../assets/images/Reading.png"; fillMode: Image.PreserveAspectFit }
                }
                Item {
                    Layout.preferredWidth: 50; Layout.preferredHeight: 50
                    Image { anchors.centerIn: parent; width: 24; height: 24; source: "../assets/images/Bookmarks.png"; fillMode: Image.PreserveAspectFit }
                }

                // Pushes the bottom icon to the very end of the bar
                Item { Layout.fillHeight: true }

                // 3-Dots Menu Icon Placeholder (Ready for menu implementation later)
                Item {
                    Layout.preferredWidth: 50; Layout.preferredHeight: 50
                    Image {
                        anchors.centerIn: parent; width: 24; height: 24;
                        source: "../assets/images/ThreeDots.png"
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }
        }

        // 2. Central Dynamic Workspace (Managed by StackView)
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
            if (documentManager.fileUrl.toString() === "") return;

            console.log("[QML] Backend confirmed load success for: " + documentManager.fileUrl);

            stackView.clear();
            stackView.push("Readerscreen.qml", {
                documentSource: documentManager.fileUrl
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
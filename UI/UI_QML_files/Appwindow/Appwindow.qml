import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import ShokaReader

ApplicationWindow {
    id: root
    width: 700
    height: 800
    visible: true
    visibility: Window.Maximized
    title: (documentManager.activeDocument !== null && stackView.currentItem !== null && stackView.currentItem.objectName === "readerView")
           ? documentManager.activeDocument.title
           : "ShokaReader"

    Component.onCompleted: {
        if (documentManager.activeDocument !== null) {
            stackView.clear();
            stackView.push("qrc:/qt/qml/ShokaReader/UI/UI_QML_files/Readerscreen/Readerscreen.qml");
        }
    }

    //Entire visisible items in Applicationwindow.qml
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Global Activity Bar
        ActivityBar {
            stackViewRef: stackView
            fileOpenDialogRef: function() { fileOpenDialog.open(); }
        }

        // Central Dynamic Workspace (Managed by StackView)
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
            documentManager.openDocument(selectedFile);
        }
    }

    Connections {
        target: documentManager

        function onActiveDocumentChanged() {
            if (documentManager.activeDocument === null){
                return;
            }
            stackView.clear();
            stackView.push("qrc:/qt/qml/ShokaReader/UI/UI_QML_files/Readerscreen/Readerscreen.qml");
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
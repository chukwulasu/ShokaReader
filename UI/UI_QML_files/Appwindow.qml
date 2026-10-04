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
    title: (documentManager.activeDocument !== null && stackView.currentItem !== null
           && stackView.currentItem.objectName === "readerScreen")
           ? documentManager.activeDocument.title
           : "ShokaReader"

    Component.onCompleted: {
            if (documentManager.activeDocument !== null) {
                stackView.replace("Readerscreen.qml",StackView.Immediate);
            }
        }

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
                        if(stackView.currentItem !== null && stackView.currentItem.objectName !== "homeScreen"){
                            stackView.replace("Homescreen.qml",StackView.Immediate);
                            documentManager.releaseDocument();
                        }
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

                // Spacer item to push all buttons to the top and absorb remaining space when in Homescreen
                Item{
                    visible: !(stackView.currentItem !== null && stackView.currentItem.objectName === "readerScreen")
                    Layout.fillHeight: true
                }

                C_ToolbarButton{
                    id:searchButton
                    source: "../../assets/images/SearchIcon.png"
                    toolTipText: "Search Document(Ctrl + F)"
                    shortcut: "Ctrl+F"
                    visible: stackView.currentItem !== null && (stackView.currentItem.objectName === "readerScreen"
                             || stackView.currentItem.objectName === "activelyReading")
                    onClicked: {
                        if (stackView.currentItem !== null) {
                            if (stackView.currentItem.objectName === "readerScreen") {
                                if (stackView.currentItem.isTableOfContentsVisible) {
                                    stackView.currentItem.isTableOfContentsVisible = false;
                                }
                                stackView.currentItem.isSearchSidebarVisible = !stackView.currentItem.isSearchSidebarVisible;
                            }
                        }
                    }
                }

                //ReaderScreen specific buttons
                ColumnLayout{
                    spacing: 0
                    visible: stackView.currentItem !== null && stackView.currentItem.objectName === "readerScreen"

                    C_ToolbarButton{
                        id:bookMarkButton
                        source: "../../assets/images/Bookmarks.png"
                        toolTipText: "Bookmarks"
                    }

                    C_ToolbarButton{
                        id:tableOfContentsButton
                        source: "../../assets/images/Table_of_contents.png"
                        toolTipText: "Table of Contents"
                        onClicked: {
                            if (stackView.currentItem !== null && stackView.currentItem.objectName === "readerScreen") {
                                if (stackView.currentItem.isSearchSidebarVisible) {
                                    stackView.currentItem.isSearchSidebarVisible = false;
                                }
                                stackView.currentItem.isTableOfContentsVisible = !stackView.currentItem.isTableOfContentsVisible;
                            }
                        }
                    }

                    C_ToolbarButton{
                        id:zoomInButton
                        source: "../../assets/images/ZoomIn.png"
                        shortcut: "Ctrl + Shift + ="
                        toolTipText: "Zoom In(Ctrl + Shift + =)"
                        onClicked:{
                            if (stackView.currentItem !== null && stackView.currentItem.objectName === "readerScreen")
                                stackView.currentItem.zoomIn();
                        }
                    }

                    C_ToolbarButton{
                        id:zoomOutButton
                        source: "../../assets/images/ZoomOut.png"
                        shortcut: "Ctrl + Shift + -"
                        toolTipText: "Zoom Out(Ctrl + Shift + -)"
                        onClicked:{
                            if (stackView.currentItem !== null && stackView.currentItem.objectName === "readerScreen")
                                stackView.currentItem.zoomOut();
                        }
                    }

                    C_ToolbarButton{
                        id:rotateLeftButton
                        source: "../../assets/images/RotateLeft.png"
                        shortcut: "Ctrl + L"
                        toolTipText: "Rotate Left(Ctrl + L)"
                        onClicked: {
                            if (stackView.currentItem !== null && stackView.currentItem.objectName === "readerScreen")
                                stackView.currentItem.rotateLeft();
                        }
                    }

                    C_ToolbarButton{
                        id:rotateRightButton
                        source: "../../assets/images/RotateRight.png"
                        shortcut: "Ctrl + R"
                        toolTipText: "Rotate Right(Ctrl + R)"
                        onClicked:{
                            if (stackView.currentItem !== null && stackView.currentItem.objectName === "readerScreen")
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

                    C_PageNumberViewer {
                        id: pageViewer
                        Layout.preferredWidth: 47
                        Layout.preferredHeight: 44
                        reader: stackView.currentItem
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
            //TODO: remove console.log in final product
            console.log("Selected file: " + selectedFile);
            documentManager.openDocument(selectedFile);
        }
    }

    Connections {
        target: documentManager

        function onActiveDocumentChanged() {
            if (documentManager.activeDocument === null) return;
            //TODO: remove the console.log in final prduct
            console.log("[QML] Backend confirmed load success for: " + documentManager.activeDocument.fileUrl);
            stackView.replace("Readerscreen.qml",StackView.Immediate);
        }

        function onDocumentLocked(fileName) {
            passwordDialog.targetFileName = fileName;
            passwordDialog.errorMessage = "";
            passwordErrorTimer.stop();
            userPasswordTextField.text = "";
            ownerPasswordTextField.text = "";
            passwordDialog.open();
        }

        function onErrorOccurred(errorMessage) {
            errorDialogText.text = errorMessage;
            errorDialogWindow.open();
        }
    }

    Dialog {
        id: passwordDialog
        title: "Password Required"
        anchors.centerIn: parent
        modal: true

        property string targetFileName: ""
        property string errorMessage: ""

        function showPasswordError(msg) {
            errorMessage = msg;
            passwordErrorTimer.restart();
        }

        contentItem: ColumnLayout {
            spacing: 12

            Timer {
                id: passwordErrorTimer
                interval: 3000
                repeat: false
                onTriggered: {
                    passwordDialog.errorMessage = "";
                }
            }

            Label {
                text: "\"" + passwordDialog.targetFileName + "\" is password protected."
            }

            Label {
                text: "User Password:"
            }

            TextField {
                id: userPasswordTextField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Enter User Password"
                focus: true
                onAccepted: {
                    if (documentManager.unlockPendingDocument(userPasswordTextField.text, ownerPasswordTextField.text)) {
                        passwordDialog.close();
                    } else {
                        passwordDialog.showPasswordError("Incorrect password. Please try again.");
                    }
                }
            }

            Label {
                text: "Owner Password not necessary field to read document but needed to copy and print."
                font.bold: true
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 320
            }

            Label {
                text: "Owner Password:"
            }

            TextField {
                id: ownerPasswordTextField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Enter Owner Password"
                onAccepted: {
                    if (documentManager.unlockPendingDocument(userPasswordTextField.text, ownerPasswordTextField.text)) {
                        passwordDialog.close();
                    } else {
                        passwordDialog.showPasswordError("Incorrect password. Please try again.");
                    }
                }
            }

            Label {
                text: passwordDialog.errorMessage
                color: "#FF4D4D"
                visible: passwordDialog.errorMessage !== ""
            }
        }

        footer: RowLayout {
            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "Cancel"
                onClicked: {
                    passwordErrorTimer.stop();
                    documentManager.cancelPendingDocument();
                    passwordDialog.close();
                }
            }

            Button {
                text: "OK"
                onClicked: {
                    if (documentManager.unlockPendingDocument(userPasswordTextField.text, ownerPasswordTextField.text)) {
                        passwordDialog.close();
                    } else {
                        passwordDialog.showPasswordError("Incorrect password. Please try again.");
                    }
                }
            }
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
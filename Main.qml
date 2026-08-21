import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import PDF_reader.UI // Accesses components inside your UI subfolder

ApplicationWindow {
    id: root
    width: 1200
    height: 800
    visible: true
    visibility: Window.Maximized
    title: "YomiReader"

    // StackView manages dynamic screen transitions between Home and Reader
    StackView {
        id: stackView
        anchors.fill: parent

        // Initial view is your HomeScreen component from the UI folder
        initialItem: HomeScreen {
            // Signal handler triggered when the user clicks the folder icon
            onOpenFileRequested: {
                fileOpenDialog.open();
            }
        }
    }

    // VLC-style native file explorer dialog
    FileDialog {
        id: fileOpenDialog
        title: "Select PDF or Manga File"
        nameFilters: ["PDF Files (*.pdf)", "All Files (*.*)"]

        onAccepted: {
            console.log("Selected file path: " + selectedFile);

            // Push the ReaderScreen onto the stack view and transition screens
            stackView.push(ReaderScreen {
                onBackRequested: {
                    stackView.pop(); // Return to HomeScreen
                }
            });
        }
    }
}
import QtQuick
import QtQuick.Controls.Basic

Item {
    id: pageViewer
    property var reader: null

    TextField {
        id: pageTextField
        anchors.fill:parent
        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0

        placeholderText: (
            pageViewer.reader !== null &&
            pageViewer.reader.currentPage !== undefined
        )
        ? pageViewer.reader.currentPage.toString()
          + " / "
          + pageViewer.reader.totalPages.toString()
        : "N/A"

        placeholderTextColor: "#000000"
        color: "#000000"

        font.pixelSize: 11
        font.bold: true

        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true

        background: Rectangle {
            anchors.fill:parent
            color: "#FFFFFF"
        }

        onAccepted: {
            if (pageViewer.reader !== null) {
                let pageNum = Number(text);
                if (text !== "" && isNaN(pageNum) === false) {
                    pageViewer.reader.jumpToPage(pageNum);
                }
                text = "";
                pageViewer.reader.forceActiveFocus();
            }
        }
    }
}
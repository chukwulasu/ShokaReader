import QtQuick
import QtQuick.Controls.Basic

Item {
    id: pageViewer
    property var reader: null

    // Numerator (Editable Current Page)
    TextField {
        id: pageTextField
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 18

        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0

        placeholderText: (
            pageViewer.reader !== null &&
            pageViewer.reader.currentPage !== undefined
        )
        ? pageViewer.reader.currentPage.toString() : "N/A"

        placeholderTextColor: "#000000"
        color: "#000000"
        font.pixelSize: 11
        font.bold: true
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true

        background: Rectangle {
            radius: 2
            color: "#FFFFFF"
            anchors.fill:parent
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

    // Fraction Divider Line
    Rectangle {
        id: divider
        anchors.top: pageTextField.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 1.2
        color: "#888888"
    }

    // Denominator (Static Total Pages)
    Text {
        id: totalPagesText
        anchors.top: divider.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: (
            pageViewer.reader !== null &&
            pageViewer.reader.totalPages !== undefined &&
            pageViewer.reader.totalPages !== 0
        )
        ? pageViewer.reader.totalPages.toString() : "N/A"
        
        font.pixelSize: 11
        font.bold: true
        color: "#CCCCCC"
        horizontalAlignment: Text.AlignHCenter
    }
}
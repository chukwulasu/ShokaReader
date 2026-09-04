import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Pdf

Rectangle {
    id: readerScreen
    objectName: "readerView"
    color: "#1E1E1E"

    property url documentSource: ""

    PdfDocument {
        id: pdfDoc
        source: documentSource
    }

    // High-precision trackpad & mousewheel scrolling interceptor
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true

        onWheel: (wheel) => {
            if (wheel.angleDelta.y !== 0) {
                let sensitivityFactor = 360;
                let scrollAmount = wheel.angleDelta.y / sensitivityFactor;

                if (scrollAmount > 0) {
                    view.goToPreviousPage();
                } else {
                    view.goToNextPage();
                }
                wheel.accepted = true;
            }
        }

        PdfMultiPageView {
            id: view
            anchors.fill: parent
            document: pdfDoc
            renderScale: 1.2

            // 🌟 THE ONE-PAGE RESOLUTION FIX:
            Component.onCompleted: {
                let vBar = view.ScrollView.vertical;
                if (vBar) {
                    // 1. Disable the native incremental behavior
                    vBar.active = true;

                    // 2. Safely query the child buttons of the native ScrollBar.
                    // Built-in scrollbars render an up-arrow (decrease visual button)
                    // and a down-arrow (increase visual button) at their boundaries.
                    for (let i = 0; i < vBar.children.length; ++i) {
                        let child = vBar.children[i];

                        // Detect and intercept the Up Arrow Button
                        if (child.objectName === "decreaseVisual" || (child.text !== undefined && child.text === "▲")) {
                            child.onPressed.connect(function() {
                                view.goToPreviousPage(); // 🌟 Force EXACTLY 1 page up!
                            });
                        }

                        // Detect and intercept the Down Arrow Button
                        if (child.objectName === "increaseVisual" || (child.text !== undefined && child.text === "▼")) {
                            child.onPressed.connect(function() {
                                view.goToNextPage(); // 🌟 Force EXACTLY 1 page down!
                            });
                        }
                    }
                }
            }

            Label {
                text: "Parsing digital layout..."
                color: "white"
                visible: pdfDoc.status === PdfDocument.Loading
                anchors.centerIn: parent
            }
        }
    }

    onDocumentSourceChanged: {
        console.log("[QML Panel] Rendering engine targeting location: " + documentSource);
    }
}

import QtQuick

Image {
    id: homeScreen
    objectName: "homeScreen"
    source: "../assets/images/Homescreen.png"
    fillMode: Image.PreserveAspectCrop
    clip:true
    cache: true
    //TODO: remove later after you are done with the product, to be used to test lifecycle of stackview items
    Component.onDestruction: {
        console.log("[Lifecycle] Homescreen has been destroyed and freed from memory.");
    }
}

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QIcon>
#include <QSurfaceFormat>
#include "Libraries/DocumentManager/DocumentManager.h"
#include "Libraries/DocumentManager/DocumentPageImageProvider.h"

int main(int argc, char* argv[])
{
    // GPU logic to prevent overheating
    QSurfaceFormat format;
    format.setSwapInterval(1); // use 1 for Phones
    QSurfaceFormat::setDefaultFormat(format);

    // Rest of the code for handling the application
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/qt/qml/ShokaReader/UI/assets/images/AppIcon.png"));

    DocumentManager globalDocManager;
    QQmlApplicationEngine engine;

    // Register the document manager context property
    engine.rootContext()->setContextProperty("documentManager", &globalDocManager);

    // Register the custom image provider to bridge C++ QImage rendering to QML Image elements
    engine.addImageProvider(QStringLiteral("documentProvider"), new DocumentPageImageProvider(&globalDocManager));

    // Check if a file path was passed via command line or with Open With from file explorer)
    QStringList args = app.arguments();
    if (args.count() > 1) {
        QString filePath = args.at(1);
        QUrl fileUrl = QUrl::fromLocalFile(filePath);
        globalDocManager.openDocument(fileUrl);
    }

   const QUrl applicationQmlUrl(QStringLiteral("qrc:/qt/qml/ShokaReader/UI/UI_QML_files/Appwindow/Appwindow.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    engine.load(applicationQmlUrl);
    return app.exec();
}
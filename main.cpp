#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QIcon>

#include "Libraries/DocumentManager/DocumentManager.h"

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/qt/qml/ShokaReader/UI/assets/images/AppIcon.png"));
    DocumentManager globalDocManager;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("documentManager", &globalDocManager);
    const QUrl applicationQmlUrl(QStringLiteral("qrc:/qt/qml/ShokaReader/UI/UI_QML_files/Appwindow.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                    &app, []() { QCoreApplication::exit(-1); },
                    Qt::QueuedConnection);

    engine.load(applicationQmlUrl);
    return app.exec();
}
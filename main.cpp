#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/qt/qml/YomiReader/UI/assets/images/AppIcon.png"));
    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("YomiReader", "Appwindow");

    return QGuiApplication::exec();
}

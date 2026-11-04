#include "player.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
#include <QQuickStyle>

int main(int argc, char *argv[]) {
    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Konus");
    Player player;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("player", &player);
    engine.loadFromModule("Konus", "Main");
    if (engine.rootObjects().isEmpty()) return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (argc > 1) player.open(QUrl::fromUserInput(QString::fromLocal8Bit(argv[1])));
    const QString grab = qEnvironmentVariable("KONUS_GRAB");
    if (!grab.isEmpty()) QTimer::singleShot(3000, window, [window, grab, &app] { window->grabWindow().save(grab, "PNG"); app.exit(0); });
    return app.exec();
}

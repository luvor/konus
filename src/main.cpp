#include "player.h"
#include <QGuiApplication>
#include <QFont>
#include <QFontDatabase>
#include <QDebug>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCursor>
#include <QTimer>
#include <QQuickStyle>
#include <QQuickImageProvider>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QPainter>
#include <QSvgRenderer>

class IconProvider final : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override {
        QFile svg(":/konus/assets/icons/" + id.section('/', 0, 0) + ".svg");
        if (!svg.open(QIODevice::ReadOnly)) return {};
        const QColor tint("#" + id.section('/', 1));
        if (!tint.isValid()) return {};
        QSvgRenderer renderer(svg.readAll().replace("#9a9a9a", tint.name().toUtf8()));
        if (!renderer.isValid()) return {};
        *size = renderer.defaultSize();
        QImage image(requestedSize.isValid() ? requestedSize : *size, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        renderer.render(&painter);
        return image;
    }
};

int main(int argc, char *argv[]) {
    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Konus");
    const int regularFont = QFontDatabase::addApplicationFont(":/konus/assets/fonts/Inter-Regular.ttf");
    const int mediumFont = QFontDatabase::addApplicationFont(":/konus/assets/fonts/Inter-Medium.ttf");
    if (regularFont < 0 || mediumFont < 0) qWarning() << "Failed to load bundled Inter font; using system font";
    else QGuiApplication::setFont(QFont("Inter"));
#ifdef Q_OS_LINUX
    const QString bundledPlugins = QDir(QCoreApplication::applicationDirPath()).filePath("../lib/vlc/plugins");
    if (QFileInfo::exists(bundledPlugins)) qputenv("VLC_PLUGIN_PATH", QDir::cleanPath(bundledPlugins).toUtf8());
#endif
    Player player;
    QQmlApplicationEngine engine;
    engine.addImageProvider("icons", new IconProvider);
    engine.rootContext()->setContextProperty("player", &player);
    engine.loadFromModule("Konus", "Main");
    if (engine.rootObjects().isEmpty()) return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    const QString windowSize = qEnvironmentVariable("KONUS_WINDOW_SIZE");
    const auto dimensions = windowSize.split('x');
    if (dimensions.size() == 2) {
        bool widthOk = false, heightOk = false;
        const int width = dimensions[0].toInt(&widthOk), height = dimensions[1].toInt(&heightOk);
        if (widthOk && heightOk && width > 0 && height > 0) window->resize(width, height);
    }
    if (argc > 1) player.open(QUrl::fromUserInput(QString::fromLocal8Bit(argv[1])));
    const QString grab = qEnvironmentVariable("KONUS_GRAB");
    if (!grab.isEmpty()) QTimer::singleShot(3000, window, [window, grab, &app] {
        QMetaObject::invokeMethod(window, "reveal");
        QTimer::singleShot(200, window, [window, grab, &app] {
            if (!window->grabWindow().save(grab, "PNG")) { app.exit(2); return; }
            const QString hidden = qEnvironmentVariable("KONUS_GRAB_HIDDEN");
            if (hidden.isEmpty()) { app.exit(0); return; }
            QCursor::setPos(window->mapToGlobal(QPoint(window->width() / 2, window->height() / 2)));
            QTimer::singleShot(3000, window, [window, hidden, &app] {
                const bool saved = !window->property("showChrome").toBool() && window->grabWindow().save(hidden, "PNG");
                app.exit(saved ? 0 : 2);
            });
        });
    });
    return app.exec();
}

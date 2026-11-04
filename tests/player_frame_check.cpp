#include "../src/player.h"
#include <QCoreApplication>
#include <QDebug>
#include <QVideoFrame>
#include <QEvent>
#include <climits>
#include <cstring>
#include <thread>
#ifdef Q_OS_MACOS
#include <mach/mach.h>
#endif

struct PlayerFrameCheck {
    static quint64 rss() {
#ifdef Q_OS_MACOS
        mach_task_basic_info_data_t info{};
        mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
        if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                      reinterpret_cast<task_info_t>(&info), &count) != KERN_SUCCESS)
            qFatal("Cannot read RSS");
        return info.resident_size;
#else
        return 0; // RSS comparison is macOS-only; callback checks run everywhere.
#endif
    }
    static int run() {
        Player player;
        void *opaque = &player;
        char chroma[4];
        unsigned width = 1280, height = 720, pitch = 0, lines = 0;
        if (!Player::setup(&opaque, chroma, &width, &height, &pitch, &lines)) return 2;
        auto drop = [&] {
            void *plane = nullptr;
            void *picture = Player::lock(opaque, &plane);
            if (!plane) qFatal("Missing decode buffer");
            std::memset(plane, 0x37, size_t(pitch) * lines);
            Player::unlock(opaque, picture, &plane);
            // Force the legal dropped-picture path: no display callback.
        };
        for (int i = 0; i < 4; ++i) drop();
        const auto before = rss();
        for (int i = 0; i < 64; ++i) drop();
        const auto after = rss();
        Player::cleanup(opaque);
        qInfo().noquote() << "64 dropped 1280x720 pictures; RSS before=" << before
                          << "after=" << after << "growth=" << qint64(after) - qint64(before);
        if (after > before + 16 * 1024 * 1024) return 1;

        QVideoSink sink;
        player.attachSink(&sink);
        for (const QSize dimensions : {QSize(13, 7), QSize(640, 360), QSize(1280, 720)}) {
            opaque = &player;
            width = dimensions.width(); height = dimensions.height();
            if (!Player::setup(&opaque, chroma, &width, &height, &pitch, &lines)) return 2;
            std::thread decoder([&] {
                void *plane = nullptr;
                void *picture = Player::lock(opaque, &plane);
                if (quintptr(plane) % 32 || pitch % 32 || lines % 32 || std::memcmp(chroma, "RV32", 4))
                    qFatal("Misaligned video format");
                for (unsigned y = 0; y < height; ++y)
                    std::memset(static_cast<char *>(plane) + size_t(y) * pitch, y % 251, size_t(width) * 4);
                Player::unlock(opaque, picture, &plane);
                Player::display(opaque, picture);
                // Overwrite and display again before the GUI consumes the first copy.
                drop();
                Player::display(opaque, picture);
                Player::cleanup(opaque);
            });
            decoder.join();
            QCoreApplication::sendPostedEvents(&player, QEvent::MetaCall);
            QVideoFrame frame = sink.videoFrame();
            if (frame.size() != dimensions || frame.isMapped() || !frame.map(QVideoFrame::ReadOnly)) return 4;
            for (unsigned y = 0; y < height; ++y)
                for (unsigned x = 0; x < width * 4; ++x)
                    if (frame.bits(0)[size_t(y) * frame.bytesPerLine(0) + x] != y % 251) return 5;
            frame.unmap();
            if (player.m_framePending) return 6;
        }
        // Format instances may overlap: cleanup of the old one must not free the new one.
        void *old = &player, *next = &player;
        width = 32; height = 32;
        if (!Player::setup(&old, chroma, &width, &height, &pitch, &lines)) return 7;
        width = 64;
        if (!Player::setup(&next, chroma, &width, &height, &pitch, &lines)) return 7;
        Player::cleanup(old);
        void *plane = nullptr;
        void *picture = Player::lock(next, &plane);
        std::memset(plane, 0x55, size_t(pitch) * lines);
        Player::display(next, picture);
        Player::cleanup(next);
        QCoreApplication::sendPostedEvents(&player, QEvent::MetaCall);
        if (sink.videoFrame().size() != QSize(64, 32)) return 8;
        for (unsigned invalid : {0u, UINT_MAX}) {
            opaque = &player; width = invalid; height = 32;
            if (Player::setup(&opaque, chroma, &width, &height, &pitch, &lines)) return 9;
            width = 32; height = invalid;
            if (Player::setup(&opaque, chroma, &width, &height, &pitch, &lines)) return 9;
        }
        auto *closing = new Player;
        opaque = closing; width = height = 32;
        if (!Player::setup(&opaque, chroma, &width, &height, &pitch, &lines)) return 10;
        picture = Player::lock(opaque, &plane);
        std::memset(plane, 0, size_t(pitch) * lines);
        Player::display(opaque, picture);
        Player::cleanup(opaque);
        delete closing;
        QCoreApplication::sendPostedEvents(nullptr, QEvent::MetaCall);
        qInfo("PASS: dropped pictures, worker-to-GUI copies, aligned odd sizes, bounded queue, format replacement, invalid sizes, pending-frame teardown");
        return 0;
    }
};

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    return PlayerFrameCheck::run();
}

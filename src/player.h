#pragma once
#include <QObject>
#include <QUrl>
#include <functional>
#include <QVideoSink>
#include <vlc/vlc.h>
#include <atomic>

class Player final : public QObject {
    Q_OBJECT
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 time READ time NOTIFY positionChanged)
    Q_PROPERTY(qint64 length READ length NOTIFY positionChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY volumeChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
public:
    explicit Player(QObject *parent = nullptr);
    ~Player() override;
    Q_INVOKABLE void attachSink(QVideoSink *sink) { m_sink = sink; }
    qint64 position() const;
    qint64 time() const;
    qint64 length() const;
    int volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    bool playing() const;
    QString title() const { return m_title; }
    Q_INVOKABLE void open(const QUrl &url);
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void seek(qint64 ms);
    Q_INVOKABLE void cycleSubtitle();
    Q_INVOKABLE void cycleAudioTrack();
    void setVolume(int value);
    void setMuted(bool value);
signals:
    void positionChanged();
    void volumeChanged();
    void playingChanged();
    void titleChanged();
private:
    friend struct PlayerFrameCheck;
    static void *lock(void *, void **planes);
    static void unlock(void *, void *, void *const *planes);
    static void display(void *, void *);
    static unsigned setup(void **, char *, unsigned *, unsigned *, unsigned *, unsigned *);
    static void cleanup(void *);
    static void event(const libvlc_event_t *, void *);
    void post(const std::function<void()> &fn);
    libvlc_instance_t *m_instance{};
    libvlc_media_player_t *m_player{};
    QVideoSink *m_sink{};
    std::atomic<bool> m_framePending{false};
    int m_volume{80};
    bool m_muted{false};
    QString m_title{QStringLiteral("Konus")};
};

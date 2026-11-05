#include "player.h"
#include <QDebug>
#include <QFileInfo>
#include <QCoreApplication>
#include <QMetaObject>
#include <QVideoFrame>
#include <QVideoFrameFormat>
#include <QUrl>
#include <QtGlobal>
#include <climits>
#include <limits>
#include <new>
#include <cstdlib>
#include <cstring>

namespace {
struct VideoBuffer {
    Player *player;
    unsigned width, height, pitch;
    std::uint64_t generation;
    void *pixels;
    ~VideoBuffer() { qFreeAligned(pixels); }
};
}

Player::Player(QObject *parent) : QObject(parent) {
#ifdef Q_OS_MACOS
    const QString bundled = QCoreApplication::applicationDirPath() + "/../PlugIns/vlc";
    const QString plugins = QFileInfo::exists(bundled) ? bundled : QStringLiteral("/Applications/VLC.app/Contents/MacOS/plugins");
    qputenv("VLC_PLUGIN_PATH", plugins.toUtf8());
#endif
    const char *args[] = {"--no-video-title-show"};
    m_instance = libvlc_new(1, args);
    if (!m_instance) qWarning() << "libVLC failed to start:" << (libvlc_errmsg() ? libvlc_errmsg() : "unknown error");
    if (m_instance) {
        m_player = libvlc_media_player_new(m_instance);
        if (m_player) {
        libvlc_video_set_callbacks(m_player, lock, unlock, display, this);
        libvlc_video_set_format_callbacks(m_player, setup, cleanup);
        auto *manager = libvlc_media_player_event_manager(m_player);
        for (auto type : {libvlc_MediaPlayerPlaying, libvlc_MediaPlayerPaused, libvlc_MediaPlayerStopped,
                          libvlc_MediaPlayerTimeChanged, libvlc_MediaPlayerLengthChanged,
                          libvlc_MediaPlayerEncounteredError, libvlc_MediaPlayerEndReached, libvlc_MediaPlayerVout})
            libvlc_event_attach(manager, type, event, this);
        libvlc_audio_set_volume(m_player, m_volume);
        }
    }
}
Player::~Player() { if (m_player) { libvlc_media_player_stop(m_player); libvlc_media_player_release(m_player); } if (m_instance) libvlc_release(m_instance); }
void Player::post(const std::function<void()> &fn) { QMetaObject::invokeMethod(this, fn, Qt::QueuedConnection); }
void Player::event(const libvlc_event_t *e, void *data) {
    auto *self = static_cast<Player *>(data);
    const auto generation = self->m_generation.load();
    const int vout = e->type == libvlc_MediaPlayerVout ? e->u.media_player_vout.new_count : 0;
    self->post([self, type=e->type, generation, vout] {
        if (generation != self->m_generation.load()) return;
        if (type == libvlc_MediaPlayerVout && self->m_hasVideo != (vout > 0)) {
            self->m_hasVideo = vout > 0;
            emit self->hasVideoChanged();
        }
        if (type == libvlc_MediaPlayerPlaying) {
            if (self->m_pendingUrl.isValid()) {
                self->m_currentUrl = self->m_pendingUrl; emit self->currentUrlChanged();
                if (!self->m_pendingTitle.isEmpty() && self->m_title != self->m_pendingTitle) { self->m_title = self->m_pendingTitle; emit self->titleChanged(); }
            }
            self->m_pendingUrl.clear();
            self->m_pendingTitle.clear();
        } else if (type == libvlc_MediaPlayerEncounteredError) {
            const QString name = self->m_pendingUrl.isValid() ? self->m_pendingUrl.fileName() : self->m_currentUrl.fileName();
            self->failMedia(name);
            return;
        }
        if (type == libvlc_MediaPlayerPlaying || type == libvlc_MediaPlayerPaused || type == libvlc_MediaPlayerStopped || type == libvlc_MediaPlayerEndReached) emit self->playingChanged();
        emit self->positionChanged();
        if (type == libvlc_MediaPlayerEndReached) emit self->endReached();
    });
}
unsigned Player::setup(void **opaque, char *chroma, unsigned *w, unsigned *h, unsigned *pitches, unsigned *lines) {
    if (!*w || !*h || *w > (INT_MAX - 31u) / 4 || *h > INT_MAX - 31u) return 0;
    auto *self = static_cast<Player *>(*opaque);
    libvlc_media_t *media = self->m_player ? libvlc_media_player_get_media(self->m_player) : nullptr;
    if (media) {
        libvlc_media_track_t **tracks = nullptr;
        const unsigned count = libvlc_media_tracks_get(media, &tracks);
        for (unsigned i = 0; i < count; ++i) {
            if (tracks[i]->i_type == libvlc_track_video && tracks[i]->video && tracks[i]->video->i_sar_num && tracks[i]->video->i_sar_den) {
                const std::uint64_t scaled = std::uint64_t(*w) * tracks[i]->video->i_sar_num / tracks[i]->video->i_sar_den;
                if (scaled && scaled <= (INT_MAX - 31u) / 4) *w = unsigned(scaled);
                break;
            }
        }
        if (tracks) libvlc_media_tracks_release(tracks, count);
        libvlc_media_release(media);
    }
    const unsigned pitch = (*w * 4 + 31) & ~31u, rows = (*h + 31) & ~31u;
    if (rows > std::numeric_limits<size_t>::max() / pitch) return 0;
    void *pixels = qMallocAligned(size_t(pitch) * rows, 32);
    if (!pixels) return 0;
    auto *buffer = new (std::nothrow) VideoBuffer{self, *w, *h, pitch, self->m_generation.load(), pixels};
    if (!buffer) { qFreeAligned(pixels); return 0; }
    std::memcpy(chroma, "RV32", 4);
    *opaque = buffer;
    *pitches = pitch; *lines = rows; return 1;
}
void Player::cleanup(void *data) { delete static_cast<VideoBuffer *>(data); }
void *Player::lock(void *data, void **planes) {
    auto *buffer = static_cast<VideoBuffer *>(data);
    // libVLC 3 vmem serializes prepare/display; even a dropped picture reuses this buffer.
    *planes = buffer->pixels; return buffer;
}
void Player::unlock(void *data, void *picture, void *const *) {
    Q_UNUSED(data); Q_UNUSED(picture);
}
void Player::display(void *data, void *picture) {
    auto *buffer = static_cast<VideoBuffer *>(picture);
    auto *self = buffer->player;
    // shortcut: keep one pending GUI frame; use a bounded timestamp queue if frame-accurate output is needed.
    if (self->m_framePending.exchange(true)) return;
    // ponytail: CPU copy per frame can stutter at 4K60; upgrade to libVLC 4 output callbacks or a native surface.
    QVideoFrame frame(QVideoFrameFormat(QSize(int(buffer->width), int(buffer->height)), QVideoFrameFormat::Format_BGRX8888));
    if (!frame.map(QVideoFrame::WriteOnly)) { self->m_framePending = false; return; }
    for (unsigned y = 0; y < buffer->height; ++y)
        std::memcpy(frame.bits(0) + size_t(y) * frame.bytesPerLine(0),
                    static_cast<const char *>(buffer->pixels) + size_t(y) * buffer->pitch, size_t(buffer->width) * 4);
    frame.unmap();
    const auto generation = buffer->generation;
    self->post([self, frame, generation] { if (generation == self->m_generation.load() && self->m_sink) self->m_sink->setVideoFrame(frame); self->m_framePending = false; });
}
void Player::open(const QUrl &url) {
    if (!m_instance || !m_player || !url.isValid()) {
        emit playbackError(QStringLiteral("Can't open %1").arg(url.fileName()));
        return;
    }
    libvlc_media_t *media = url.isLocalFile() ? libvlc_media_new_path(m_instance, url.toLocalFile().toUtf8().constData()) : libvlc_media_new_location(m_instance, url.toString().toUtf8().constData());
    if (!media) {
        emit playbackError(QStringLiteral("Can't open %1").arg(url.fileName()));
        return;
    }
    const QString name = url.isLocalFile() ? QFileInfo(url.toLocalFile()).fileName() : url.fileName();
    resetMedia();
    m_pendingUrl = url;
    m_pendingTitle = name;
    emit hasMediaChanged();
    libvlc_media_player_set_media(m_player, media); libvlc_media_release(media);
    if (libvlc_media_player_play(m_player) != 0) {
        failMedia(name);
    }
}
void Player::resetMedia() {
    // stop joins the old input before callbacks can acquire the next media's generation.
    libvlc_media_player_stop(m_player);
    ++m_generation;
    libvlc_media_player_set_media(m_player, nullptr);
    m_framePending = false;
    if (m_sink) m_sink->setVideoFrame(QVideoFrame());
    m_pendingUrl.clear();
    m_pendingTitle.clear();
    m_currentUrl.clear();
    m_title = QStringLiteral("Konus");
    m_hasVideo = false;
    emit hasMediaChanged();
    emit currentUrlChanged();
    emit titleChanged();
    emit hasVideoChanged();
    emit playingChanged();
    emit positionChanged();
}
void Player::failMedia(const QString &name) {
    resetMedia();
    emit playbackError(QStringLiteral("Can't play %1").arg(name));
}
void Player::togglePause() {
    if (!m_player || (m_currentUrl.isEmpty() && m_pendingUrl.isEmpty())) return;
    const auto state = libvlc_media_player_get_state(m_player);
    if (state == libvlc_Ended || state == libvlc_Error) {
        libvlc_media_player_stop(m_player);
        libvlc_media_player_play(m_player);
    } else {
        libvlc_media_player_pause(m_player);
    }
}
void Player::seek(qint64 ms) { if (m_player && length() > 0) libvlc_media_player_set_time(m_player, qBound<qint64>(0, ms, length())); }
void Player::cycleSubtitle() {
    auto *ids = m_player ? libvlc_video_get_spu_description(m_player) : nullptr;
    const int current = m_player ? libvlc_video_get_spu(m_player) : -1;
    int next = -1;
    bool available = false;
    QString name = QStringLiteral("Subtitles off");
    for (auto *track = ids; track; track = track->p_next) {
        if (track->i_id < 0) continue;
        available = true;
        if (next == -1 && track->i_id > current) {
            next = track->i_id;
            name = QString::fromUtf8(track->psz_name);
        }
    }
    if (ids) libvlc_track_description_list_release(ids);
    if (!available) { emit subtitleChanged(QStringLiteral("No subtitles")); return; }
    libvlc_video_set_spu(m_player, next);
    emit subtitleChanged(name);
}
void Player::cycleAudioTrack() {
    auto *ids = m_player ? libvlc_audio_get_track_description(m_player) : nullptr;
    const int current = m_player ? libvlc_audio_get_track(m_player) : -1;
    int count = 0, next = -1, first = -1;
    QString name, firstName;
    for (auto *track = ids; track; track = track->p_next) {
        if (track->i_id < 0) continue;
        ++count;
        if (first == -1) { first = track->i_id; firstName = QString::fromUtf8(track->psz_name); }
        if (next == -1 && track->i_id > current) { next = track->i_id; name = QString::fromUtf8(track->psz_name); }
    }
    if (ids) libvlc_track_description_list_release(ids);
    if (count < 2) { emit audioTrackChanged(QStringLiteral("No other audio track")); return; }
    if (next == -1) { next = first; name = firstName; }
    libvlc_audio_set_track(m_player, next);
    emit audioTrackChanged(name);
}
void Player::setVolume(int v) { m_volume=qBound(0,v,100); if(m_volume>0)m_muted=false; if(m_player)libvlc_audio_set_volume(m_player,m_muted?0:m_volume); emit volumeChanged(); }
void Player::setMuted(bool v) { m_muted=v; if(m_player)libvlc_audio_set_volume(m_player,m_muted?0:m_volume); emit volumeChanged(); }
qint64 Player::time() const { return m_player?libvlc_media_player_get_time(m_player):0; }
qint64 Player::position() const { return m_player?libvlc_media_player_get_position(m_player)*length():0; }
qint64 Player::length() const { return m_player?libvlc_media_player_get_length(m_player):0; }
bool Player::playing() const { return m_player && libvlc_media_player_is_playing(m_player); }

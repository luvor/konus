#include "player.h"
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
    if (m_instance) {
        m_player = libvlc_media_player_new(m_instance);
        if (m_player) {
        libvlc_video_set_callbacks(m_player, lock, unlock, display, this);
        libvlc_video_set_format_callbacks(m_player, setup, cleanup);
        auto *manager = libvlc_media_player_event_manager(m_player);
        for (auto type : {libvlc_MediaPlayerPlaying, libvlc_MediaPlayerPaused, libvlc_MediaPlayerStopped,
                          libvlc_MediaPlayerTimeChanged, libvlc_MediaPlayerLengthChanged,
                          libvlc_MediaPlayerEncounteredError, libvlc_MediaPlayerEndReached})
            libvlc_event_attach(manager, type, event, this);
        libvlc_audio_set_volume(m_player, m_volume);
        }
    }
}
Player::~Player() { if (m_player) { libvlc_media_player_stop(m_player); libvlc_media_player_release(m_player); } if (m_instance) libvlc_release(m_instance); }
void Player::post(const std::function<void()> &fn) { QMetaObject::invokeMethod(this, fn, Qt::QueuedConnection); }
void Player::event(const libvlc_event_t *e, void *data) {
    auto *self = static_cast<Player *>(data);
    self->post([self, type=e->type] {
        if (type == libvlc_MediaPlayerPlaying) {
            if (!self->m_pendingTitle.isEmpty() && self->m_title != self->m_pendingTitle) { self->m_title = self->m_pendingTitle; emit self->titleChanged(); }
            self->m_pendingTitle.clear();
        } else if (type == libvlc_MediaPlayerEncounteredError) {
            emit self->playbackError(QStringLiteral("Can't play %1").arg(self->m_pendingTitle));
            self->m_pendingTitle.clear();
        }
        if (type == libvlc_MediaPlayerPlaying || type == libvlc_MediaPlayerPaused || type == libvlc_MediaPlayerStopped || type == libvlc_MediaPlayerEndReached) emit self->playingChanged();
        emit self->positionChanged();
    });
}
unsigned Player::setup(void **opaque, char *chroma, unsigned *w, unsigned *h, unsigned *pitches, unsigned *lines) {
    if (!*w || !*h || *w > (INT_MAX - 31u) / 4 || *h > INT_MAX - 31u) return 0;
    const unsigned pitch = (*w * 4 + 31) & ~31u, rows = (*h + 31) & ~31u;
    if (rows > std::numeric_limits<size_t>::max() / pitch) return 0;
    void *pixels = qMallocAligned(size_t(pitch) * rows, 32);
    if (!pixels) return 0;
    auto *buffer = new (std::nothrow) VideoBuffer{static_cast<Player *>(*opaque), *w, *h, pitch, pixels};
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
    Q_UNUSED(data);
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
    self->post([self, frame] { if (self->m_sink) self->m_sink->setVideoFrame(frame); self->m_framePending = false; });
}
void Player::open(const QUrl &url) {
    if (!m_instance || !m_player || !url.isValid()) {
        emit playbackError(QStringLiteral("Can't open this media"));
        return;
    }
    libvlc_media_t *media = url.isLocalFile() ? libvlc_media_new_path(m_instance, url.toLocalFile().toUtf8().constData()) : libvlc_media_new_location(m_instance, url.toString().toUtf8().constData());
    if (!media) {
        emit playbackError(QStringLiteral("Can't open %1").arg(url.fileName()));
        return;
    }
    libvlc_media_player_set_media(m_player, media); libvlc_media_release(media);
    const QString name = url.isLocalFile() ? QFileInfo(url.toLocalFile()).fileName() : url.fileName();
    if (m_currentUrl != url) { m_currentUrl = url; emit currentUrlChanged(); }
    m_pendingTitle = name;
    if (libvlc_media_player_play(m_player) != 0) {
        emit playbackError(QStringLiteral("Can't play %1").arg(name));
        m_pendingTitle.clear();
    }
}
void Player::togglePause() {
    if (!m_player) return;
    const auto state = libvlc_media_player_get_state(m_player);
    if (state == libvlc_Ended || state == libvlc_Error) {
        libvlc_media_player_stop(m_player);
        libvlc_media_player_play(m_player);
    } else {
        libvlc_media_player_pause(m_player);
    }
}
void Player::seek(qint64 ms) { if (m_player) libvlc_media_player_set_time(m_player, ms); }
void Player::cycleSubtitle() { if (!m_player) return; auto ids=libvlc_video_get_spu_description(m_player); if (!ids) return; int current=libvlc_video_get_spu(m_player), next=-1; QString name=QStringLiteral("Subtitles off"); bool selected=false; for(auto p=ids;p;p=p->p_next) { if(p->i_id>current){next=p->i_id;name=QString::fromUtf8(p->psz_name);selected=true;break;} } if(!selected) for(auto p=ids;p;p=p->p_next) if(p->i_id==-1) {name=QStringLiteral("Subtitles off");break;} libvlc_track_description_list_release(ids); libvlc_video_set_spu(m_player,next); emit subtitleChanged(name); }
void Player::cycleAudioTrack() { if (!m_player) return; auto ids=libvlc_audio_get_track_description(m_player); if(!ids)return; int current=libvlc_audio_get_track(m_player), next=-1; QString name; for(auto p=ids;p;p=p->p_next) if(p->i_id>current&&p->i_id!=-1){next=p->i_id;name=QString::fromUtf8(p->psz_name);break;} if(next==-1) for(auto p=ids;p;p=p->p_next) if(p->i_id!=-1){next=p->i_id;name=QString::fromUtf8(p->psz_name);break;} libvlc_track_description_list_release(ids); if(next!=-1){libvlc_audio_set_track(m_player,next);emit audioTrackChanged(name);} }
void Player::setVolume(int v) { m_volume=qBound(0,v,100); if(m_volume>0)m_muted=false; if(m_player)libvlc_audio_set_volume(m_player,m_muted?0:m_volume); emit volumeChanged(); }
void Player::setMuted(bool v) { m_muted=v; if(m_player)libvlc_audio_set_volume(m_player,m_muted?0:m_volume); emit volumeChanged(); }
qint64 Player::time() const { return m_player?libvlc_media_player_get_time(m_player):0; }
qint64 Player::position() const { return m_player?libvlc_media_player_get_position(m_player)*length():0; }
qint64 Player::length() const { return m_player?libvlc_media_player_get_length(m_player):0; }
bool Player::playing() const { return m_player && libvlc_media_player_is_playing(m_player); }

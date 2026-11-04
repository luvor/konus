#include "player.h"
#include <QFileInfo>
#include <QCoreApplication>
#include <QMetaObject>
#include <QVideoFrame>
#include <QVideoFrameFormat>
#include <QUrl>
#include <cstdlib>
#include <cstring>

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
        libvlc_video_set_callbacks(m_player, lock, unlock, display, this);
        libvlc_video_set_format_callbacks(m_player, setup, cleanup);
        auto *manager = libvlc_media_player_event_manager(m_player);
        for (auto type : {libvlc_MediaPlayerPlaying, libvlc_MediaPlayerPaused, libvlc_MediaPlayerStopped,
                          libvlc_MediaPlayerTimeChanged, libvlc_MediaPlayerLengthChanged})
            libvlc_event_attach(manager, type, event, this);
        libvlc_audio_set_volume(m_player, m_volume);
    }
}
Player::~Player() { if (m_player) libvlc_media_player_release(m_player); if (m_instance) libvlc_release(m_instance); }
void Player::post(const std::function<void()> &fn) { QMetaObject::invokeMethod(this, fn, Qt::QueuedConnection); }
void Player::event(const libvlc_event_t *e, void *data) {
    auto *self = static_cast<Player *>(data);
    self->post([self, type=e->type] { if (type == libvlc_MediaPlayerPlaying || type == libvlc_MediaPlayerPaused || type == libvlc_MediaPlayerStopped) emit self->playingChanged(); emit self->positionChanged(); });
}
unsigned Player::setup(void **opaque, char *chroma, unsigned *w, unsigned *h, unsigned *pitches, unsigned *lines) {
    auto *self = static_cast<Player *>(*opaque);
    std::memcpy(chroma, "RV32", 4);
    self->m_width = int(*w); self->m_height = int(*h);
    *pitches = *w * 4; *lines = *h; return 1;
}
void Player::cleanup(void *) {}
void *Player::lock(void *data, void **planes) {
    auto *self = static_cast<Player *>(data);
    // ponytail: CPU copy per frame can stutter at 4K60; upgrade to libVLC 4 output callbacks or a native surface.
    auto *frame = new QVideoFrame(QVideoFrameFormat(QSize(self->m_width.load(), self->m_height.load()), QVideoFrameFormat::Format_BGRA8888));
    if (!frame->map(QVideoFrame::WriteOnly)) { delete frame; *planes = nullptr; return nullptr; }
    *planes = frame->bits(0); return frame;
}
void Player::unlock(void *, void *, void *const *) {}
void Player::display(void *data, void *picture) {
    auto *self = static_cast<Player *>(data);
    auto *frame = static_cast<QVideoFrame *>(picture);
    self->post([self, frame] { if (self->m_sink) self->m_sink->setVideoFrame(*frame); frame->unmap(); delete frame; });
}
void Player::open(const QUrl &url) {
    if (!m_player || !url.isValid()) return;
    libvlc_media_t *media = url.isLocalFile() ? libvlc_media_new_path(m_instance, url.toLocalFile().toUtf8().constData()) : libvlc_media_new_location(m_instance, url.toString().toUtf8().constData());
    if (!media) return;
    libvlc_media_player_set_media(m_player, media); libvlc_media_release(media);
    const QString name = url.isLocalFile() ? QFileInfo(url.toLocalFile()).fileName() : url.fileName();
    if (m_title != name) { m_title = name; emit titleChanged(); }
    libvlc_media_player_play(m_player);
}
void Player::togglePause() { if (m_player) libvlc_media_player_pause(m_player); }
void Player::seek(qint64 ms) { if (m_player) libvlc_media_player_set_time(m_player, ms); }
void Player::cycleSubtitle() { if (!m_player) return; auto ids = libvlc_video_get_spu_description(m_player); if (!ids) return; int current=libvlc_video_get_spu(m_player), next=-1; for(auto p=ids;p;p=p->p_next) if(p->i_id>current){next=p->i_id;break;} libvlc_track_description_list_release(ids); libvlc_video_set_spu(m_player,next); }
void Player::cycleAudioTrack() { if (!m_player) return; auto ids=libvlc_audio_get_track_description(m_player); if(!ids)return; int current=libvlc_audio_get_track(m_player), next=-1; for(auto p=ids;p;p=p->p_next) if(p->i_id>current){next=p->i_id;break;} libvlc_track_description_list_release(ids); libvlc_audio_set_track(m_player,next); }
void Player::setVolume(int v) { m_volume=qBound(0,v,100); if(m_player)libvlc_audio_set_volume(m_player,m_muted?0:m_volume); emit volumeChanged(); }
void Player::setMuted(bool v) { m_muted=v; if(m_player)libvlc_audio_set_volume(m_player,m_muted?0:m_volume); emit volumeChanged(); }
qint64 Player::time() const { return m_player?libvlc_media_player_get_time(m_player):0; }
qint64 Player::position() const { return m_player?libvlc_media_player_get_position(m_player)*length():0; }
qint64 Player::length() const { return m_player?libvlc_media_player_get_length(m_player):0; }
bool Player::playing() const { return m_player && libvlc_media_player_is_playing(m_player); }

# Konus

Konus is an open-source desktop video player built with Qt 6 QML and libVLC 3, bringing Juxtopposed's VLC redesign concept to a working player with a media library, responsive playback controls, keyboard shortcuts, drag and drop, and subtitle/audio track selection.

![Konus screenshot](docs/screenshot.png)

## Features

- Dark player with collapsible media library and custom title bar.
- Video playback through libVLC with a Qt video output.
- Space, arrows, M, F, Escape, drag and drop, and file picker controls.
- Videos from `~/Movies`; music from `~/Music`.

## Local checks

`KONUS_GRAB=/tmp/grab.png <app> <media>` reveals the UI before capturing and exits.
Add `KONUS_GRAB_HIDDEN=/tmp/grab-hidden.png` to capture video alone after the normal
2.5-second idle timer. Keep the pointer still during this check. A failed save or
UI that remains visible at the second capture exits with code 2.

For the dropped-picture regression check, configure with `-DKONUS_BUILD_FRAME_CHECK=ON`,
build, and run `build/konus-frame-check`. It forces 64 lock/unlock pairs without display
and checks bounded RSS growth on macOS (less than 16 MiB), copied pixels, row alignment,
queued-frame limits and format changes. RSS comparison is skipped on other platforms.
No per-frame debug counter is installed in the player.

## Build

Requirements: CMake 3.21+, C++17 compiler, Qt 6.5+ (Quick, QuickControls2, Multimedia, Svg), and libVLC 3.

### macOS

Install Qt 6 and VLC, then run:

```sh
cmake -S . -B build -DCMAKE_PREFIX_PATH="$(brew --prefix qt)" -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

### Windows

Install Qt 6 using the Qt online installer and download the [VLC 3.0.23 SDK](https://download.videolan.org/pub/videolan/vlc/3.0.23/win64/vlc-3.0.23-win64.7z). Point `VLC_SDK_DIR` to its extracted `sdk` directory:

The Windows ZIP includes the MSVC runtime DLLs beside the app; extract it and run `konus.exe` with no installer needed.

```powershell
cmake -S . -B build -DVLC_SDK_DIR=C:/vlc/sdk -DCMAKE_PREFIX_PATH=C:/Qt/6.8.0/msvc2022_64
cmake --build build --config Release
```

### Linux

Install the build tools and libVLC packages on Ubuntu 24.04. The Qt packages in
Ubuntu 24.04 provide Qt 6.4.2, below Konus's Qt 6.5 minimum, so install the same
Qt 6.8.3 modules used by CI (Qt Svg ships in the base package) with `aqtinstall`:

```sh
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config python3-venv libvlc-dev libvlc5 vlc-plugin-base libgl1 libxkbcommon-x11-0 libxcb-cursor0
python3 -m venv .venv-aqt
.venv-aqt/bin/python -m pip install aqtinstall
.venv-aqt/bin/aqt install-qt linux desktop 6.8.3 linux_gcc_64 --modules qtmultimedia --outputdir "$HOME/Qt"
export CMAKE_PREFIX_PATH="$HOME/Qt/6.8.3/gcc_64"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

The build uses Qt's installed shared libraries and system libVLC plugins at
runtime; keep `libvlc5`, `vlc-plugin-base`, `libxkbcommon-x11-0`, and
`libxcb-cursor0` installed.

## Credits

Design by [Juxtopposed](https://www.figma.com/community/file/1691465999134370980), based on [I Redesigned VLC After 25 Years](https://www.youtube.com/watch?v=ERFeOgqk324), used with CC BY 4.0 attribution. Playback engine: [libVLC by VideoLAN](https://www.videolan.org/).

Icons are vendored from `@hugeicons/core-free-icons` 4.4.0 under the MIT license;
see `assets/icons/LICENSE-hugeicons.txt`. The maximize, restore and playlist assets
use Hugeicons' `Square`, `Copy01` and `ListVideo` paths respectively. The cone is original.

Inter by Rasmus Andersson is bundled under the SIL Open Font License 1.1; see
`assets/fonts/OFL.txt`.

Not affiliated with VideoLAN. VLC is a trademark of VideoLAN.

## License

Konus is licensed under the GNU General Public License, version 3 or (at your option) any later version. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for third-party notices.

## Download

Packaged builds are attached to successful GitHub Actions runs; tagged releases will be listed on the repository's Releases page.

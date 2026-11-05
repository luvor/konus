# Konus

Konus is an open-source desktop video player built with Qt 6 QML and libVLC 3, bringing Juxtopposed's VLC redesign concept to a working player with a media library, responsive playback controls, keyboard shortcuts, drag and drop, and subtitle/audio track selection.

![Konus screenshot](docs/screenshot.png)

## Download

Download a packaged build from this repository's [Releases page](../../releases).
Development builds are also attached to successful GitHub Actions runs.

- **macOS:** extract `konus-macos.zip` and open `konus.app`. The app is ad-hoc
  signed and is not notarized. On macOS 14 and earlier, right-click the app and
  choose **Open**. On macOS 15 and later, first try opening it, then use
  **System Settings → Privacy & Security → Open Anyway** if blocked
  ([Apple's instructions](https://support.apple.com/en-gb/102445)).
- **Windows:** extract `konus-windows.zip` and run `konus.exe`. The ZIP includes
  the MSVC runtime DLLs. If SmartScreen warns about an unrecognized app, choose
  **More info → Run anyway** after checking that you downloaded it from this repository.
- **Linux (x86_64):** download `konus-linux.AppImage`, run
  `chmod +x konus-linux.AppImage`, then `./konus-linux.AppImage`.
  If FUSE is unavailable, use `./konus-linux.AppImage --appimage-extract-and-run`.

## Features

- Dark player with collapsible media library and custom title bar.
- Video playback through libVLC with a Qt video output.
- Space, arrows, M, F, Escape, drag and drop, and file picker controls.
- Media library from the platform's standard Videos and Music folders.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Space | Play / pause |
| ← / → | Seek backward / forward 5 seconds |
| Shift + ← / → | Seek backward / forward 30 seconds |
| ↑ / ↓ | Raise / lower volume by 5% |
| M | Mute / unmute |
| F | Toggle fullscreen |
| Esc | Close search, or leave fullscreen |
| Ctrl + O (Windows/Linux), Cmd + O (macOS) | Open a media file |

When a library list or volume control has focus, arrow keys control that widget.

## Library folders

| Platform | Videos | Music |
| --- | --- | --- |
| macOS | `~/Movies` | `~/Music` |
| Windows | `%USERPROFILE%/Videos` | `%USERPROFILE%/Music` |
| Linux | `~/Videos` | `~/Music` |

Konus uses Qt's standard folder locations, so redirected Windows folders and
Linux XDG user-directory settings take precedence over these defaults.

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

Install Qt 6.8.3 for MSVC 2022 64-bit (including Qt Multimedia) using the Qt
online installer, and extract the [VLC 3.0.23 archive](https://download.videolan.org/pub/videolan/vlc/3.0.23/win64/vlc-3.0.23-win64.7z)
to `C:/vlc-3.0.23`. Run from a Visual Studio x64 developer shell:

```powershell
cmake -S . -B build -DVLC_SDK_DIR=C:/vlc-3.0.23/sdk -DCMAKE_PREFIX_PATH=C:/Qt/6.8.3/msvc2022_64
cmake --build build --config Release
```

### Linux

CI builds the AppImage on Ubuntu 22.04 to keep the glibc baseline older.
For a local build on Ubuntu 22.04 or 24.04, install the same Qt 6.8.3 modules
used by CI (Qt Svg ships in the base package) with `aqtinstall`:

```sh
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config python3-venv libvlc-dev libvlc5 vlc-plugin-base libgl1-mesa-dev libxkbcommon-dev libxkbcommon-x11-0 libxcb-cursor0
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

Design adapted from [Juxtopposed](https://www.figma.com/community/file/1691465999134370980), based on [I Redesigned VLC After 25 Years](https://www.youtube.com/watch?v=ERFeOgqk324), under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Changes made: implementation as a Qt/QML player, layout and interaction adaptations, and original cone artwork. Playback engine: [libVLC by VideoLAN](https://www.videolan.org/).

Icons are vendored from `@hugeicons/core-free-icons` 4.4.0 under the MIT license;
see `assets/icons/LICENSE-hugeicons.txt`. The maximize, restore and playlist assets
use Hugeicons' `Square`, `Copy01` and `ListVideo` paths respectively. The cone is original.

Inter by Rasmus Andersson is bundled under the SIL Open Font License 1.1; see
`assets/fonts/OFL.txt`.

Not affiliated with VideoLAN. VLC is a trademark of VideoLAN.

## License

Konus is licensed under the GNU General Public License, version 3 or (at your option) any later version. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for third-party notices.

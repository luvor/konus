# Источник дизайна

- Видео: [I Redesigned VLC After 25 Years — Juxtopposed](https://www.youtube.com/watch?v=ERFeOgqk324), разбор koz → `video/`
- Figma: <https://www.figma.com/community/file/1691465999134370980> (копия: `B5eYdPmibY1TgQxeQOO1np`)
- Автор разрешает: «Feel free to use the design to contribute to the VLC project directly». Атрибуция Juxtopposed обязательна.
- Скриншоты фреймов: `figma/`

## Токены (сняты со скриншотов, без inspect)
- Шрифт: Inter. Акцент: оранжевый конус ~#E8821E. Фон видео #2B2B2B, сайдбар #111, rail #1C1C1C.
- Громкость — клин-конус (жёлто-зелёный), прямоугольные кнопки с малым скруглением.
- Акцент выбирается в настройках (10 цветов), темы Dark / Light / System.

## Экраны → node-id
| Экран | node-id |
|---|---|
| Player (основной) | 187:328, 247:445, 970:2703, 970:3308, 970:3792, 970:4028, 6261:15078 |
| Player — hide UI | 3328:11554 |
| Player — Music | 4767:23726, 4778:25123 |
| Player — Light | 2425:13624 |
| Player — customize | 2107:5604, 2160:6137…8732, 6587:19923 |
| Settings (global…extensions) | 999:5047, 3046:9282, 3046:10057, 3062:11379, 3062:11911, 3062:12552, 3072:13408, 3073:14187, 3073:15375, 3073:15879, 3180:17398, 3180:17989, 6536:13908, 6536:14482, 6542:15251, 6543:15649, 6571:15958, 6571:16429, 6575:17137 |
| Onboarding ×11 | 1899:3055, 1902:3670…6770 |
| Add Subtitles | 1911:7545, 1919:8707, 1919:9278, 3336:11929 |
| Keyboard Shortcuts / Network stream / New playlist | 2437:14832 / 6216:13614 / 6259:14954 |
| Компоненты: Controls, volume, play, sidebar, Miniplayer | 491:1780, 244:184, 848:1712, 848:1996, 970:3091 |

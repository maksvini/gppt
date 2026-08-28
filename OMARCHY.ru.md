# GPPT на Omarchy / Hyprland

*English: [OMARCHY.md](OMARCHY.md)*

Альтернативный «фронтенд» для того же [`daemon/discord_ptt.py`](daemon/discord_ptt.py), которым пользуется расширение GNOME Shell (см. [README.ru.md](README.ru.md)), — для систем на **[Omarchy](https://omarchy.org/)** (Arch + Hyprland + бар на Quickshell) вместо GNOME Shell. Сам демон не меняется — он и так не зависит от GNOME, — меняется только то, как он запускается/останавливается и как виден его статус:

| GNOME | Omarchy / Hyprland |
|---|---|
| Кнопка в панели `extension.js` запускает/убивает демон | `systemd --user`-сервис (`omarchy/discord-ptt.service.template`) |
| Окно настроек `prefs.js` (GTK) | `~/.config/discord-ptt/env` (клавиша PTT) + виджет в баре (`omarchy/plugin/`) со статусом/переключателем/рестартом |
| Схема GSettings | обычный env-файл, который читает systemd-юнит |

Файлы GNOME-расширения (`extension.js`, `prefs.js`, `metadata.json`, `schemas/`) тут не трогаются и не нужны — GNOME Shell на Hyprland не запущен, так что они просто лежат неиспользуемые.

## Требования

- Omarchy (или любой Arch + Hyprland + этот бар на Quickshell).
- `python-evdev` (`omarchy pkg add python-evdev` — есть в официальном репозитории `extra`, AUR не нужен).
- `pipewire-pulse` (в Omarchy стоит по умолчанию).
- Пользователь должен быть в группе **`input`**: `groups $(whoami)` должно показывать `input`. Если нет: `sudo usermod -aG input $(whoami)`, затем перелогиниться.

## Установка

```bash
git clone git@github.com:maksvini/gppt.git ~/vimaxstudio/gppt   # или куда удобно
cd ~/vimaxstudio/gppt
git checkout omarchy-hyprland     # или main, после мержа
./omarchy/install.sh
```

Скрипт безопасно перезапускать (например, после `git pull` или переноса репозитория в другое место — юнит-файл просто перегенерируется с новым путём). Он:

1. Ставит `python-evdev`, если его нет.
2. Предупреждает, если вы не в группе `input`.
3. Генерирует звуки клика, если `sounds/*.wav` отсутствуют.
4. Пишет `~/.config/systemd/user/discord-ptt.service` с `ExecStart`, указывающим **именно на этот клон репозитория** (демон всегда запускается оттуда, куда вы его склонировали — отдельной копии для «установки» нет).
5. Пишет `~/.config/discord-ptt/env` с `PTT_KEY=58` (Caps Lock) — **только если файла ещё нет**, чтобы не затереть уже выбранную вами клавишу.
6. Ставит виджет бара в `~/.config/omarchy/plugins/<ваш-логин>.discord-ptt/` и включает его в правой секции бара.
7. `systemctl --user enable --now discord-ptt.service`.

## Смена клавиши PTT

Правьте `~/.config/discord-ptt/env`:

```
PTT_KEY=58
PTT_EXTRA_ARGS=
```

`PTT_KEY` — это **сырой evdev-код клавиши** (не GDK/XKB — таблица есть в [CLAUDE.md](CLAUDE.md) или в `EVDEV_KEY_NAMES` внутри `omarchy/plugin/Model.js`), например `58` = Caps Lock, `56` = Left Alt, `29` = Left Ctrl, `57` = Space. В `PTT_EXTRA_ARGS` можно добавить доп. флаги демона, например `--no-sound` или `-v`.

После правки примените одним из способов:

```bash
systemctl --user restart discord-ptt.service
```

или кнопкой **Restart service** в попапе виджета (клик по иконке микрофона в баре).

Захвата клавиши прямо в виджете нет (в отличие от GTK-диалога в GNOME-расширении) — в Quickshell нет готового паттерна для захвата клавиатуры в попапе, да и у демона всё равно нет live-reload (смена клавиши требует перезапуска), так что правка env-файла — пока единственный поддерживаемый способ.

## Проверка, что всё работает

```bash
systemctl --user status discord-ptt.service        # должен быть active (running)
journalctl --user -u discord-ptt.service -f         # лог самого демона
cat ~/.local/state/discord-ptt/state.json           # текущее состояние, обновляется на каждое нажатие/отпускание
```

Именно `state.json` смотрит виджет бара (через `FileView` в Quickshell — по событию, без опроса), чтобы показать иконку микрофона и статус. Ожидаемый формат:

```json
{"schema": 1, "service": "up", "holding": false, "muted": true, "keycode": 58, "sound_enabled": true, "ts": 1234567890.12}
```

В баре: клик по иконке микрофона открывает статус / переключатель вкл-выкл / кнопку рестарта. Сама иконка: тусклая = сервис не запущен, яркая mic-off = запущен и замьючен (в простое), яркая mic-on = клавиша PTT сейчас зажата.

## Удаление

```bash
./omarchy/uninstall.sh
```

Останавливает/выключает сервис и удаляет виджет бара. `~/.config/discord-ptt/env` и `~/.local/state/discord-ptt/` не трогает (удалите вручную, если нужна полная чистка).

## Файлы, добавленные в этой ветке

```
omarchy/
  install.sh                        # идемпотентный установщик
  uninstall.sh
  discord-ptt.service.template       # systemd --user юнит (пути подставляет install.sh)
  env.example                        # PTT_KEY=58 по умолчанию
  plugin/
    manifest.json.template           # id/author подставляет install.sh
    Panel.qml                        # иконка в баре + попап (статус, переключатель, рестарт)
    Service.qml                      # слежение за state-файлом + управление через systemctl
    Model.js                        # имена evdev-кодов, парсинг состояния, глифы
daemon/discord_ptt.py                # +флаг --state-file (аддитивно, опционально, no-op если не задан)
OMARCHY.md / OMARCHY.ru.md           # этот файл
```

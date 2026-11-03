# Roadwarden — PortMaster port for TrimUI Smart Pro (SpruceOS)

Port of **Roadwarden 1.1.31 (build 67621)** from the GOG Linux release to the
TrimUI Smart Pro (TSPS, 1280x720, Mali-G57) using the PortMaster Ren'Py runtime
(`renpy_8.3.4.aarch64.squashfs`).

Status: playable — picture, sound, mouse cursor, gamepad-as-mouse, on-screen
keyboard, GL4ES hardware rendering (gles2 renderer).

## What is in this repo

| Path | Purpose |
| --- | --- |
| `Roadwarden.sh` | PortMaster launcher (SpruceOS paths, ALSA env, gptokeyb target) |
| `roadwarden.gptk` | Gamepad mapping: right stick = mouse cursor, A/R2 = left click, B/L2 = right click, Start = Enter, Select = Esc |
| `port.json`, `gameinfo.xml` | PortMaster metadata |
| `game/zz_tsps_port.rpy` | Port overlay: disables Ren'Py's own joystick handling, draws the cursor (`MouseDisplayable`), adds the on-screen keyboard |
| `game/gui/port_cursor.png` | Cursor sprite (Ren'Py does not draw one in the software renderer) |
| `install.sh` | Copies the overlay into an installed game and applies the font-size patches |
| `gl4es/libGL.so.1`, `gl4es/libEGL.so.1` | GL4ES shim used by the `gles2` renderer |
| `docs/PERFORMANCE.md` | Frame-time and CPU measurements, what was tried |
| `docs/GPU_TEST.md` | How to verify the GL path and roll back to software |

Game data is **not** included.

## Build

1. Unpack the GOG Linux installer without running it (MojoSetup refuses to run
   headless):

   ```sh
   tail -n +520 roadwarden_1_1_31_67621..sh > payload.bin
   tail -c +658485 payload.bin > data.zip
   unzip -q data.zip -d zipout
   # game files: zipout/data/noarch/game/
   ```

2. Copy `zipout/data/noarch/game/` to `<ports>/roadwarden/game/`.
3. Delete every `*.rpyc` shipped with the game — the port runs Ren'Py 8 (Python 3)
   and the shipped bytecode is Python 2:
   `find roadwarden/game -name '*.rpyc' -delete`
4. Run `./install.sh <ports>/roadwarden` to install the overlay and font patches.
5. Put `Roadwarden.sh`, `roadwarden.gptk`, `port.json`, `gameinfo.xml` next to the
   `roadwarden/` folder.

The Ren'Py runtime is mounted by the launcher from PortMaster
(`PortMaster/libs/renpy_8.3.4.squashfs`).

## Port specifics

* **Input**: `config.joystick = False` — gptokeyb owns the pad and emits keyboard
  and mouse events through uinput. gptokeyb must target the process name
  `startRENPY`, not `$PORTEXEC`.
* **Cursor**: `config.mouse_displayable = MouseDisplayable("gui/port_cursor.png")`
  in the overlay, because the software renderer never shows a pointer.
* **Keyboard**: `renpy.get_screen("input")` triggers an on-screen keyboard that
  posts synthetic text events (`pygame.event.post(TEXTINPUT)`) plus
  `renpy.queue_event("input_backspace"/"input_enter")`.
* **Audio**: `SDL_AUDIODRIVER=alsa`, `AUDIODEV=hw:0,0`. Without them SDL picks a
  non-existent default PCM and the game runs silent.
* **Fonts**: the game is authored at 1920x1080 and displayed at 1280x720, so all
  text was scaled up (`install.sh` patches `gui.rpy`, `screens.rpy`, `inv.rpy`,
  `nvlchoices.rpy` and `journal_glossary_endscreen.rpy`). Sizes set by
  `renpy.register_style_preference()` win at runtime, so each one is changed in
  both places; a `size` must come after `properties gui.*_text_properties()`,
  which resets it.

## Known issues

* Cursor is not perfectly smooth: every movement step is a separate relative
  mouse event through uinput (`mouse_scale = 650`, `mouse_delay = 8` in the
  `.gptk`).
* No text input from the physical pad beyond the on-screen keyboard.

#!/bin/bash
# Installs the TSPS port overlay into an unpacked Roadwarden game folder and
# applies the font scaling. Usage: ./install.sh /path/to/roadwarden
set -euo pipefail

GAMEDIR=${1:?usage: install.sh <roadwarden port dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
G="$GAMEDIR/game"

[ -f "$G/screens.rpy" ] || { echo "no $G/screens.rpy — wrong directory?"; exit 1; }

# overlay: cursor + on-screen keyboard + joystick off
install -D -m644 "$HERE/game/zz_tsps_port.rpy" "$G/zz_tsps_port.rpy"
install -D -m644 "$HERE/game/gui/port_cursor.png" "$G/gui/port_cursor.png"

# 1920x1080 is downscaled to 1280x720, so text needs to be ~40% bigger
sed -i.bak-port -e 's/^define gui\.text_size = .*/define gui.text_size = 40/' "$G/gui.rpy"

size() { # size <style> <normal> <pixel>
  sed -i.bak-port \
    -e "s/register_style_preference(\"text\", \"normal\", style\.$1, \"size\", [0-9]*)/register_style_preference(\"text\", \"normal\", style.$1, \"size\", $2)/" \
    -e "s/register_style_preference(\"text\", \"pixel\", style\.$1, \"size\", [0-9]*)/register_style_preference(\"text\", \"pixel\", style.$1, \"size\", $3)/" \
    "$G/screens.rpy"
}

size gui_text          40 42
size say_dialogue      40 40
size button_text       38 38   # answer choices inherit this
size tooltip_text      38 40
size input_text        36 36
size nvl_button_text   35 35   # dialogue answer choices
size nvl_button2_text  35 35   # answers you cannot pick
size navigation_button_text 40 40   # in-game menu list (Return/Save/...)

# button_text_properties() runs after the block above and resets size to 48;
# this must come last of all style statements for that style
grep -q '^    size 40$' "$G/screens.rpy" || \
  sed -i.bak-port '/^    properties gui.button_text_properties("navigation_button")$/a\    size 40' "$G/screens.rpy"

# style blocks that call properties gui.*_text_properties() reset the size
grep -q '^style say_dialogue:$' "$G/screens.rpy" && \
  sed -i.bak-port '/^    properties gui.text_properties("dialogue")$/a\    size 40' "$G/screens.rpy"

# same sizes live in the style blocks, applied before the preferences
sed -i.bak-port -e 's/^    size [0-9]*$/    size 35/' "$G/nvlchoices.rpy"

# inventory: hint text 30, item tooltip 30, taller hint frame
sed -i.bak-port -e 's/text_size 28/text_size 30/g' \
  -e 's/tt.value xpos 10 size 28/tt.value xpos 10 size 30/' \
  -e 's/tt.value xpos 12 size 28/tt.value xpos 12 size 30/' \
  -e 's/(1380,130)/(1380,180)/g' "$G/inv.rpy"

# Ren'Py recompiles .rpy only when the .rpyc is missing
rm -f "$G/screens.rpyc" "$G/gui.rpyc" "$G/zz_tsps_port.rpyc" "$G/nvlchoices.rpyc" "$G/inv.rpyc"

# GPU path: gles2 renderer through gl4es, plus the launcher that wires it up
install -D -m755 "$HERE/Roadwarden.sh" "$GAMEDIR/Roadwarden.sh"
mkdir -p "$GAMEDIR/gl4es"
install -m644 "$HERE"/gl4es/libGL.so.1 "$HERE"/gl4es/libEGL.so.1 "$GAMEDIR/gl4es/"

python3 "$HERE/tools/fix-presplash.py" "$GAMEDIR" || echo "presplash fix skipped (needs Pillow)"

echo "installed into $G"

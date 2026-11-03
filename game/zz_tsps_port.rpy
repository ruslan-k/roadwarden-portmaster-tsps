# TSPS port overlay: gptokeyb owns input, software renderer needs its own cursor,
# gamepad needs an on-screen keyboard for text fields.
init -10 python:
    config.joystick = False

init python:
    import pygame_sdl2 as pygame

    def osk_text(ch):
        pygame.event.post(pygame.event.Event(pygame.TEXTINPUT, text=ch))

    def osk_key(name):
        renpy.queue_event(name)

init 100 python:
    config.mouse_displayable = MouseDisplayable("gui/port_cursor.png", 1, 1)
    config.overlay_screens.append("osk")

screen osk():
    zorder 300
    if renpy.get_screen("input"):
        frame:
            align (0.5, 1.0)
            background "#000000cc"
            padding (10, 8)
            vbox:
                spacing 4
                for row in ("1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"):
                    hbox:
                        spacing 4
                        xalign 0.5
                        for ch in row:
                            textbutton ch action Function(osk_text, ch) text_size 28
                hbox:
                    spacing 8
                    xalign 0.5
                    textbutton "Space" action Function(osk_text, " ") text_size 26
                    textbutton "Del" action Function(osk_key, "input_backspace") text_size 26
                    textbutton "OK" action Function(osk_key, "input_enter") text_size 26

# PortMaster ships renpy/config.py with gl_enable = False and without mipmap.
# Import by string so the store keeps its renpy proxy (renpy.has_screen etc.).
init -1000 python:
    _rc = __import__("renpy").config
    _rc.gl_enable = True
    _rc.mipmap = False
    del _rc

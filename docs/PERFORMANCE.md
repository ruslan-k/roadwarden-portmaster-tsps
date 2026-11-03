# Performance notes (TSPS, Roadwarden 1.1.31)

## Hardware acceleration: not available

The port uses PortMaster's `renpy_8.3.4.aarch64.squashfs` runtime. That build ships
**no GL modules at all** — `librenpython.so` has no `PyInit_gldraw`. Runtime log:

```
ModuleNotFoundError: No module named 'renpy.gl.gldraw'
Unknown renderer: gl
Unknown renderer: gles
Initializing gl2 renderer:
GL Disabled.
Initializing sw renderer:
```

So the game runs on Ren'Py's **software renderer**. Nothing in the port can change
that: enabling GL would require a runtime built with `gldraw`/`gl2draw` for
aarch64 plus an EGL context over the Mali driver.

## What the software renderer costs

* Virtual resolution 1920x1080 (`gui.init`), panel is 1280x720, so Ren'Py keeps a
  1920x1080 surface and scales it down **every frame**:
  `renpy/display/swdraw.py:864  smoothscale(self.window, self.screen.get_size(), self.screen)`
  followed by `pygame.display.flip()`.
* Measured CPU of the whole `startRENPY` process (sum of all thread ticks from
  `/proc/<pid>/task/*/stat`, 10 s window) on a nearly static scene:
  **≈68 % of one core** (device has 4 cores).
* The panel exposes exactly one mode (`1280x720`), so the render size cannot be
  lowered by changing the DRM mode.

## Tried

| Attempt | Result |
| --- | --- |
| `RENPY_RENDERER=gl/gles2` | fails, no modules in runtime |
| Nearest-neighbour instead of bilinear downscale (patched runtime, `pygame.transform.scale`) | built as a port-local squashfs, but the A/B CPU measurement was invalid — the second instance could not take the DRM master (`ERROR: Could not queue pageflip: -16`) and the numbers were identical garbage |
| `SDL_VIDEODRIVER` change | not tested yet; only `kmsdrm`/`fbcon` are plausible and both write a full 1280x720 frame |

## Open ideas (unverified)

1. **Re-author the port at 1280x720** — set `gui.init(1280, 720)` and scale every
   absolute value in `gui.rpy`/`screens.rpy` by 2/3. This removes the per-frame
   downscale entirely and lets Ren'Py redraw only damaged rectangles. Biggest
   expected win, biggest diff (the game's screens use hardcoded 1920-space pixels).
2. **Nearest-neighbour scaling**, measured properly: cheap, but 0.667 downscaling
   with NN makes the pixel art uneven.
3. **Throttle redraws**: Ren'Py has no fps cap; the software renderer redraws on
   every event/ATL tick. Throwing away redraws is not exposed by the runtime.

## Resolved: GL2 (gles2) acceleration via gl4es

The PortMaster runtime ships `renpy/config.py` with `gl_enable = False`, so GL2 aborts
with `GL Disabled.` even though `renpy.gl2.gl2draw` is compiled into `librenpython.so`.
Re-enabling it needs three things, all in this repo:

1. `game/zz_tsps_port.rpy` — `init -1000` sets `renpy.config.gl_enable = True` and
   `renpy.config.mipmap = False` (the runtime has no `mipmap` config; without it
   `gl2texture.allocate_texture` raises `AttributeError`).
   It must reach the module through `__import__("renpy").config`: assigning through the
   store proxy `config.*` raises `not a known configuration variable`, and a plain
   `import renpy` in an init block shadows the store's `renpy` proxy (breaks
   `renpy.has_screen`, `renpy.get_side_image`).
2. `Roadwarden.sh` — `RENPY_RENDERER=gles2`, `LD_LIBRARY_PATH` with `gl4es/`,
   `SDL_VIDEO_GL_DRIVER` / `SDL_VIDEO_EGL_DRIVER` pointing at the bundled libs,
   `LIBGL_ES=2`, `LIBGL_GL=21`.
3. `gl4es/libGL.so.1` + `libEGL.so.1` (ARM64, from DDLC-ARM-Linux, MIT) in the port dir.

Verified on TrimUI Smart Pro S (Mali-G57, glibc 2.31, SpruceOS):

```
Initializing gles2 renderer:
Vendor: "b'ptitSeb'"
Renderer: b'GL4ES wrapper'
Version: b'2.1 gl4es wrapper 1.1.7'
Screen sizes: virtual=(1920, 1080) physical=(1280, 720) drawable=(1280, 720)
Maximum texture size: 4096x4096
```

No `GL Disabled.`, no fallback to `Initializing sw renderer`, no pageflip errors;
the intro and scene transitions run smoothly. Rolling back is one line:
`RENPY_RENDERER=sw` in the launcher (or restore `Roadwarden.sh.bak-sw`).

Note on CPU: the software path measured ~68% of one core on a static scene; the GL
path measures ~79% because it now draws at vsync rate instead of dropping frames.
Whole-second CPU is therefore not the metric — frame pacing is, and that is what
became smooth.

Caveat: gl4es is a GL→GLES translation layer, so this is hardware accelerated but
not a native GLES2 path. Shader-heavy effects would still cost more than on a native
GL driver.

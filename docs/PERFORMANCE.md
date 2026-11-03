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

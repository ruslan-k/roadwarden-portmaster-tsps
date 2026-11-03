# Roadwarden Ren'Py 8.3.4 — GPU rendering experiment

**Status: in use — the `gles2` + GL4ES path is what the port ships.**

Everything below lives in this repo; nothing in the shared PortMaster runtime is changed:

- `Roadwarden.sh` — requests `RENPY_RENDERER=gles2`.
- `game/zz_tsps_port.rpy` — enables `config.gl_enable = True` early in initialization.
- `docs/GPU_TEST.md` — installation, diagnostics, and rollback instructions.

## Installation

1. Back up `Roadwarden.sh` and `game/zz_tsps_port.rpy` from the deployed port.
2. Extract the archive and copy the two replacement files to their corresponding paths.
3. Launch Roadwarden normally through PortMaster.
4. Inspect `log.txt` on the device:

```sh
grep -Ei 'requested renderer|Initializing .*renderer|GL Disabled|Unknown renderer|Vendor:|Renderer:|Version:|EGL|GLX|traceback' log.txt
```

Successful GPU acceleration requires the GL2/GLES2 renderer to **initialize**, show an actual Mali GL renderer, and avoid falling back to `Initializing sw renderer`. Selecting a renderer through an environment variable does not itself prove acceleration.

## Why try this first?

In Ren'Py 8.3.4, `GL2Draw.init()` prints `GL Disabled.` when `config.gl_enable` is false. The observed `Initializing gl2 renderer: GL Disabled.` message suggests `renpy.gl2.gl2draw` imported successfully. The absent *legacy* `renpy.gl.gldraw` module is not proof that the newer GL2 backend is missing.

If GPU initialization still fails, inspect the device's EGL/GLES-capable SDL2 and Mali library stack. The alternative GL4ES/Weston path may need `RENPY_RENDERER=gl2`.

## Rollback

Set `RENPY_RENDERER=sw` in the launcher environment or restore the original two files. The shared `renpy_8.3.4.squashfs` stays untouched.

## References

- [Ren'Py 8.3.4 GL2 source](https://github.com/renpy/renpy/blob/8.3.4.24120703/renpy/gl2/gl2draw.pyx)
- [Custom PortMaster runtime notes](https://github.com/nitou2504/renpy-portmaster-runtime/blob/main/RUNTIME.md)

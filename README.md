# ghosttykit

The `GhosttyKit.xcframework` and terminal resources that
[Ottam](https://github.com/ottamdev) embeds: upstream
[Ghostty](https://github.com/ghostty-org/ghostty) at a release tag plus one
small patch. This is not a fork, and it is not an official Ghostty build. For a
terminal to use, get Ghostty itself.

## Why a patch

Ottam's core owns its PTYs, so Ghostty has to render a surface without spawning
a process. Upstream has no API for that. `patches/ottam.patch` adds:

- a manual-IO surface mode, `GHOSTTY_SURFACE_IO_MANUAL`, with
  `ghostty_surface_process_output` and a write callback
- a gate so `-Di18n=false` also leaves libintl out of the static library

The manual-IO design comes from the MIT-licensed
[manaflow-ai/ghostty](https://github.com/manaflow-ai/ghostty) fork.

## What a release contains

`ottam-ghostty.tar.gz`, `arm64` macOS only:

- `GhosttyKit.xcframework`
- `resources/ghostty/themes`
- `resources/terminfo`
- `LICENSE` and `THIRD_PARTY.md`

Ghostty's shell-integration scripts are GPL and are left out, as are Sentry and
libintl.

## Building

`PIN` holds the upstream commit and the Zig version. On macOS with Xcode and
that Zig:

```bash
./build.sh
```

Pushing a `ghostty-v*` tag builds on CI and publishes the release. Tags are
`ghostty-<upstream tag>-ottam.<n>`.

`include/ghostty.h` is Ghostty's internal embedder API, so a new upstream tag
can need changes to the patch and to Ottam's Swift host.

## License

MIT, the same as Ghostty; see `LICENSE`. Linked components are listed in
`THIRD_PARTY.md`.

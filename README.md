# gst-plugins-rs-rpi

Pre-built [GStreamer Rust plugins](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs) for Linux **amd64** and **arm64** (Raspberry Pi, M1/M2 Linux, arm64 servers).

## Plugins included

- `webrtcsrc` / `webrtcsink` from `gst-plugin-webrtc`
- `whepsrc` / `whipsink` etc. from `gst-plugin-webrtchttp`

## Install

### Debian / Ubuntu (recommended)

Download the `.deb` matching your arch from the latest [release](../../releases):

```bash
sudo dpkg -i gst-plugins-rs-webrtc_<version>_amd64.deb
# or arm64:
sudo dpkg -i gst-plugins-rs-webrtc_<version>_arm64.deb
```

Plugins install to `/usr/lib/<triplet>/gstreamer-1.0/` and are auto-discovered by GStreamer — no `GST_PLUGIN_PATH` needed.

### Tarball (other distros)

```bash
tar -xzf gst-plugins-rs-<arch>.tar.gz -C /
export GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/<triplet>/
```

## Build

The CI workflow cross-compiles for every supported arch in parallel (`amd64` native, `arm64` via `aarch64-linux-gnu`) on each `v*` tag push.

Trigger a manual build via **workflow_dispatch** (optionally specifying a `gst-plugins-rs` tag or branch — defaults to `main`). Push a `vX.Y.Z` tag to auto-create a GitHub release with the tarballs and `.deb`s attached.

# gst-plugins-rs-rpi

Cross-compiled [GStreamer Rust plugins](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs) for Raspberry Pi (aarch64).

## Plugins included

- `webrtcsrc` / `webrtcsink` — WebRTC streaming
- All net plugins from gst-plugins-rs

## Usage

Download the latest release artifact and extract to your rootfs:

```bash
tar -xzf gst-plugins-rs-rpi.tar.gz -C /
export GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/
```

## Build

The CI workflow cross-compiles for `aarch64-unknown-linux-gnu` and packages the result.

Trigger a build manually via workflow_dispatch, or push a tag to create a release.

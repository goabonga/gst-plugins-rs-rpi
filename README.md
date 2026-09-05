# gst-plugins-rs-rpi

[![ci](https://github.com/goabonga/gst-plugins-rs-rpi/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/goabonga/gst-plugins-rs-rpi/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/goabonga/gst-plugins-rs-rpi.svg)](https://github.com/goabonga/gst-plugins-rs-rpi/releases/latest)
[![upstream](https://img.shields.io/badge/upstream-gst--plugins--rs-orange.svg)](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/goabonga/gst-plugins-rs-rpi/blob/main/LICENSE)

Pre-built [GStreamer Rust WebRTC plugins](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs)
for Linux **amd64** and **arm64** (Raspberry Pi 64-bit, arm64 servers, Apple
Silicon Linux VMs).

Upstream ships these elements as Rust crates and no distribution packages them
promptly, so a pipeline here compiles them on native runners for both
architectures and publishes ready-to-install packages. It tracks upstream on
its own: a daily job releases every new stable `gst-plugins-rs` version
without anyone tagging by hand.

## Elements included

From `gst-plugin-webrtc` and `gst-plugin-webrtchttp`:

| Element | Role |
| --- | --- |
| `webrtcsink` | send a pipeline to WebRTC consumers |
| `webrtcsrc` | consume a WebRTC producer as a pipeline source |
| `whipsink` / `whipclientsink` | publish over WHIP |
| `whepsrc` | consume over WHEP |

## Install

### Debian / Ubuntu / Raspberry Pi OS

Download the `.deb` matching your architecture from the
[latest release](https://github.com/goabonga/gst-plugins-rs-rpi/releases/latest):

```bash
sudo apt install ./gst-plugins-rs-webrtc_<version>-1_arm64.deb
```

The plugins land in `/usr/lib/<triplet>/gstreamer-1.0/` and GStreamer finds
them automatically — no `GST_PLUGIN_PATH` needed.

### Ubuntu, from the PPA

When the maintainer has configured Launchpad publishing (see
[Publishing targets](#publishing-targets)), every release is also uploaded to
a PPA:

```bash
sudo add-apt-repository ppa:<owner>/<ppa>
sudo apt install gst-plugins-rs-webrtc
```

### Arch Linux

Two AUR packages are published, pick one:

```bash
paru -S gst-plugins-rs-webrtc-bin   # installs the prebuilt binaries
paru -S gst-plugins-rs-webrtc       # compiles upstream locally
```

### Any distribution (tarball)

```bash
tar -xzf gst-plugins-rs-webrtc-<version>-<arch>.tar.gz -C /usr/local
export GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0
```

Every release ships a `SHA256SUMS` covering all of its assets.

## Verify

```bash
gst-inspect-1.0 webrtcsink
```

## Build it yourself

Requirements: a Rust toolchain matching the upstream MSRV (1.92 for
`gstreamer-1.28.x`), plus the GStreamer development headers:

```bash
sudo apt install pkg-config libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev \
  libglib2.0-dev libssl-dev libsoup-3.0-dev libnice-dev

scripts/build-plugins.sh --upstream-tag gstreamer-1.28.6
scripts/build-deb.sh --version 1.28.6 \
  --tarball dist/gst-plugins-rs-webrtc-1.28.6-amd64.tar.gz
```

Builds are always native; cross-compiling needs a full foreign-arch sysroot,
so CI uses one runner per architecture instead.

## Versioning and releases

Versions are not chosen here — a release is named after the upstream tag it was
built from, so upstream `gstreamer-1.28.6` is published as `v1.28.6`.

- [`upstream-watch`](.github/workflows/upstream-watch.yml) runs daily, compares
  the newest stable upstream tag (GStreamer's even-minor convention) with the
  newest release here, and calls the release pipeline when upstream moves ahead.
- [`release`](.github/workflows/release.yml) builds both architectures, checks
  the packaged plugins load with `gst-inspect-1.0`, and publishes the GitHub
  release. The tag is created by the publish step, so a failed build never
  leaves behind a tag for a release that does not exist.
- Pushing a `v*` tag or running `release` manually does the same thing for a
  specific version.

## Publishing targets

Downstream publishing is optional and gated on configuration; the pipeline
stays green with none of it set up.

| Target | Enable with | Notes |
| --- | --- | --- |
| GitHub release | always on | tarballs, `.deb`s, `SHA256SUMS` |
| Launchpad PPA | secrets `LAUNCHPAD_GPG_PRIVATE_KEY`, `LAUNCHPAD_GPG_PASSPHRASE`; variables `LAUNCHPAD_PPA` (e.g. `ppa:goabonga/gst-plugins-rs`), optional `LAUNCHPAD_SERIES` (default `noble`) | see the caveat below |
| AUR | secret `AUR_SSH_PRIVATE_KEY` | pushes `gst-plugins-rs-webrtc` and `gst-plugins-rs-webrtc-bin` |

**Launchpad caveat.** Upstream declares `rust-version = 1.92` and the newest
`rustc` in the Ubuntu archive is 1.75 (noble), so Launchpad's builders cannot
compile the plugins. The source package therefore repacks the shared objects
this pipeline built, and `debian/rules` installs the set matching the build
architecture — the reasoning and the verification steps are in
[`packaging/launchpad/debian/README.Debian`](packaging/launchpad/debian/README.Debian).
Because the binaries are linked on the CI runners, the target series must match
them; `LAUNCHPAD_SERIES` defaults to `noble` for that reason.

## Repository layout

```
scripts/      build, packaging and publishing steps, each runnable on its own
packaging/
  deb/        control template for the binary .deb
  launchpad/  Debian source package uploaded to the PPA
  aur/        PKGBUILD templates for both AUR packages
.github/      CI, release and upstream-watch workflows
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, the commit-message
convention and the lint expectations. By participating you agree to the
[Code of Conduct](CODE_OF_CONDUCT.md).

Security issues: follow the disclosure process in [SECURITY.md](SECURITY.md).

## License

The packaging in this repository is distributed under the
[MIT License](LICENSE). The plugins it builds and ships come from
[`gst-plugins-rs`](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs) and
are licensed under the MPL-2.0.

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

Packages are built **once per distribution release**, not once for all of them.
`gst-plugin-webrtc` compiles against the GStreamer headers it finds and enables
the `v1_22` feature set unconditionally, so a binary built on one release can
call symbols another does not have. Pick the package matching your system:

| Your system | GStreamer | Package suffix |
| --- | --- | --- |
| Debian 12 | 1.22 | `~bookworm1` |
| Debian 13 / Raspberry Pi OS (trixie) | 1.26 | `~trixie1` |
| Ubuntu 24.04 | 1.24 | `~noble1` |
| Ubuntu 26.04 | 1.28 | `~resolute1` |

Ubuntu 22.04 is not supported: it ships GStreamer 1.20, below the 1.22 the
plugins require.

### Debian / Ubuntu / Raspberry Pi OS

Download the `.deb` for your release and architecture from the
[latest release](https://github.com/goabonga/gst-plugins-rs-rpi/releases/latest):

```bash
sudo apt install ./gst-plugins-rs-webrtc_<version>-1~trixie1_arm64.deb
```

Install with `apt`, not `dpkg -i`: the dependencies are computed by
`dpkg-shlibdeps` against that release, and `apt` resolves them. The plugins
land in `/usr/lib/<triplet>/gstreamer-1.0/` and GStreamer finds them
automatically -- no `GST_PLUGIN_PATH` needed.

### Ubuntu, from the PPA

When the maintainer has configured Launchpad publishing (see
[Publishing targets](#publishing-targets)), the Ubuntu releases are also
uploaded to a PPA:

```bash
sudo add-apt-repository ppa:<owner>/<ppa>
sudo apt install gst-plugins-rs-webrtc
```

### Arch Linux

```bash
paru -S gst-plugins-rs-webrtc       # compiles upstream locally -- preferred
paru -S gst-plugins-rs-webrtc-bin   # repacks the Ubuntu 26.04 build
```

Prefer the from-source package: Arch is rolling, and only a local build is
guaranteed to match the GStreamer it currently ships.

### Any distribution (tarball)

```bash
tar -xzf gst-plugins-rs-webrtc-<version>-<release>-<arch>.tar.gz -C /usr/local
export GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0
```

Every release ships a `SHA256SUMS` covering all of its assets.

## Verify

```bash
gst-inspect-1.0 webrtcsink
```

## Build it yourself

The pipeline does this in a container of each target release; to reproduce one
of them locally, run the same two scripts inside that release. On a Debian 13
machine, for `trixie`:

```bash
# build-essential is an implied build dependency of dpkg-buildpackage, which
# refuses to start without it even though debian/rules compiles nothing.
sudo apt install build-essential pkg-config debhelper dpkg-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libgstreamer-plugins-bad1.0-dev libglib2.0-dev libssl-dev \
  libsoup-3.0-dev libnice-dev
# Upstream needs rustc 1.92; no distribution packages one that new, so use
# rustup rather than the apt toolchain.

scripts/build-plugins.sh --upstream-tag gstreamer-1.28.6 --codename trixie
scripts/build-deb.sh --version 1.28.6 --codename trixie \
  --tarball dist/gst-plugins-rs-webrtc-1.28.6-trixie-amd64.tar.gz
```

Or in one line, without touching your system:

```bash
docker run --rm -v "$PWD:/w" -w /w debian:trixie bash -c '...'
```

Builds are always native. Cross-compiling needs a full foreign-arch sysroot,
which every earlier iteration of this pipeline broke on, so CI uses one runner
per architecture.

## The pipeline

There is one workflow, [`pipeline.yml`](.github/workflows/pipeline.yml). It runs
daily on a cron, or by hand with the upstream tag to build. Each stage waits for
the one before it; the matrices fan out inside a stage.

| Stage | What it does |
| --- | --- |
| **version** | asks GitLab for the newest stable upstream tag and decides whether it is already released here |
| **checks** | `shellcheck`, `actionlint`, SPDX headers, packaging metadata parses |
| **build** | 4 releases x 2 architectures in parallel, each in a container of its target release: compile, `.deb`, install through `apt`, inspect the elements |
| **aur metadata** | renders both PKGBUILDs with the real checksums |
| **github release** | tarballs, `.deb`s and `SHA256SUMS` |
| **launchpad**, **aur** | only when the secrets are configured |

Building inside the target release is what makes the dependencies right:
`dh_shlibdeps` resolves them against that release's own packages. Writing them
by hand got it wrong twice -- once missing `gstreamer1.0-plugins-bad`, which
made the plugins abort on load, and once naming `libsoup`/`libnice`/`libssl`,
which the Rust crates link statically and no `.so` needs.

There is no pull-request trigger: a push is not validated, and a lint or
packaging mistake surfaces at the next cron run or manual dispatch.

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
  debian/     debian/ tree, shared by the .deb build and the PPA upload
  aur/        PKGBUILD templates for both AUR packages
.github/workflows/
  pipeline.yml            the pipeline: cron or manual
  dependabot-rewrite.yml  signs and renames Dependabot's commits
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

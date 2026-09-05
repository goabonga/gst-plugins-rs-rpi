# Contributing to gst-plugins-rs-rpi

Thanks for taking the time to contribute. This document is the short version
of how to propose a change and what the project expects in return.

## Code of Conduct

Participation in this project is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md). By contributing you agree to abide by
its terms.

## What lives here

This repository contains **no plugin source code**. It holds the build
scripts, the packaging metadata and the CI pipeline that compile upstream
[`gst-plugins-rs`](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs)
and publish `.deb`, tarball and AUR packages.

Changes to the plugins themselves belong
[upstream](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs).

## Development setup

```bash
git clone https://github.com/goabonga/gst-plugins-rs-rpi.git
cd gst-plugins-rs-rpi
```

The only hard requirements for hacking on the scripts are `bash` and
`shellcheck`. Building the plugins locally additionally needs a Rust
toolchain and the GStreamer development headers — see the `Build` section of
the [README](README.md).

## Quality gates

Before pushing, make sure your change passes the same gates the `ci` workflow
runs:

```bash
shellcheck -x scripts/*.sh scripts/lib/*.sh
actionlint
python3 scripts/add_license_header.py --path . --types sh,yml,yaml --check
```

## Commit messages

Commit messages MUST follow
[Conventional Commits](https://www.conventionalcommits.org/).

| Type | Use it for |
| --- | --- |
| `feat` | a new packaging target or pipeline capability |
| `fix` | a broken build, packaging or publishing step |
| `docs` | documentation |
| `refactor`, `test`, `chore`, `ci`, `build`, `style`, `perf` | maintenance |

Do not append `Co-Authored-By` trailers.

## Versioning and releases

Versions are **not** decided here: a release is named after the upstream
`gst-plugins-rs` tag it was built from (upstream `gstreamer-1.28.6` is
released as `v1.28.6`). The `upstream-watch` workflow polls upstream daily,
tags any new stable version and lets the release pipeline build and publish
it. Maintainers do not tag by hand — although
`workflow_dispatch` on `upstream-watch` is available to force a check.

## Reporting bugs and asking for features

Please open a GitHub issue. For security-sensitive reports, follow
[SECURITY.md](SECURITY.md) instead of the public tracker.

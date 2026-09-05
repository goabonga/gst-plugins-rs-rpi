# Security Policy

## Supported versions

`gst-plugins-rs-rpi` republishes upstream
[`gst-plugins-rs`](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs)
binaries. Only the latest release is supported; it always tracks the newest
stable upstream tag.

| Version | Supported |
| --- | --- |
| latest release | ✅ |
| older releases | ❌ |

## Reporting a vulnerability

**Please do not open a public issue.** GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
is the preferred channel:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Describe the issue with reproduction steps and a suggested mitigation.

If you cannot use GitHub's form, email **goabonga@pm.me** with the same
information. PGP encryption is available on request.

You can expect an acknowledgement within **3 business days**, a triage
assessment within **10 business days**, and a fix or written mitigation
plan before any public disclosure.

## Scope

This repository contains **no plugin source code**: it holds the build
scripts, the Debian/Arch packaging metadata and the GitHub Actions pipeline
that compile upstream `gst-plugins-rs` and publish the resulting artifacts.

In scope:

- the build, packaging and publishing scripts under `scripts/`
- the packaging metadata under `packaging/`
- the workflows under `.github/workflows/` (secret handling, supply-chain
  integrity of the published `.deb`, tarball and AUR packages)

Out of scope:

- vulnerabilities in the GStreamer plugins themselves — report those to
  [upstream](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs/-/issues)
  and let us know so a rebuild can be triggered
- vulnerabilities in the Rust crates vendored at build time — report them to
  the crate maintainers and to [RustSec](https://rustsec.org/)

Thanks for helping keep the project and its users safe.

#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Build the selected gst-plugins-rs plugins from an upstream tag and lay the
# resulting shared objects out as a relocatable tarball:
#
#   <outdir>/gst-plugins-rs-webrtc-<version>-<debarch>.tar.gz
#     lib/gstreamer-1.0/*.so
#
# The build is always native: cross-compiling GStreamer's Rust bindings needs
# a full foreign-arch sysroot, which is what every earlier iteration of this
# pipeline kept tripping over. CI runs this on a native runner per
# architecture instead.

set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git}"
PLUGINS="${PLUGINS:-gst-plugin-webrtc gst-plugin-webrtchttp}"

usage() {
    cat <<'USAGE'
Usage: build-plugins.sh --upstream-tag <tag> [options]

Options:
  --upstream-tag <tag>   Upstream git tag or branch (e.g. gstreamer-1.28.6).
  --version <version>    Package version (default: tag minus "gstreamer-").
  --workdir <dir>        Scratch directory for the checkout (default: build).
  --outdir <dir>         Where to write the tarball (default: dist).
  -h, --help             Show this help.

Environment:
  UPSTREAM_REPO          Upstream clone URL.
  PLUGINS                Space-separated cargo packages to build.
USAGE
}

UPSTREAM_TAG=""
VERSION=""
WORKDIR="build"
OUTDIR="dist"

while [ $# -gt 0 ]; do
    case "$1" in
        --upstream-tag) UPSTREAM_TAG="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --workdir) WORKDIR="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$UPSTREAM_TAG" ]; then
    echo "error: --upstream-tag is required" >&2
    usage >&2
    exit 2
fi

: "${VERSION:=${UPSTREAM_TAG#gstreamer-}}"

# Debian architecture name — the one used in every published artifact name.
if command -v dpkg-architecture >/dev/null 2>&1; then
    DEB_ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
    GNU_TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
else
    case "$(uname -m)" in
        x86_64) DEB_ARCH=amd64; GNU_TRIPLET=x86_64-linux-gnu ;;
        aarch64) DEB_ARCH=arm64; GNU_TRIPLET=aarch64-linux-gnu ;;
        *) echo "error: unsupported machine: $(uname -m)" >&2; exit 1 ;;
    esac
fi

SRCDIR="$WORKDIR/gst-plugins-rs"

echo "==> upstream tag : $UPSTREAM_TAG"
echo "==> version      : $VERSION"
echo "==> architecture : $DEB_ARCH ($GNU_TRIPLET)"
echo "==> plugins      : $PLUGINS"

rm -rf "$SRCDIR"
mkdir -p "$WORKDIR" "$OUTDIR"
git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$SRCDIR"

cargo_args=()
for plugin in $PLUGINS; do
    cargo_args+=(-p "$plugin")
done

(cd "$SRCDIR" && cargo build --release "${cargo_args[@]}")

STAGE="$WORKDIR/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/lib/gstreamer-1.0"

shopt -s nullglob
sofiles=("$SRCDIR"/target/release/*.so)
shopt -u nullglob
if [ ${#sofiles[@]} -eq 0 ]; then
    echo "error: cargo produced no shared objects in $SRCDIR/target/release" >&2
    exit 1
fi
cp "${sofiles[@]}" "$STAGE/lib/gstreamer-1.0/"
strip --strip-unneeded "$STAGE"/lib/gstreamer-1.0/*.so

TARBALL="$OUTDIR/gst-plugins-rs-webrtc-${VERSION}-${DEB_ARCH}.tar.gz"
tar -czf "$TARBALL" -C "$STAGE" lib

echo "==> built:"
for so in "$STAGE"/lib/gstreamer-1.0/*.so; do
    echo "    $(basename "$so")"
done
ls -lh "$TARBALL"

# Hand the computed values back to the caller (GitHub Actions or a shell).
if [ -n "${GITHUB_ENV:-}" ]; then
    {
        echo "PKG_VERSION=$VERSION"
        echo "DEB_ARCH=$DEB_ARCH"
        echo "GNU_TRIPLET=$GNU_TRIPLET"
        echo "TARBALL=$TARBALL"
    } >> "$GITHUB_ENV"
fi

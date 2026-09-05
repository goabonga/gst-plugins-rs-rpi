#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Turn a tarball produced by build-plugins.sh into a binary .deb that drops
# the shared objects into the multi-arch GStreamer plugin directory.
#
#   <outdir>/gst-plugins-rs-webrtc_<version>-<revision>_<debarch>.deb
#     /usr/lib/<triplet>/gstreamer-1.0/*.so

set -euo pipefail

PACKAGE="${PACKAGE:-gst-plugins-rs-webrtc}"
CONTROL_TEMPLATE="${CONTROL_TEMPLATE:-packaging/deb/control.in}"

usage() {
    cat <<'USAGE'
Usage: build-deb.sh --version <version> --tarball <path> [options]

Options:
  --version <version>    Upstream version, e.g. 1.28.6.
  --tarball <path>       Tarball from build-plugins.sh (lib/gstreamer-1.0/*.so).
  --revision <n>         Debian revision (default: 1).
  --workdir <dir>        Scratch directory (default: build).
  --outdir <dir>         Where to write the .deb (default: dist).
  -h, --help             Show this help.

Environment:
  PACKAGE                Binary package name.
  CONTROL_TEMPLATE       Path to the control template.
USAGE
}

VERSION=""
TARBALL=""
REVISION="1"
WORKDIR="build"
OUTDIR="dist"

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --tarball) TARBALL="$2"; shift 2 ;;
        --revision) REVISION="$2"; shift 2 ;;
        --workdir) WORKDIR="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$VERSION" ] || [ -z "$TARBALL" ]; then
    echo "error: --version and --tarball are required" >&2
    usage >&2
    exit 2
fi
if [ ! -f "$TARBALL" ]; then
    echo "error: no such tarball: $TARBALL" >&2
    exit 1
fi
if [ ! -f "$CONTROL_TEMPLATE" ]; then
    echo "error: no such control template: $CONTROL_TEMPLATE" >&2
    exit 1
fi

DEB_ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
GNU_TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
DEB_VERSION="${VERSION}-${REVISION}"

ROOT="$WORKDIR/deb/$DEB_ARCH"
PLUGIN_DIR="$ROOT/usr/lib/$GNU_TRIPLET/gstreamer-1.0"
DOC_DIR="$ROOT/usr/share/doc/$PACKAGE"

rm -rf "$ROOT"
mkdir -p "$ROOT/DEBIAN" "$PLUGIN_DIR" "$DOC_DIR" "$OUTDIR"

tar -xzf "$TARBALL" -C "$WORKDIR/deb" lib/gstreamer-1.0
mv "$WORKDIR"/deb/lib/gstreamer-1.0/*.so "$PLUGIN_DIR/"
rmdir "$WORKDIR/deb/lib/gstreamer-1.0" "$WORKDIR/deb/lib"

install -m 0644 LICENSE "$DOC_DIR/copyright"

INSTALLED_SIZE=$(du -sk "$ROOT/usr" | cut -f1)

sed -e "s|@PACKAGE@|$PACKAGE|g" \
    -e "s|@DEB_VERSION@|$DEB_VERSION|g" \
    -e "s|@DEB_ARCH@|$DEB_ARCH|g" \
    -e "s|@INSTALLED_SIZE@|$INSTALLED_SIZE|g" \
    -e "s|@UPSTREAM_VERSION@|$VERSION|g" \
    "$CONTROL_TEMPLATE" > "$ROOT/DEBIAN/control"

DEB="$OUTDIR/${PACKAGE}_${DEB_VERSION}_${DEB_ARCH}.deb"
dpkg-deb --build --root-owner-group "$ROOT" "$DEB"

dpkg-deb --info "$DEB"
ls -lh "$DEB"

if [ -n "${GITHUB_ENV:-}" ]; then
    echo "DEB=$DEB" >> "$GITHUB_ENV"
fi

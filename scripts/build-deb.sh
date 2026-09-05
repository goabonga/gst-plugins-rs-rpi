#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Turn a tarball from build-plugins.sh into a binary .deb for the distribution
# release this script is running on:
#
#   <outdir>/gst-plugins-rs-webrtc_<version>-<revision>~<codename>1_<arch>.deb
#     /usr/lib/<triplet>/gstreamer-1.0/*.so
#
# It goes through dpkg-buildpackage rather than dpkg-deb so that dh_shlibdeps
# computes Depends from the shared objects themselves, against the packages of
# the release being built for. Hand-written dependency lists got this wrong in
# both directions: they missed gstreamer1.0-plugins-bad, which made the plugins
# abort on load, and they named libsoup/libnice/libssl, which the Rust crates
# link statically and no .so actually needs.

set -euo pipefail

# shellcheck source=scripts/lib/debian-tree.sh
. "$(dirname "$0")/lib/debian-tree.sh"

usage() {
    cat <<'USAGE'
Usage: build-deb.sh --version <version> --codename <codename> --tarball <path>

Options:
  --version <version>    Upstream version, e.g. 1.28.6.
  --codename <codename>  Distribution release built for, e.g. trixie.
  --tarball <path>       Tarball from build-plugins.sh.
  --revision <n>         Packaging revision (default: 1).
  --workdir <dir>        Scratch directory (default: build).
  --outdir <dir>         Where to write the .deb (default: dist).
  -h, --help             Show this help.

Environment:
  DEBIAN_TEMPLATE        debian/ template directory (default: packaging/debian).
USAGE
}

VERSION=""
CODENAME=""
TARBALL=""
REVISION="1"
WORKDIR="build"
OUTDIR="dist"

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --codename) CODENAME="$2"; shift 2 ;;
        --tarball) TARBALL="$2"; shift 2 ;;
        --revision) REVISION="$2"; shift 2 ;;
        --workdir) WORKDIR="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$VERSION" ] || [ -z "$CODENAME" ] || [ -z "$TARBALL" ]; then
    echo "error: --version, --codename and --tarball are required" >&2
    usage >&2
    exit 2
fi

DEB_ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
SRCDIR="$WORKDIR/deb/$CODENAME/gst-plugins-rs-webrtc-$VERSION"

rm -rf "$SRCDIR"
mkdir -p "$SRCDIR" "$OUTDIR"

unpack_binaries "$SRCDIR" "$DEB_ARCH" "$TARBALL"
install -m 0644 LICENSE "$SRCDIR/LICENSE"
render_debian_tree "$SRCDIR" "$VERSION" "$REVISION" "$CODENAME"

echo "==> building $DEB_VERSION for $DEB_ARCH on $CODENAME"
(cd "$SRCDIR" && dpkg-buildpackage -b -us -uc)

DEB="$WORKDIR/deb/$CODENAME/gst-plugins-rs-webrtc_${DEB_VERSION}_${DEB_ARCH}.deb"
if [ ! -f "$DEB" ]; then
    echo "error: dpkg-buildpackage did not produce $DEB" >&2
    exit 1
fi
mv "$DEB" "$OUTDIR/"
DEB="$OUTDIR/$(basename "$DEB")"

# The whole point of building per release: show what shlibdeps resolved to.
dpkg-deb -f "$DEB" Package Version Architecture Depends Recommends
ls -lh "$DEB"

if [ -n "${GITHUB_ENV:-}" ]; then
    {
        echo "DEB=$DEB"
        echo "DEB_VERSION=$DEB_VERSION"
    } >> "$GITHUB_ENV"
fi

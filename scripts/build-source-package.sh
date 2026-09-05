#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Assemble the Debian source package uploaded to a Launchpad PPA.
#
# Upstream declares rust-version = 1.92 and the newest rustc in the Ubuntu
# archive is 1.75, so Launchpad cannot compile the plugins. The source package
# repacks the shared objects the pipeline built in a container of the same
# release being uploaded for:
#
#   gst-plugins-rs-webrtc_<version>.orig.tar.xz
#     binaries/<arch>/lib/gstreamer-1.0/*.so
#     LICENSE
#
# See packaging/debian/README.Debian for the full rationale.

set -euo pipefail

# shellcheck source=scripts/lib/debian-tree.sh
. "$(dirname "$0")/lib/debian-tree.sh"

PACKAGE="gst-plugins-rs-webrtc"
ARCHES="${ARCHES:-amd64 arm64}"

usage() {
    cat <<'USAGE'
Usage: build-source-package.sh --version <version> --series <series> [options]

Options:
  --version <version>   Upstream version, e.g. 1.28.6.
  --series <series>     Ubuntu series to target, e.g. noble. The binaries must
                        have been built for that same series.
  --revision <n>        Packaging revision (default: 1).
  --artifacts <dir>     Directory holding the tarballs (default: dist).
  --workdir <dir>       Scratch directory (default: build).
  --key <keyid>         GPG key to sign with (default: unsigned).
  --with-orig           Include the orig tarball in the .changes (-sa).
                        Launchpad accepts it once per version; use it for the
                        first series of a release only.
  --metadata-only       Render debian/ and stop, without building a source
                        package.
  -h, --help            Show this help.

Environment:
  ARCHES                Architectures to pull out of --artifacts.
  DEBIAN_TEMPLATE       debian/ template directory (default: packaging/debian).
USAGE
}

VERSION=""
SERIES=""
REVISION="1"
ARTIFACTS="dist"
WORKDIR="build"
KEY=""
WITH_ORIG=0
METADATA_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --series) SERIES="$2"; shift 2 ;;
        --revision) REVISION="$2"; shift 2 ;;
        --artifacts) ARTIFACTS="$2"; shift 2 ;;
        --workdir) WORKDIR="$2"; shift 2 ;;
        --key) KEY="$2"; shift 2 ;;
        --with-orig) WITH_ORIG=1; shift ;;
        --metadata-only) METADATA_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$VERSION" ] || [ -z "$SERIES" ]; then
    echo "error: --version and --series are required" >&2
    usage >&2
    exit 2
fi

OUTDIR="$WORKDIR/source/$SERIES"
SRCDIR="$OUTDIR/${PACKAGE}-${VERSION}"

rm -rf "$OUTDIR"
mkdir -p "$SRCDIR"

if [ "$METADATA_ONLY" -eq 0 ]; then
    for arch in $ARCHES; do
        unpack_binaries "$SRCDIR" "$arch" \
            "$ARTIFACTS/${PACKAGE}-${VERSION}-${SERIES}-${arch}.tar.gz"
    done
    install -m 0644 LICENSE "$SRCDIR/LICENSE"

    ORIG="$OUTDIR/${PACKAGE}_${VERSION}.orig.tar.xz"
    tar -cJf "$ORIG" -C "$OUTDIR" --exclude=debian "${PACKAGE}-${VERSION}"
    echo "==> orig tarball: $ORIG"
fi

render_debian_tree "$SRCDIR" "$VERSION" "$REVISION" "$SERIES"

echo "==> debian/ rendered in $SRCDIR"
dpkg-parsechangelog -l "$SRCDIR/debian/changelog"

if [ "$METADATA_ONLY" -eq 1 ]; then
    exit 0
fi

build_args=(-S -d)
if [ "$WITH_ORIG" -eq 1 ]; then
    build_args+=(-sa)
else
    build_args+=(-sd)
fi
if [ -n "$KEY" ]; then
    build_args+=("-k$KEY")
else
    build_args+=(-us -uc)
fi

(cd "$SRCDIR" && dpkg-buildpackage "${build_args[@]}")

CHANGES="$OUTDIR/${PACKAGE}_${DEB_VERSION}_source.changes"
if [ ! -f "$CHANGES" ]; then
    echo "error: dpkg-buildpackage did not produce $CHANGES" >&2
    exit 1
fi

echo "==> source package: $CHANGES"
if [ -n "${GITHUB_ENV:-}" ]; then
    echo "SOURCE_CHANGES=$CHANGES" >> "$GITHUB_ENV"
fi

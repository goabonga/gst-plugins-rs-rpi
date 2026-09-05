#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Assemble the Debian source package uploaded to a Launchpad PPA.
#
# Upstream declares rust-version = 1.92 and the newest rustc in the Ubuntu
# archive is 1.75, so Launchpad cannot compile the plugins. The source package
# therefore repacks the shared objects built by the release pipeline:
#
#   gst-plugins-rs-webrtc_<version>.orig.tar.xz
#     binaries/amd64/lib/gstreamer-1.0/*.so
#     binaries/arm64/lib/gstreamer-1.0/*.so
#     LICENSE
#
# and debian/rules installs the set matching the build architecture. See
# packaging/launchpad/debian/README.Debian for the full rationale.

set -euo pipefail

PACKAGE="${PACKAGE:-gst-plugins-rs-webrtc}"
DEBIAN_TEMPLATE="${DEBIAN_TEMPLATE:-packaging/launchpad/debian}"
ARCHES="${ARCHES:-amd64 arm64}"

usage() {
    cat <<'USAGE'
Usage: build-source-package.sh --version <version> --series <series> [options]

Options:
  --version <version>   Upstream version, e.g. 1.28.6.
  --series <series>     Ubuntu series to target, e.g. noble.
  --revision <n>        Debian revision (default: 1).
  --artifacts <dir>     Directory holding the release tarballs (default: dist).
  --workdir <dir>       Scratch directory (default: build).
  --key <keyid>         GPG key to sign with (default: unsigned).
  --with-orig           Include the orig tarball in the .changes (-sa).
                        Launchpad accepts it once per version; use it for the
                        first series of a release only.
  --metadata-only       Render debian/ and stop, without building a source
                        package. Used by CI to validate the packaging.
  -h, --help            Show this help.

Environment:
  PACKAGE               Source package name.
  DEBIAN_TEMPLATE       Directory holding the debian/ template.
  ARCHES                Architectures to pull out of --artifacts.
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

# `~<series>N` keeps the same upstream version orderable across series and
# below any later official package.
DEB_VERSION="${VERSION}-${REVISION}~${SERIES}1"

OUTDIR="$WORKDIR/source/$SERIES"
SRCDIR="$OUTDIR/${PACKAGE}-${VERSION}"

rm -rf "$OUTDIR"
mkdir -p "$SRCDIR"

if [ "$METADATA_ONLY" -eq 0 ]; then
    for arch in $ARCHES; do
        tarball="$ARTIFACTS/${PACKAGE}-${VERSION}-${arch}.tar.gz"
        if [ ! -f "$tarball" ]; then
            echo "error: missing artifact for $arch: $tarball" >&2
            exit 1
        fi
        mkdir -p "$SRCDIR/binaries/$arch"
        tar -xzf "$tarball" -C "$SRCDIR/binaries/$arch" lib/gstreamer-1.0
    done
    install -m 0644 LICENSE "$SRCDIR/LICENSE"

    ORIG="$OUTDIR/${PACKAGE}_${VERSION}.orig.tar.xz"
    tar -cJf "$ORIG" -C "$OUTDIR" --exclude=debian "${PACKAGE}-${VERSION}"
    echo "==> orig tarball: $ORIG"
fi

cp -r "$DEBIAN_TEMPLATE" "$SRCDIR/debian"
chmod +x "$SRCDIR/debian/rules"

cat > "$SRCDIR/debian/changelog" <<CHANGELOG
${PACKAGE} (${DEB_VERSION}) ${SERIES}; urgency=medium

  * Repack of the GStreamer Rust WebRTC plugins built from upstream tag
    gstreamer-${VERSION} by the gst-plugins-rs-rpi release pipeline.

 -- Chris <goabonga@pm.me>  $(date -R)
CHANGELOG

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

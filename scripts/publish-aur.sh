#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Render an AUR PKGBUILD from its template, regenerate .SRCINFO and push it to
# aur.archlinux.org.
#
# Must run in an Arch environment: `makepkg --printsrcinfo` is the only
# supported way to produce .SRCINFO, and the AUR rejects a package whose
# .SRCINFO does not match its PKGBUILD.

set -euo pipefail

AUR_HOST="${AUR_HOST:-aur@aur.archlinux.org}"

usage() {
    cat <<'USAGE'
Usage: publish-aur.sh --package <name> --version <version> [options]

Options:
  --package <name>     AUR package, e.g. gst-plugins-rs-webrtc-bin.
  --version <version>  Upstream version, e.g. 1.28.6.
  --pkgrel <n>         Arch package release (default: 1).
  --artifacts <dir>    Release tarballs, for the -bin checksums (default: dist).
  --workdir <dir>      Scratch directory (default: build).
  --dry-run            Render and validate, but do not push.
  -h, --help           Show this help.

Environment:
  AUR_HOST             SSH destination of the AUR (default: aur@aur.archlinux.org).
USAGE
}

PACKAGE=""
VERSION=""
PKGREL="1"
ARTIFACTS="dist"
WORKDIR="build"
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --package) PACKAGE="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --pkgrel) PKGREL="$2"; shift 2 ;;
        --artifacts) ARTIFACTS="$2"; shift 2 ;;
        --workdir) WORKDIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$PACKAGE" ] || [ -z "$VERSION" ]; then
    echo "error: --package and --version are required" >&2
    usage >&2
    exit 2
fi

TEMPLATE="packaging/aur/$PACKAGE/PKGBUILD.in"
if [ ! -f "$TEMPLATE" ]; then
    echo "error: no template for $PACKAGE at $TEMPLATE" >&2
    exit 1
fi

sha256_of_url() {
    local url="$1" dest
    dest="$WORKDIR/aur-download/$(basename "$url")"
    mkdir -p "$(dirname "$dest")"
    echo "==> fetching $url" >&2
    curl -sSfL -o "$dest" "$url"
    sha256sum "$dest" | cut -d' ' -f1
}

sha256_of_file() {
    local path="$1"
    if [ ! -f "$path" ]; then
        echo "error: missing artifact: $path" >&2
        exit 1
    fi
    sha256sum "$path" | cut -d' ' -f1
}

STAGE="$WORKDIR/aur/$PACKAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE"

# Only resolve the checksums the template actually asks for.
render=(sed -e "s|@VERSION@|$VERSION|g" -e "s|@PKGREL@|$PKGREL|g")

if grep -q '@SHA256_SRC@' "$TEMPLATE"; then
    src_url="https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs/-/archive/gstreamer-${VERSION}/gst-plugins-rs-gstreamer-${VERSION}.tar.gz"
    render+=(-e "s|@SHA256_SRC@|$(sha256_of_url "$src_url")|g")
fi
if grep -q '@SHA256_AMD64@' "$TEMPLATE"; then
    render+=(-e "s|@SHA256_AMD64@|$(sha256_of_file "$ARTIFACTS/gst-plugins-rs-webrtc-${VERSION}-amd64.tar.gz")|g")
fi
if grep -q '@SHA256_ARM64@' "$TEMPLATE"; then
    render+=(-e "s|@SHA256_ARM64@|$(sha256_of_file "$ARTIFACTS/gst-plugins-rs-webrtc-${VERSION}-arm64.tar.gz")|g")
fi

"${render[@]}" "$TEMPLATE" > "$STAGE/PKGBUILD"

if grep -q '@[A-Z0-9_]*@' "$STAGE/PKGBUILD"; then
    echo "error: unresolved placeholders left in the rendered PKGBUILD:" >&2
    grep -n '@[A-Z0-9_]*@' "$STAGE/PKGBUILD" >&2
    exit 1
fi

(cd "$STAGE" && makepkg --printsrcinfo > .SRCINFO)

echo "==> rendered $PACKAGE $VERSION-$PKGREL"
cat "$STAGE/PKGBUILD"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> dry run, not pushing"
    exit 0
fi

REPO="$WORKDIR/aur-repo/$PACKAGE"
rm -rf "$REPO"
mkdir -p "$(dirname "$REPO")"
# `accept-new` rather than a pinned host key: the AUR rotates its host keys and
# a stale pin would break every release.
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}"
git clone "ssh://$AUR_HOST/$PACKAGE.git" "$REPO"

cp "$STAGE/PKGBUILD" "$STAGE/.SRCINFO" "$REPO/"

git -C "$REPO" add PKGBUILD .SRCINFO

# `git diff` alone would miss a package published here for the first time:
# its files are untracked until they are staged.
if git -C "$REPO" diff --cached --quiet; then
    echo "==> $PACKAGE is already at $VERSION-$PKGREL, nothing to push"
    exit 0
fi

git -C "$REPO" commit -m "Update to $VERSION-$PKGREL"
git -C "$REPO" push origin HEAD:master
echo "==> pushed $PACKAGE $VERSION-$PKGREL to the AUR"

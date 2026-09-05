#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Build and upload the Debian source package to a Launchpad PPA, one upload
# per Ubuntu series. The orig tarball is identical for every series, so it is
# attached to the first upload only -- Launchpad rejects a second copy.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: publish-launchpad.sh --version <version> --ppa <ppa> [options]

Options:
  --version <version>   Upstream version, e.g. 1.28.6.
  --ppa <ppa>           Target PPA, e.g. ppa:goabonga/gst-plugins-rs.
  --series <list>       Space-separated Ubuntu series (default: noble).
  --revision <n>        Debian revision (default: 1).
  --artifacts <dir>     Directory holding the release tarballs (default: dist).
  --workdir <dir>       Scratch directory (default: build).
  --key <keyid>         GPG key to sign with (default: the only secret key).
  --dry-run             Build and sign, but do not upload.
  -h, --help            Show this help.
USAGE
}

VERSION=""
PPA=""
SERIES_LIST="noble"
REVISION="1"
ARTIFACTS="dist"
WORKDIR="build"
KEY=""
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --ppa) PPA="$2"; shift 2 ;;
        --series) SERIES_LIST="$2"; shift 2 ;;
        --revision) REVISION="$2"; shift 2 ;;
        --artifacts) ARTIFACTS="$2"; shift 2 ;;
        --workdir) WORKDIR="$2"; shift 2 ;;
        --key) KEY="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$VERSION" ] || [ -z "$PPA" ]; then
    echo "error: --version and --ppa are required" >&2
    usage >&2
    exit 2
fi

if [ -z "$KEY" ]; then
    KEY=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')
fi
if [ -z "$KEY" ]; then
    echo "error: no GPG secret key available to sign the upload" >&2
    exit 1
fi
echo "==> signing with key $KEY"

first=1
for series in $SERIES_LIST; do
    echo "==> building source package for $series"
    orig_args=()
    if [ "$first" -eq 1 ]; then
        orig_args+=(--with-orig)
        first=0
    fi

    scripts/build-source-package.sh \
        --version "$VERSION" \
        --series "$series" \
        --revision "$REVISION" \
        --artifacts "$ARTIFACTS" \
        --workdir "$WORKDIR" \
        --key "$KEY" \
        "${orig_args[@]}"

    changes="$WORKDIR/source/$series/gst-plugins-rs-webrtc_${VERSION}-${REVISION}~${series}1_source.changes"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "==> dry run, not uploading $changes"
        continue
    fi

    echo "==> uploading $changes to $PPA"
    dput --unchecked "$PPA" "$changes"
done

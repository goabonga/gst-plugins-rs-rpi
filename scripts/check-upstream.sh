#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Resolve the newest *stable* upstream gst-plugins-rs release and report
# whether this repository has already published it.
#
# GStreamer uses the odd/even minor convention: 1.27.x and 1.29.x are
# development snapshots, 1.26.x and 1.28.x are stable. Only even minors are
# considered here.
#
# Writes `latest`, `current`, `tag` and `needs_release` to $GITHUB_OUTPUT when
# running under GitHub Actions, and prints them either way.

set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git}"

usage() {
    cat <<'USAGE'
Usage: check-upstream.sh [options]

Options:
  --current <version>   Version already released here (default: newest local
                        v* git tag; empty when the repo has no release yet).
  --force               Report needs_release=true even when up to date.
  -h, --help            Show this help.

Environment:
  UPSTREAM_REPO         Upstream clone URL.
USAGE
}

CURRENT=""
CURRENT_SET=0
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --current) CURRENT="$2"; CURRENT_SET=1; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$CURRENT_SET" -eq 0 ]; then
    CURRENT=$(git tag --list 'v*' | sed 's/^v//' | sort -V | tail -n1)
fi
CURRENT="${CURRENT#v}"
# A packaging-only release is tagged v<version>-<revision>; only the upstream
# version takes part in the comparison.
CURRENT="${CURRENT%%-*}"

# `gstreamer-1.28.6` -> `1.28.6`, stable minors only, highest version wins.
LATEST=$(
    git ls-remote --tags --refs "$UPSTREAM_REPO" 'refs/tags/gstreamer-*' \
        | sed 's#.*refs/tags/gstreamer-##' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | awk -F. '$2 % 2 == 0' \
        | sort -V \
        | tail -n1
)

if [ -z "$LATEST" ]; then
    echo "error: no stable gstreamer-* tag found at $UPSTREAM_REPO" >&2
    exit 1
fi

NEEDS_RELEASE=false
if [ "$FORCE" -eq 1 ]; then
    NEEDS_RELEASE=true
elif [ -z "$CURRENT" ]; then
    NEEDS_RELEASE=true
elif [ "$CURRENT" != "$LATEST" ] \
    && [ "$(printf '%s\n%s\n' "$CURRENT" "$LATEST" | sort -V | tail -n1)" = "$LATEST" ]; then
    NEEDS_RELEASE=true
fi

echo "latest upstream stable : $LATEST"
echo "released here          : ${CURRENT:-<none>}"
echo "needs release          : $NEEDS_RELEASE"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "latest=$LATEST"
        echo "current=$CURRENT"
        echo "tag=v$LATEST"
        echo "upstream_tag=gstreamer-$LATEST"
        echo "needs_release=$NEEDS_RELEASE"
    } >> "$GITHUB_OUTPUT"
fi

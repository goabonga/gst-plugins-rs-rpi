#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Shared by build-deb.sh and build-source-package.sh: lay out the source tree
# both a binary build and a source upload need.
#
# The tree is the same in both cases -- prebuilt shared objects under
# binaries/<arch>/ plus a rendered debian/ -- because both produce the same
# package, one compiled here and one compiled by Launchpad.

# render_debian_tree <srcdir> <version> <revision> <codename>
#
# Sets DEB_VERSION to <version>-<revision>~<codename>1. The "~" sorts below a
# plain <version>-<revision>, so a package built for an older release never
# outranks the same version built for a newer one.
render_debian_tree() {
    local srcdir="$1" version="$2" revision="$3" codename="$4"
    local template="${DEBIAN_TEMPLATE:-packaging/debian}"

    if [ ! -d "$template" ]; then
        echo "error: no debian/ template at $template" >&2
        return 1
    fi

    DEB_VERSION="${version}-${revision}~${codename}1"

    rm -rf "$srcdir/debian"
    cp -r "$template" "$srcdir/debian"
    chmod +x "$srcdir/debian/rules"
    sed -i "s|@UPSTREAM_VERSION@|$version|g" "$srcdir/debian/control"

    cat > "$srcdir/debian/changelog" <<CHANGELOG
gst-plugins-rs-webrtc (${DEB_VERSION}) ${codename}; urgency=medium

  * GStreamer Rust WebRTC plugins built from upstream tag gstreamer-${version}
    by the gst-plugins-rs-rpi pipeline, against the GStreamer headers of
    ${codename}.

 -- Chris <goabonga@pm.me>  $(date -R)
CHANGELOG
}

# unpack_binaries <srcdir> <arch> <tarball>
#
# Tarballs from build-plugins.sh hold lib/gstreamer-1.0/*.so; debian/rules
# installs the set matching the build architecture.
unpack_binaries() {
    local srcdir="$1" arch="$2" tarball="$3"

    if [ ! -f "$tarball" ]; then
        echo "error: no such tarball: $tarball" >&2
        return 1
    fi

    mkdir -p "$srcdir/binaries/$arch"
    tar -xzf "$tarball" -C "$srcdir/binaries/$arch" lib/gstreamer-1.0
}

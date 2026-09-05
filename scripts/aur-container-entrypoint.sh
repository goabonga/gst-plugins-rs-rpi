#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Entry point for the Arch container that publishes to the AUR.
#
# Runs as root: installs what base-devel lacks, creates the unprivileged user
# makepkg insists on, and hands over to publish-aur.sh.
#
# Expects the repository bind-mounted at the working directory and the AUR SSH
# private key readable at $AUR_SSH_KEY (default /ssh/aur).

set -euo pipefail

: "${PACKAGE:?PACKAGE must be set}"
: "${VERSION:?VERSION must be set}"
AUR_SSH_KEY="${AUR_SSH_KEY:-/ssh/aur}"
PUBLISHER="${PUBLISHER:-publisher}"
GIT_NAME="${GIT_NAME:-Chris}"
GIT_EMAIL="${GIT_EMAIL:-goabonga@pm.me}"

pacman -Sy --noconfirm --needed git openssh

id -u "$PUBLISHER" >/dev/null 2>&1 || useradd --create-home "$PUBLISHER"
HOME_DIR=$(getent passwd "$PUBLISHER" | cut -d: -f6)
install -d -m 700 -o "$PUBLISHER" -g "$PUBLISHER" "$HOME_DIR/.ssh"
chown -R "$PUBLISHER:$PUBLISHER" .

# The key is only needed to push. Without it a --dry-run render still works,
# which is what the metadata stage uses to validate a PKGBUILD; a real publish
# fails at `git clone` with an SSH error that says exactly that.
if [ -r "$AUR_SSH_KEY" ]; then
    install -m 600 -o "$PUBLISHER" -g "$PUBLISHER" "$AUR_SSH_KEY" "$HOME_DIR/.ssh/aur"
    ssh_command="ssh -i $HOME_DIR/.ssh/aur -o StrictHostKeyChecking=accept-new"
else
    echo "note: no AUR SSH key at $AUR_SSH_KEY; only a --dry-run render can succeed"
    ssh_command="ssh -o StrictHostKeyChecking=accept-new"
fi

export PACKAGE VERSION
runuser -u "$PUBLISHER" -- env \
    GIT_SSH_COMMAND="$ssh_command" \
    GIT_AUTHOR_NAME="$GIT_NAME" \
    GIT_AUTHOR_EMAIL="$GIT_EMAIL" \
    GIT_COMMITTER_NAME="$GIT_NAME" \
    GIT_COMMITTER_EMAIL="$GIT_EMAIL" \
    scripts/publish-aur.sh --package "$PACKAGE" --version "$VERSION" "$@"

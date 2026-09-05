#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Re-author and GPG-sign a Dependabot commit, normalising its subject to
# Conventional Commits.
#
# Everything Dependabot can bump in this repository is pipeline machinery --
# pinned GitHub Actions and container images -- so nothing it touches is
# shipped to users: `ci` for workflow changes, `chore(deps)` for the rest.
#
# Run by `git rebase --exec` in dependabot-rewrite.yml.

set -euo pipefail

changed=$(git show --name-only --pretty='' HEAD)
subject=$(git log -1 --pretty=%s HEAD)
body=$(git log -1 --pretty=%b HEAD | sed '/^[Cc]o-authored-by:/d')

# Drop any leading conventional prefix Dependabot already added.
text=$(printf '%s' "$subject" | sed -E 's/^[a-z]+(\([^)]+\))?!?:[[:space:]]*//')

if printf '%s' "$changed" | grep -q '[.]github/workflows/'; then
    prefix="ci"
else
    prefix="chore(deps)"
fi

if [ -n "$body" ]; then
    new_msg=$(printf '%s: %s\n\n%s' "$prefix" "$text" "$body")
else
    new_msg=$(printf '%s: %s' "$prefix" "$text")
fi

git commit --amend --reset-author -m "$new_msg" --quiet

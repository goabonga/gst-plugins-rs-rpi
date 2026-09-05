## Description

<!-- Describe what this PR does and why. -->

## Type

<!-- Check the one that applies: -->

- [ ] `feat` - New packaging target or pipeline capability
- [ ] `fix` - Broken build, packaging or publishing step
- [ ] `docs` - Documentation
- [ ] `refactor` - Restructuring with no behaviour change
- [ ] `chore` - Maintenance
- [ ] `ci` - CI / release pipeline

## Changes

<!-- List the main changes introduced by this PR: -->

-

## Related Issues

<!-- Link related issues: Closes #123, Fixes #456 -->

## Checklist

- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] Branch is up to date with `main`
- [ ] `shellcheck -x scripts/*.sh scripts/lib/*.sh` is clean
- [ ] `actionlint` is clean
- [ ] SPDX license headers are present (`python3 scripts/add_license_header.py --path . --types sh,yml,yaml,py --check`)
- [ ] No `Co-Authored-By` trailer in commit messages

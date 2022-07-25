#!/bin/bash

set -eu

latest_version=$(gh release list -L 1 | cut -f1)
patch_version=$(echo $latest_version | sed 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/')
new_patch_version=$((patch_version+1))
new_version=$(echo $latest_version | sed "s/v\([0-9]*\)\.\([0-9]*\)\..*/v\1.\2.$new_patch_version/")
echo "latest_version: $latest_version, new_version: $new_version"
git tag -a $new_version -m "release"
git push origin --tag
gh release create $new_version --generate-notes
gh release view $new_version --json body -q .body > release.md

echo "## Contents" >> release.md
for f in docs/content/docs/*/index.md; do grep -e '## \[[0-9]' $f | sed 's/##/-/g';done >> release.md
gh release edit $new_version --notes-file release.md

#!/usr/bin/env bash
set -euo pipefail

tag=${1:?usage: publish-package.sh TAG CODENAME DEB}
codename=${2:?usage: publish-package.sh TAG CODENAME DEB}
deb=${3:?usage: publish-package.sh TAG CODENAME DEB}
manifest=${MANIFEST_PATH:-releases/manifest.json}
base_directory=${REPREPRO_BASE_DIR:-repository}

package=$(jq -r --arg tag "$tag" '.[$tag].package' "$manifest")
version=$(jq -r --arg tag "$tag" '.[$tag].version' "$manifest")
expected_sha256=$(jq -r --arg tag "$tag" '.[$tag].sha256' "$manifest")

existing=$(find "$base_directory/pool" -type f \
  -name "${package}_${version}_*.deb" -print -quit 2>/dev/null || true)
if [[ -n "$existing" ]]; then
  existing_sha256=$(sha256sum "$existing" | awk '{print $1}')
  if [[ "$existing_sha256" != "$expected_sha256" ]]; then
    echo "Refusing to replace immutable $package version $version" >&2
    exit 1
  fi
  echo "$package $version is already published with the approved checksum"
  exit 0
fi

latest_version_before=$(reprepro -b "$base_directory" listfilter "$codename" \
  "Package (== $package)" 2>/dev/null | awk '{print $3}' | sort -V | tail -n1 || true)

reprepro -b "$base_directory" includedeb "$codename" "$deb"

latest_version_after=$(reprepro -b "$base_directory" listfilter "$codename" \
  "Package (== $package)" 2>/dev/null | awk '{print $3}' | sort -V | tail -n1 || true)
if [[ -n "$latest_version_before" ]] && \
   dpkg --compare-versions "$latest_version_after" lt "$latest_version_before"; then
  echo "Refusing candidate downgrade from $latest_version_before to $latest_version_after" >&2
  exit 1
fi

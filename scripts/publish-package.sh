#!/usr/bin/env bash
set -euo pipefail

tag=${1:?usage: publish-package.sh TAG CODENAME DEB}
codename=${2:?usage: publish-package.sh TAG CODENAME DEB}
deb=${3:?usage: publish-package.sh TAG CODENAME DEB}
manifest=${MANIFEST_PATH:-releases/manifest.json}
base_directory=${APT_REPOSITORY_DIR:-repository}

package=$(jq -r --arg tag "$tag" '.[$tag].package' "$manifest")
version=$(jq -r --arg tag "$tag" '.[$tag].version' "$manifest")
asset=$(jq -r --arg tag "$tag" '.[$tag].asset' "$manifest")
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
else
  if [[ "$package" == lib?* ]]; then
    pool_prefix=${package:0:4}
  else
    pool_prefix=${package:0:1}
  fi
  destination="$base_directory/pool/main/$pool_prefix/$package/$asset"
  install -D -m 0644 "$deb" "$destination"
fi

scripts/rebuild-repository.sh "$base_directory" "$codename"

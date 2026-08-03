#!/usr/bin/env bash
set -euo pipefail

tag=${1:?usage: verify-release.sh TAG CODENAME OUTPUT_DIRECTORY}
codename=${2:?usage: verify-release.sh TAG CODENAME OUTPUT_DIRECTORY}
output_directory=${3:?usage: verify-release.sh TAG CODENAME OUTPUT_DIRECTORY}
manifest=${MANIFEST_PATH:-releases/manifest.json}

if ! jq -e --arg tag "$tag" '.[$tag]' "$manifest" >/dev/null; then
  echo "Tag is not approved in $manifest: $tag" >&2
  exit 1
fi

expected_codename=$(jq -r --arg tag "$tag" '.[$tag].codename' "$manifest")
repository=$(jq -r --arg tag "$tag" '.[$tag].repository' "$manifest")
package=$(jq -r --arg tag "$tag" '.[$tag].package' "$manifest")
version=$(jq -r --arg tag "$tag" '.[$tag].version' "$manifest")
architecture=$(jq -r --arg tag "$tag" '.[$tag].architecture' "$manifest")
asset=$(jq -r --arg tag "$tag" '.[$tag].asset' "$manifest")
expected_sha256=$(jq -r --arg tag "$tag" '.[$tag].sha256' "$manifest")

if [[ "$codename" != "$expected_codename" ]]; then
  echo "Tag $tag is approved only for $expected_codename" >&2
  exit 1
fi

release_json=$(gh release view "$tag" --repo "$repository" \
  --json tagName,isDraft,isPrerelease,assets)

if [[ $(jq -r '.tagName' <<<"$release_json") != "$tag" ]] || \
   [[ $(jq -r '.isDraft' <<<"$release_json") != false ]] || \
   [[ $(jq -r '.isPrerelease' <<<"$release_json") != false ]]; then
  echo "Upstream release must be stable and match $tag" >&2
  exit 1
fi

release_digest=$(jq -r --arg asset "$asset" \
  '.assets[] | select(.name == $asset) | .digest // empty' <<<"$release_json")
if [[ "$release_digest" != "sha256:$expected_sha256" ]]; then
  echo "GitHub release digest does not match the approved manifest" >&2
  exit 1
fi

mkdir -p "$output_directory"
gh release download "$tag" --repo "$repository" --pattern "$asset" \
  --dir "$output_directory"
deb="$output_directory/$asset"

printf '%s  %s\n' "$expected_sha256" "$deb" | sha256sum --check --status
gh attestation verify "$deb" --repo "$repository" >&2

actual_package=$(dpkg-deb --field "$deb" Package)
actual_version=$(dpkg-deb --field "$deb" Version)
actual_architecture=$(dpkg-deb --field "$deb" Architecture)

if [[ "$actual_package" != "$package" ]] || \
   [[ "$actual_version" != "$version" ]] || \
   [[ "$actual_architecture" != "$architecture" ]]; then
  echo "Package metadata does not match the approved manifest" >&2
  exit 1
fi

printf '%s\n' "$deb"

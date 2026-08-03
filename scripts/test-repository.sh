#!/usr/bin/env bash
set -euo pipefail

repository=${1:-repository}
keyring=${2:-keys/exoduscode-archive-keyring.gpg}
manifest=${MANIFEST_PATH:-releases/manifest.json}
tag=${TAG:-v0.1.2}
codename=${CODENAME:-noble}

gpgv --keyring "$keyring" "$repository/dists/$codename/InRelease"
gpgv --keyring "$keyring" "$repository/dists/$codename/Release.gpg" \
  "$repository/dists/$codename/Release"

tampered=$(mktemp)
cp "$repository/dists/$codename/InRelease" "$tampered"
sed -i 's/Origin: ExodusCode/Origin: Tampered/' "$tampered"
if gpgv --keyring "$keyring" "$tampered" >/dev/null 2>&1; then
  echo "Tampered InRelease was incorrectly accepted" >&2
  exit 1
fi
rm -f "$tampered"

if gpgv --keyring /dev/null "$repository/dists/$codename/InRelease" \
  >/dev/null 2>&1; then
  echo "InRelease was incorrectly accepted without the repository key" >&2
  exit 1
fi

package=$(jq -r --arg tag "$tag" '.[$tag].package' "$manifest")
version=$(jq -r --arg tag "$tag" '.[$tag].version' "$manifest")
cli_version=$(jq -r --arg tag "$tag" '.[$tag].cli_version' "$manifest")
expected_sha256=$(jq -r --arg tag "$tag" '.[$tag].sha256' "$manifest")
deb=$(find "$repository/pool" -type f -name "${package}_${version}_*.deb" -print -quit)
if [[ -z "$deb" ]]; then
  echo "$package $version is missing from the repository pool" >&2
  exit 1
fi
printf '%s  %s\n' "$expected_sha256" "$deb" | sha256sum --check --status

latest_version=$(jq -r --arg package "$package" --arg codename "$codename" '
  .[] | select(.package == $package and .codename == $codename) | .version
' "$manifest" | sort -V | tail -n1)
latest_cli_version=$(jq -r --arg package "$package" --arg codename "$codename" \
  --arg version "$latest_version" '
  .[] |
  select(.package == $package and .codename == $codename and .version == $version) |
  .cli_version
' "$manifest")

docker run --rm \
  -e PACKAGE="$package" \
  -e VERSION="$version" \
  -e CLI_VERSION="$cli_version" \
  -e LATEST_VERSION="$latest_version" \
  -e LATEST_CLI_VERSION="$latest_cli_version" \
  -v "$PWD/$repository:/repo:ro" \
  -v "$PWD/$keyring:/exoduscode-keyring.gpg:ro" \
  ubuntu:24.04 bash -euc '
    cp /exoduscode-keyring.gpg /usr/share/keyrings/exoduscode-archive-keyring.gpg
    printf "%s\n" \
      "Types: deb" \
      "URIs: file:/repo" \
      "Suites: noble" \
      "Components: main" \
      "Signed-By: /usr/share/keyrings/exoduscode-archive-keyring.gpg" \
      >/etc/apt/sources.list.d/exoduscode.sources
    apt-get update
    apt-cache policy "$PACKAGE" | grep -F "Candidate: $LATEST_VERSION"
    apt-cache madison "$PACKAGE" | awk "{print \$3}" | grep -Fx "$VERSION"
    apt-get install -y "$PACKAGE=$VERSION"
    "$PACKAGE" --version | grep -F "$PACKAGE $CLI_VERSION"
    "$PACKAGE" count
    apt-get remove -y "$PACKAGE"
    apt-get install -y "$PACKAGE"
    "$PACKAGE" --version | grep -F "$PACKAGE $LATEST_CLI_VERSION"
  '

#!/usr/bin/env bash
set -euo pipefail

base_directory=${1:-repository}
codename=${2:-noble}
manifest=${MANIFEST_PATH:-releases/manifest.json}
config="$base_directory/conf/release.json"

test "$(jq -r '.codename' "$config")" = "$codename"
component=$(jq -r '.components | if length == 1 then .[0] else error("exactly one component is required") end' "$config")
origin=$(jq -r '.origin' "$config")
label=$(jq -r '.label' "$config")
suite=$(jq -r '.suite' "$config")
release_version=$(jq -r '.version' "$config")
description=$(jq -r '.description' "$config")
sign_with=$(jq -r '.sign_with' "$config")
mkdir -p "$base_directory/pool"

while IFS= read -r -d '' deb; do
  package=$(dpkg-deb --field "$deb" Package)
  version=$(dpkg-deb --field "$deb" Version)
  architecture=$(dpkg-deb --field "$deb" Architecture)
  actual_sha256=$(sha256sum "$deb" | awk '{print $1}')
  expected_sha256=$(jq -r --arg package "$package" --arg version "$version" \
    --arg architecture "$architecture" '
      .[] |
      select(
        .package == $package and
        .version == $version and
        .architecture == $architecture
      ) |
      .sha256
    ' "$manifest" | head -n1)
  if [[ -z "$expected_sha256" || "$expected_sha256" != "$actual_sha256" ]]; then
    echo "Pool contains an unapproved or modified package: $deb" >&2
    exit 1
  fi
done < <(find "$base_directory/pool" -type f -name '*.deb' -print0 | sort -z)

rm -rf "$base_directory/db" "$base_directory/dists/$codename"

for architecture in $(jq -r '.architectures[]' "$config"); do
  binary_directory="$base_directory/dists/$codename/$component/binary-$architecture"
  mkdir -p "$binary_directory"
  (
    cd "$base_directory"
    dpkg-scanpackages --arch all --multiversion pool /dev/null
  ) >"$binary_directory/Packages"
  gzip --no-name --best --stdout "$binary_directory/Packages" >"$binary_directory/Packages.gz"
  cat >"$binary_directory/Release" <<EOF
Archive: $suite
Version: $release_version
Component: $component
Origin: $origin
Label: $label
Architecture: $architecture
EOF
done

release_file="$base_directory/dists/$codename/Release"
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=$origin" \
  -o "APT::FTPArchive::Release::Label=$label" \
  -o "APT::FTPArchive::Release::Suite=$suite" \
  -o "APT::FTPArchive::Release::Codename=$codename" \
  -o "APT::FTPArchive::Release::Version=$release_version" \
  -o "APT::FTPArchive::Release::Architectures=$(jq -r '.architectures | join(" ")' "$config")" \
  -o "APT::FTPArchive::Release::Components=$component" \
  -o "APT::FTPArchive::Release::Description=$description" \
  release "$base_directory/dists/$codename" >"$release_file"

gpg --batch --yes --local-user "$sign_with" --output "$base_directory/dists/$codename/Release.gpg" --detach-sign "$release_file"
gpg --batch --yes --local-user "$sign_with" --output "$base_directory/dists/$codename/InRelease" --clearsign "$release_file"

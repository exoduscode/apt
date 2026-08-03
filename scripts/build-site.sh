#!/usr/bin/env bash
set -euo pipefail

output=${1:-site}
repository=${2:-repository}
keys=${3:-keys}
if [[ "$output" != "site" ]]; then
  echo "The Pages output directory must be the repository-local site directory" >&2
  exit 1
fi
rm -rf site
mkdir -p site
cp -R "$repository/dists" "$repository/pool" "$keys" site/
touch site/.nojekyll
cat >site/index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>ExodusCode APT repository</title></head>
  <body>
    <h1>ExodusCode APT repository</h1>
    <p>See <a href="https://github.com/exoduscode/apt">installation instructions</a>.</p>
    <p>Signing-key fingerprint: <code>C85D DAF2 A38C A242 A745 D9DE 5A40 25DA 3610 A2EC</code></p>
  </body>
</html>
EOF

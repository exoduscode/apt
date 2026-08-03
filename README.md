# ExodusCode APT repository

Signed APT packages for ExodusCode projects. The initial supported platform is
Ubuntu 24.04 LTS (`noble`) on AMD64 and ARM64.

## Configure once

```bash
curl -fsSL https://exoduscode.github.io/apt/keys/exoduscode-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/exoduscode-archive-keyring.gpg >/dev/null

sudo tee /etc/apt/sources.list.d/exoduscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://exoduscode.github.io/apt
Suites: noble
Components: main
Signed-By: /usr/share/keyrings/exoduscode-archive-keyring.gpg
EOF

sudo apt update
sudo apt install lsusers
```

Signing-key fingerprint:

```text
C85D DAF2 A38C A242 A745  D9DE 5A40 25DA 3610 A2EC
```

Always compare the complete fingerprint before trusting a downloaded key.

## Repository policy

- Packages are imported only from stable upstream GitHub Releases listed in
  `releases/manifest.json`.
- A published package version is immutable. Republishing the same version with
  different bytes is rejected.
- Downgrades are rejected.
- The archive key expires on 2028-07-30. Rotation must begin at least 90 days
  before expiry.
- Generated indexes and packages are retained in Git so upgrades and rollback
  investigations remain auditable.
- Reviewed source, workflows, manifests, signing policy, and `reprepro`
  configuration live on protected `main`. Generated databases, signed indexes,
  and packages live only on the append-only `apt-repository` publication
  branch. The publishing workflow copies the reviewed configuration into the
  published state, can fast-forward that branch, and cannot write to `main`.
- GitHub Pages is deployed from an artifact assembled by the approved workflow;
  Pages does not execute or publish unreviewed branch contents directly.

See [SECURITY.md](SECURITY.md) for key rotation and revocation procedures.

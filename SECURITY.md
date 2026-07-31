# Repository signing-key operations

## Current key

- Identity: `ExodusCode APT Archive <packages@exoduscode.io>`
- Fingerprint: `C85D DAF2 A38C A242 A745 D9DE 5A40 25DA 3610 A2EC`
- Algorithm: RSA 4096
- Expires: 2028-07-30
- Public key: `keys/exoduscode-archive-keyring.gpg`

The encrypted private key and its passphrase exist only as secrets in the
protected GitHub environment `production`. They must never be committed,
printed in logs, attached to releases, or copied into build artifacts.

## Planned rotation

1. Generate a new dedicated signing key on a trusted workstation at least 90
   days before expiry.
2. Add the new public key alongside the old key and publish both fingerprints.
3. Sign repository metadata with both keys during the transition period when
   tooling permits; otherwise distribute a combined keyring before switching.
4. Update the protected environment secrets and `SignWith` fingerprint.
5. Keep the old public key available for historical verification.
6. Remove trust in the old key only after all supported clients have had a
   documented migration window.

## Emergency revocation

If compromise is suspected, stop the publish workflow, disable GitHub Pages,
remove access to the `production` environment, publish the offline revocation
certificate, generate a new key, and require users to install the replacement
keyring explicitly. Never silently replace the key at the same URL without a
public incident notice and fingerprint verification instructions.


#!/usr/bin/env bash
# Decrypt the encrypted state file back to plain Terraform state, so you can
# re-run plan/apply (e.g. to update IAM trust policy). Reverse of encrypt-state.sh.
#
# Usage:
#   ./scripts/decrypt-state.sh <account-name>

set -euo pipefail

ACCOUNT="${1:?usage: $0 <account-name>}"
ENC="state/${ACCOUNT}.tfstate.encrypted"
PLAIN="state/${ACCOUNT}.tfstate"

if [[ ! -f "$ENC" ]]; then
  echo "ERROR: $ENC not found." >&2
  exit 1
fi

if ! command -v sops >/dev/null 2>&1; then
  echo "ERROR: sops not installed." >&2
  exit 1
fi

echo "→ Decrypting $ENC → $PLAIN"
sops --decrypt --input-type json --output-type json "$ENC" > "$PLAIN"
echo "✓ Decrypted. NOTE: $PLAIN is now plaintext on disk — re-encrypt before commit."

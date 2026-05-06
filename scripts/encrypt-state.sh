#!/usr/bin/env bash
# Encrypt the local Terraform state file with sops, ready to commit.
# Run this immediately after `terraform apply` succeeds.
#
# Usage:
#   ./scripts/encrypt-state.sh <account-name>
# Example:
#   ./scripts/encrypt-state.sh sandbox

set -euo pipefail

ACCOUNT="${1:?usage: $0 <account-name>}"
PLAIN="state/${ACCOUNT}.tfstate"
ENC="state/${ACCOUNT}.tfstate.encrypted"

if [[ ! -f "$PLAIN" ]]; then
  echo "ERROR: $PLAIN not found. Did you run 'terraform apply' with the matching backend config?" >&2
  exit 1
fi

if ! command -v sops >/dev/null 2>&1; then
  echo "ERROR: sops not installed. brew install sops (mac) or see https://github.com/getsops/sops" >&2
  exit 1
fi

echo "→ Encrypting $PLAIN → $ENC"
sops --encrypt --input-type json --output-type json "$PLAIN" > "$ENC"

# Sanity check: re-decrypt and diff
sops --decrypt "$ENC" > "/tmp/${ACCOUNT}.decrypted.tfstate"
if ! diff -q "$PLAIN" "/tmp/${ACCOUNT}.decrypted.tfstate" >/dev/null; then
  echo "ERROR: encrypted file does not round-trip cleanly. Aborting." >&2
  rm -f "$ENC" "/tmp/${ACCOUNT}.decrypted.tfstate"
  exit 1
fi
rm -f "/tmp/${ACCOUNT}.decrypted.tfstate"

echo "✓ Encrypted state at $ENC"
echo
echo "Next:"
echo "  rm $PLAIN              # remove the unencrypted file (it's already gitignored, but be explicit)"
echo "  git add $ENC"
echo "  git commit -m \"chore(${ACCOUNT}): bootstrap state\""

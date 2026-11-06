#!/usr/bin/env bash
# Creates .env from .env.example. ADMIN_TOKEN is filled manually because
# `vaultwarden hash` prompts twice and cannot be piped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  echo ".env already exists — delete it first to regenerate." >&2
  exit 1
fi

cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
echo "Plaintext admin token (store in the vault once it exists):"
openssl rand -base64 48 | tr -d '\n'; echo
echo
echo "Next: hash it with"
echo "  docker run --rm -it vaultwarden/server:1.37.5 /vaultwarden hash --preset owasp"
echo "then put the \$argon2id\$... string in .env, SINGLE-QUOTED."

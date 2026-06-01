#!/usr/bin/env bash
set -euo pipefail
# Rendered for cluster=drroc4 instance=drgitopsapp. Template only — never commit a filled-in copy.
# Export the required values in your shell, then run against an unsealed Vault (KV v2 at secret/).

PREFIX="secret/mas/drroc4"
IPREFIX="secret/mas/drroc4/drgitopsapp"

: "${IBM_ENTITLEMENT_KEY:?}" ; : "${MAS_LICENSE_FILE:?}" ; : "${MAS_LICENSE_ID:=}"
: "${MAS_SUPERUSER_USERNAME:=superuser}" ; : "${MAS_SUPERUSER_PASSWORD:?}"
: "${JDBC_USERNAME:?}" ; : "${JDBC_PASSWORD:?}" ; : "${JDBC_URL:?}" ; : "${JDBC_CA_CRT:?path to Oracle CA PEM}"
: "${MANAGE_CRYPTO_KEY:?}" ; : "${MANAGE_CRYPTOX_KEY:?}"
: "${MONGO_USERNAME:?}" ; : "${MONGO_PASSWORD:?}" ; : "${MONGO_HOST:?}" ; : "${MONGO_CA_CRT:?}"
: "${SLS_MONGO_USERNAME:?}" ; : "${SLS_MONGO_PASSWORD:?}" ; : "${SLS_MONGO_CA_CRT:?}"
: "${SLS_REGISTRATION_KEY:=}" ; : "${SLS_URL:=}" ; : "${SLS_CA_CRT:=}"

ENC="$(printf 'cp:%s' "$IBM_ENTITLEMENT_KEY" | base64 | tr -d '\n')"
DOCKERCFG="$(printf '{\"auths\":{\"cp.icr.io\":{\"auth\":\"%s\"}}}' "$ENC" | base64 | tr -d '\n')"

vault kv put "$PREFIX/entitlement" image_pull_secret_b64="$DOCKERCFG"

vault kv put "$IPREFIX/license"  license_id="$MAS_LICENSE_ID" license_file="$(base64 "$MAS_LICENSE_FILE" | tr -d '\n')"
vault kv put "$IPREFIX/superuser" username="$MAS_SUPERUSER_USERNAME" password="$MAS_SUPERUSER_PASSWORD"

vault kv put "$IPREFIX/jdbc-system" \
  username="$JDBC_USERNAME" password="$JDBC_PASSWORD" jdbc_url="$JDBC_URL" ca.crt="$(cat "$JDBC_CA_CRT")"

vault kv put "$IPREFIX/manage-crypto" cryptoKey="$MANAGE_CRYPTO_KEY" cryptoxKey="$MANAGE_CRYPTOX_KEY"

vault kv put "$IPREFIX/mongo" \
  username="$MONGO_USERNAME" password="$MONGO_PASSWORD" host="$MONGO_HOST" ca.crt="$(cat "$MONGO_CA_CRT")"

vault kv put "$IPREFIX/sls-mongo" \
  username="$SLS_MONGO_USERNAME" password="$SLS_MONGO_PASSWORD" ca.crt="$(cat "$SLS_MONGO_CA_CRT")"

if [[ -n "$SLS_REGISTRATION_KEY" || -n "$SLS_URL" || -n "$SLS_CA_CRT" ]]; then
  vault kv put "$IPREFIX/sls" \
    registration_key="$SLS_REGISTRATION_KEY" url="$SLS_URL" \
    ca.crt="$( [[ -n "$SLS_CA_CRT" ]] && cat "$SLS_CA_CRT" || echo "" )"
fi

echo "Loaded Vault secrets under $PREFIX and $IPREFIX"

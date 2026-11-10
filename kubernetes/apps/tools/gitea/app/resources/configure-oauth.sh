#!/bin/sh
# Registers (or updates) the Authentik OIDC login source in Gitea's database.
# Login sources are DB rows, not app.ini settings, so GITEA__* env vars can't
# create them; this runs as an init container on every pod start instead.
#
# The source name is part of the callback URL configured in Authentik:
#   https://gitea.<domain>/user/oauth2/authentik/callback
set -eu

SOURCE_NAME="authentik"

if [ -z "${OIDC_CLIENT_ID:-}" ] || [ -z "${OIDC_CLIENT_SECRET:-}" ]; then
  echo "OIDC_CLIENT_ID/OIDC_CLIENT_SECRET not set, skipping ${SOURCE_NAME} login source"
  exit 0
fi

# Same step the image entrypoint runs before starting Gitea: fold GITEA__* env
# (incl. the DB password) into app.ini so the CLI can reach the database.
environment-to-ini --config "${GITEA_APP_INI}"

set -- \
  --name "${SOURCE_NAME}" \
  --provider openidConnect \
  --key "${OIDC_CLIENT_ID}" \
  --secret "${OIDC_CLIENT_SECRET}" \
  --auto-discover-url "${OIDC_DISCOVERY_URL}" \
  --scopes email \
  --scopes profile \
  --skip-local-2fa

id="$(gitea admin auth list | awk -v name="${SOURCE_NAME}" '$2 == name { print $1 }')"

if [ -n "${id}" ]; then
  echo "Updating login source ${SOURCE_NAME} (id ${id})"
  gitea admin auth update-oauth --id "${id}" "$@"
else
  echo "Adding login source ${SOURCE_NAME}"
  gitea admin auth add-oauth "$@"
fi

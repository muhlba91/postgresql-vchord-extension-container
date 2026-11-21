#!/usr/bin/env bash
# usage: smoke.sh <postgresql image> <pgvector image> <vchord image> <vchord version>
# the extension images are extracted and mounted under /extensions like CloudNativePG does
set -euo pipefail

postgresql_image="$1"
pgvector_image="$2"
vchord_image="$3"
vchord_version="$4"
engine="${CONTAINER_ENGINE:-docker}"
root="$(cd "$(dirname "$0")" && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

extract() {
  local id
  id="$("${engine}" create "$1" /noop)"
  mkdir -p "${work}/$2"
  "${engine}" cp "${id}:/." "${work}/$2"
  "${engine}" rm "${id}" >/dev/null
}

extract "${pgvector_image}" pgvector
extract "${vchord_image}" vchord

# shellcheck disable=SC2016 # the script runs in the container shell
"${engine}" run --rm --user 26 \
  -v "${work}/pgvector:/extensions/pgvector:ro" \
  -v "${work}/vchord:/extensions/vchord:ro" \
  -v "${root}/smoke.sql:/smoke.sql:ro" \
  -e "VCHORD_VERSION=${vchord_version}" \
  "${postgresql_image}" \
  bash -euc '
    initdb -D /tmp/pgdata -A trust >/dev/null
    postgres -D /tmp/pgdata \
      -c shared_preload_libraries=vchord \
      -c "extension_control_path=/extensions/pgvector/share:/extensions/vchord/share:\$system" \
      -c "dynamic_library_path=/extensions/pgvector/lib:/extensions/vchord/lib:\$libdir" \
      >/tmp/postgres.log 2>&1 &
    for _ in $(seq 60); do pg_isready -q && break; sleep 1; done
    pg_isready -q || { cat /tmp/postgres.log; exit 1; }
    psql -X -v ON_ERROR_STOP=1 -v vchord_version="${VCHORD_VERSION}" -d postgres -f /smoke.sql
  '

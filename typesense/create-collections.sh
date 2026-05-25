#!/usr/bin/env bash
#
# Creates all Typesense collections for Kineograph.
#
# Prerequisites:
#   export TYPESENSE_HOST=xxx.a1.typesense.net
#   export TYPESENSE_ADMIN_KEY=your-admin-api-key
#
# Usage:
#   ./create-collections.sh          # create all collections
#   ./create-collections.sh --drop   # drop + recreate all collections

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

: "${TYPESENSE_HOST:?Set TYPESENSE_HOST (e.g. xxx.a1.typesense.net)}"
: "${TYPESENSE_ADMIN_KEY:?Set TYPESENSE_ADMIN_KEY}"

BASE_URL="https://${TYPESENSE_HOST}"
AUTH_HEADER="X-TYPESENSE-API-KEY: ${TYPESENSE_ADMIN_KEY}"

DROP="${1:-}"

# ── Scrubber collections (share the scrubbers.json schema) ───────────────

SCRUBBER_COLLECTIONS=(
  scrubbers_library
  scrubbers_user
)

create_collection() {
  local name="$1"
  local schema_file="$2"

  if [[ "$DROP" == "--drop" ]]; then
    echo "  Dropping $name …"
    curl -s -o /dev/null -w "%{http_code}" \
      -X DELETE "${BASE_URL}/collections/${name}" \
      -H "${AUTH_HEADER}" || true
    echo ""
  fi

  echo "  Creating $name …"
  # Replace the PLACEHOLDER name in the schema with the actual collection name.
  local body
  body=$(sed "s/\"PLACEHOLDER\"/\"${name}\"/" "$schema_file")

  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${BASE_URL}/collections" \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -d "$body")

  if [[ "$status" == "201" ]]; then
    echo "  ✅ $name created"
  elif [[ "$status" == "409" ]]; then
    echo "  ⏭️  $name already exists (409)"
  else
    echo "  ❌ $name failed (HTTP $status)"
  fi
}

echo "═══ Articles (unified) ═══"
create_collection "articles" "${SCRIPT_DIR}/schemas/articles.json"

echo ""
echo "═══ Scrubber collections ═══"
for coll in "${SCRUBBER_COLLECTIONS[@]}"; do
  create_collection "$coll" "${SCRIPT_DIR}/schemas/scrubbers.json"
done

echo ""
echo "═══ User profiles ═══"
create_collection "user_profiles" "${SCRIPT_DIR}/schemas/user_profiles.json"

echo ""
echo "═══ Official Account profiles ═══"
create_collection "oa_profiles" "${SCRIPT_DIR}/schemas/oa_profiles.json"

echo ""
echo "Done. Total: 1 article + ${#SCRUBBER_COLLECTIONS[@]} scrubber + 1 user_profiles + 1 oa_profiles = $(( 1 + ${#SCRUBBER_COLLECTIONS[@]} + 2 )) collections."

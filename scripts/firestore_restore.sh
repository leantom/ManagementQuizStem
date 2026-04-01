#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-brainbolt-281c7}"
DATABASE_ID="${DATABASE_ID:-prod-stem-db}"
IMPORT_URI_PREFIX="${IMPORT_URI_PREFIX:?Set IMPORT_URI_PREFIX to the completed Firestore export URI prefix.}"
IMPORT_KIND="${IMPORT_KIND:-full}"
COLLECTION_IDS="${COLLECTION_IDS:-Subjects,Topics,Questions,challenges,badges}"
ACK_IMPORT="${ACK_IMPORT:-}"

case "${IMPORT_KIND}" in
  full|scoped)
    ;;
  *)
    echo "Unsupported IMPORT_KIND: ${IMPORT_KIND}. Use 'full' or 'scoped'." >&2
    exit 1
    ;;
esac

if [[ "${ACK_IMPORT}" != "YES" ]]; then
  cat >&2 <<'EOF'
Refusing to import without ACK_IMPORT=YES.

Firestore imports overwrite matching document IDs, but they do not delete documents
that are not touched by the import. If you need an exact rollback, delete or archive
post-migration documents first, or restore into a clean database.
EOF
  exit 1
fi

cmd=(
  gcloud firestore import "${IMPORT_URI_PREFIX}"
  "--project=${PROJECT_ID}"
  "--database=${DATABASE_ID}"
)

if [[ "${IMPORT_KIND}" == "scoped" ]]; then
  cmd+=("--collection-ids=${COLLECTION_IDS}")
fi

echo "Starting Firestore import with:"
echo "  PROJECT_ID=${PROJECT_ID}"
echo "  DATABASE_ID=${DATABASE_ID}"
echo "  IMPORT_KIND=${IMPORT_KIND}"
echo "  IMPORT_URI_PREFIX=${IMPORT_URI_PREFIX}"
if [[ "${IMPORT_KIND}" == "scoped" ]]; then
  echo "  COLLECTION_IDS=${COLLECTION_IDS}"
fi
echo
printf 'Running: '
printf '%q ' "${cmd[@]}"
echo

"${cmd[@]}"

echo
echo "Import submitted."
echo "Validate production reads before reopening admin write flows."

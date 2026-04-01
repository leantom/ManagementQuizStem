#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-brainbolt-281c7}"
DATABASE_ID="${DATABASE_ID:-prod-stem-db}"
BACKUP_BUCKET="${BACKUP_BUCKET:?Set BACKUP_BUCKET to a GCS bucket name without the gs:// prefix.}"
EXPORT_KIND="${EXPORT_KIND:-full}"
EXPORT_ROOT="${EXPORT_ROOT:-firestore-backups}"
COLLECTION_IDS="${COLLECTION_IDS:-Subjects,Topics,Questions,challenges,badges}"
RELEASE_TAG="${RELEASE_TAG:-manual}"
SNAPSHOT_TIME="${SNAPSHOT_TIME:-}"
TIMESTAMP="${TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"

OUTPUT_URI_PREFIX="gs://${BACKUP_BUCKET}/${EXPORT_ROOT}/${DATABASE_ID}/${TIMESTAMP}_${RELEASE_TAG}"

case "${EXPORT_KIND}" in
  full|scoped)
    ;;
  *)
    echo "Unsupported EXPORT_KIND: ${EXPORT_KIND}. Use 'full' or 'scoped'." >&2
    exit 1
    ;;
esac

cmd=(
  gcloud firestore export "${OUTPUT_URI_PREFIX}"
  "--project=${PROJECT_ID}"
  "--database=${DATABASE_ID}"
)

if [[ -n "${SNAPSHOT_TIME}" ]]; then
  cmd+=("--snapshot-time=${SNAPSHOT_TIME}")
fi

if [[ "${EXPORT_KIND}" == "scoped" ]]; then
  cmd+=("--collection-ids=${COLLECTION_IDS}")
fi

echo "Starting Firestore export with:"
echo "  PROJECT_ID=${PROJECT_ID}"
echo "  DATABASE_ID=${DATABASE_ID}"
echo "  EXPORT_KIND=${EXPORT_KIND}"
echo "  OUTPUT_URI_PREFIX=${OUTPUT_URI_PREFIX}"
if [[ -n "${SNAPSHOT_TIME}" ]]; then
  echo "  SNAPSHOT_TIME=${SNAPSHOT_TIME}"
fi
if [[ "${EXPORT_KIND}" == "scoped" ]]; then
  echo "  COLLECTION_IDS=${COLLECTION_IDS}"
fi
echo
printf 'Running: '
printf '%q ' "${cmd[@]}"
echo

"${cmd[@]}"

echo
echo "Export submitted."
echo "Record the completed operation's final outputUriPrefix before starting the migration."

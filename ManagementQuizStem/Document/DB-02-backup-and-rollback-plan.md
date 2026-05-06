# DB-02 Production Backup And Rollback Plan

## Purpose

This runbook defines the minimum backup and rollback procedure that must happen before any Firestore schema migration or destructive data change.

It is written against the current app configuration:

- Xcode build configs set `FIREBASE_ENV` to `dev`, `beta`, or `prod`
- `AppFirestore.database()` maps:
  - `dev` -> `(default)`
  - `beta` -> `beta-stem-db`
  - `prod` -> `prod-stem-db`
- Only `GoogleService-Info.plist` is present in the repo, so the Firebase project currently resolves to `brainbolt-281c7` unless a build pipeline injects environment-specific plist files outside the repo

For production changes, assume the target database is:

- `PROJECT_ID=brainbolt-281c7`
- `DATABASE_ID=prod-stem-db`

Do not start a migration until the operator has confirmed the deployed app build is still pointed at that exact project/database pair.

## Collections In Scope

Primary production collections and collection groups:

- `Subjects`
- `Topics`
- `questions`
- `Questions`
- `users`
- `learningPaths`
- `dailyChallenges`
- `challenges`
- `badges`
- `satExamQuestions`

Legacy path also covered by the backup:

- `Topics/{topicId}/Questions`
- `Topics/{topicId}/questions`

Important:

- Firestore export/import uses collection groups, not just root collections.
- Exporting/importing collection ID `Questions` covers both root `Questions` and nested `Topics/{topicId}/Questions` documents.
- Exporting/importing collection ID `questions` covers root `questions` and nested `Topics/{topicId}/questions` documents.

## Backup Strategy

### Required backup before every schema change

1. Freeze app writes.
2. Capture release metadata.
3. Export Firestore before the first mutation.
4. Verify the export completed successfully.
5. Record the final export URI in the change log.

### Write freeze requirement

A Firestore managed export is not a guaranteed exact snapshot of the database at export start time. If writes continue during export, the backup can include in-flight changes.

Because this admin app has no runtime feature flag or server-side write toggle, the write freeze must be operational:

- stop using the admin app for schema-changing actions
- do not run topic import, question import, challenge upload, badge seed upload, or subject edits during backup
- if needed, distribute a previous safe build or temporarily block operator access until the migration window starts

### Preferred backup modes

Use one of these modes:

- Preferred if PITR is enabled: export from a `--snapshot-time` timestamp immediately after the write freeze
- Otherwise: run a managed export after the write freeze and treat that export as the rollback baseline

### Release metadata to capture

Record these values before export:

- Git commit SHA
- app build configuration
- Firebase project ID
- Firestore database ID
- operator name
- migration name
- UTC start time

## Export Procedure

### Full export

Use a full export as the primary rollback artifact.

Example:

```bash
PROJECT_ID=brainbolt-281c7 \
DATABASE_ID=prod-stem-db \
BACKUP_BUCKET=<gcs-bucket-name> \
EXPORT_KIND=full \
RELEASE_TAG=<migration-or-release-tag> \
/Users/quangho/Documents/ManagementQuizStem/scripts/firestore_export.sh
```

### Optional scoped export

If you want a smaller, faster artifact for dry runs or a collection-scoped rollback rehearsal, also create a scoped export:

```bash
PROJECT_ID=brainbolt-281c7 \
DATABASE_ID=prod-stem-db \
BACKUP_BUCKET=<gcs-bucket-name> \
EXPORT_KIND=scoped \
COLLECTION_IDS=Subjects,Topics,Questions,challenges,badges \
RELEASE_TAG=<migration-or-release-tag> \
/Users/quangho/Documents/ManagementQuizStem/scripts/firestore_export.sh
```

For the brain-training schema, use:

```bash
PROJECT_ID=brainbolt-281c7 \
DATABASE_ID=prod-stem-db \
BACKUP_BUCKET=<gcs-bucket-name> \
EXPORT_KIND=scoped \
COLLECTION_IDS=Subjects,Topics,Questions,questions,users,learningPaths,dailyChallenges,challenges,badges,satExamQuestions \
RELEASE_TAG=<migration-or-release-tag> \
/Users/quangho/Documents/ManagementQuizStem/scripts/firestore_export.sh
```

### Export verification checklist

Do not proceed until all are true:

- the export command returned success
- the long-running export operation completed successfully
- the final `outputUriPrefix` was recorded
- the backup bucket path is readable by the rollback operator
- the migration ticket or runbook includes the exact export URI

## Rollback Triggers

Rollback should start immediately if any of these happen:

- migration writes corrupt `Topics.name` or `Topics.category`
- question imports produce missing or duplicated root `questions`
- challenge creation points to missing question IDs
- learning paths point to missing `questions/{questionId}` documents
- daily challenges point to missing `questions/{questionId}` references
- badge or subject writes fail because of schema incompatibility
- the shipped app can no longer read production data without errors

## Rollback Plan

Rollback has two parts and both matter:

- app-behavior rollback
- data rollback

### 1. App-behavior rollback

Do this first to stop further damage:

1. Stop all operators from using the admin app.
2. Revert to the last known-good app build if a new build changed Firestore behavior.
3. If a new build is not the cause, keep the current build offline until data restore is complete.

Current limitation:

- this repo does not have runtime feature flags, Remote Config gates, or a write-disable switch for admin flows
- operational freeze or app build rollback is therefore the only immediate behavior rollback

### 2. Data rollback

Choose one of these recovery modes:

- Exact rollback of a small set of collection groups:
  - delete or archive post-migration documents in the affected collection groups
  - then import the scoped export
- Full database rollback:
  - restore from the full export into the target production database
  - or, if safer for validation, restore into a clean staging database first and cut traffic after verification

Important Firestore import behavior:

- imports overwrite matching document IDs
- imports do not delete documents that are not touched by the import

That means an import alone is not an exact rollback if the failed migration created new documents or new paths. Exact rollback requires one of:

- pre-delete of the post-migration documents in the affected collection groups
- restore into a clean database

### Restore command

Use the recorded `outputUriPrefix` from the successful export:

```bash
PROJECT_ID=brainbolt-281c7 \
DATABASE_ID=prod-stem-db \
IMPORT_URI_PREFIX=gs://<bucket>/<export-prefix>/ \
IMPORT_KIND=full \
ACK_IMPORT=YES \
/Users/quangho/Documents/ManagementQuizStem/scripts/firestore_restore.sh
```

Scoped import example:

```bash
PROJECT_ID=brainbolt-281c7 \
DATABASE_ID=prod-stem-db \
IMPORT_URI_PREFIX=gs://<bucket>/<export-prefix>/ \
IMPORT_KIND=scoped \
COLLECTION_IDS=Subjects,Topics,Questions,challenges,badges \
ACK_IMPORT=YES \
/Users/quangho/Documents/ManagementQuizStem/scripts/firestore_restore.sh
```

Brain-training scoped import example:

```bash
PROJECT_ID=brainbolt-281c7 \
DATABASE_ID=prod-stem-db \
IMPORT_URI_PREFIX=gs://<bucket>/<export-prefix>/ \
IMPORT_KIND=scoped \
COLLECTION_IDS=Subjects,Topics,Questions,questions,users,learningPaths,dailyChallenges,challenges,badges,satExamQuestions \
ACK_IMPORT=YES \
/Users/quangho/Documents/ManagementQuizStem/scripts/firestore_restore.sh
```

## Post-Restore Validation

After rollback, verify:

- the admin app launches and authenticates anonymously
- subjects list loads
- topics list loads and sort order still works on `category`
- root `questions` can be fetched and deleted by `topicID`
- root `Questions` remains available only as legacy migration data
- learning path counts load on the dashboard
- daily challenge counts load on the dashboard
- user profile count loads on the dashboard
- challenge creation screen loads Topics without decode failures
- badge seed data shape still decodes
- a spot-check of `Subjects`, `Topics`, `questions`, `users`, `learningPaths`, `dailyChallenges`, `challenges`, `badges`, and `satExamQuestions` matches the pre-migration baseline

## Recovery Drill Recommendation

Before the first production schema migration:

1. Run the export procedure against production.
2. Import that export into a non-production database.
3. Launch the app in `beta` or `dev` against the restored data.
4. Verify the five core admin flows still decode and render.

This is the fastest way to prove the rollback artifact is usable before it is needed under incident pressure.

## Operator Notes

- Use the helper scripts in `/Users/quangho/Documents/ManagementQuizStem/scripts`.
- Keep the exact export URI in the change record.
- Never start a schema migration without a successful export from the same target database.
- Never rely on Firestore import alone to remove bad post-migration documents.

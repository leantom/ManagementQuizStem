# DB-01 Firestore Audit

## Scope

This is a code-level audit of the Firestore usage in the current macOS admin app. It inventories the collections and document shapes the shipped app can read or write, based on the Firestore code paths in:

- `ManagementQuizStem/Subjects/Subject.swift`
- `ManagementQuizStem/Topics/TopicsViewModel.swift`
- `ManagementQuizStem/Questions/QuestionsViewModel.swift`
- `ManagementQuizStem/Topics/ChallengesViewModel.swift`
- `ManagementQuizStem/Topics/Badge/BadgesViewModel.swift`

The app uses the default Firebase app from `GoogleService-Info.plist` via `FirebaseApp.configure()` and does not implement environment switching in code. The bundled Firebase project is `brainbolt-281c7`. Anonymous auth is enabled at app startup.

## Reachable Admin Flows

The sidebar in `ContentView.swift` wires these Firestore-backed flows:

- `Upload from CSV` -> Topics import and education-level backfill
- `Delete Questions by Topic ID` -> root `Questions` read and delete
- `Edit Topics` -> Topics read, update, delete
- `Import Questions from Topics` -> Topics read plus root `Questions` batch import
- `Upload challenges` -> Topics read, root `Questions` batch import, `challenges` create
- `Create Badge` -> `badges` batch seed upload
- `Create subject` -> `Subjects` read/create/update plus Topics read

Anything outside those sidebar routes exists in code but is not currently reachable from the app UI.

## Cross-Cutting Notes

- Collection names are mixed-case and case-sensitive:
  - `Subjects`
  - `Topics`
  - `Questions`
  - `challenges`
  - `badges`
- The app uses batched writes for question imports, question deletes, and badge seed uploads.
- The app does not use Firestore transactions.
- The app does not use `collectionGroup("Questions")`; all question reads go to the root `Questions` collection.

## Collection Inventory

### 1. `Subjects`

Path:

- `Subjects/{subjectId}`

Document identity:

- The document path uses a generated UUID as `subjectId`.
- The `Subject` model declares `@DocumentID var id: String?`, so the document ID is the source of truth for identity.

Observed fields:

- `name: String`
- `short_name: String`
- `description: String`
- `trending: Int`
- `icon_url: String`
- `topicIds: [String]` (optional, only written on update)
- `id` is modeled on the client, but the path key is the reliable identifier.

Query patterns:

- Fetch all subjects sorted by `trending desc`
- Check existence by `name == <subjectName>`

Write paths:

- Create subject:
  - `setData(from:)` on `Subjects/{uuid}`
  - Writes the current form state for `name`, `short_name`, `description`, `trending`, `icon_url`
- Update subject:
  - `updateData(...)` on `Subjects/{subjectId}`
  - Updates any non-empty scalar fields
  - Uses `FieldValue.arrayUnion(topicIDs)` for `topicIds`
- Icon upload:
  - Uploads image to Firebase Storage, then calls `updateSubject(...)` to write the resulting `icon_url`

Current usage notes:

- `CreateNewSubjectView` reads all Subjects and all Topics, then associates topics to a selected subject in memory using `topic.name == subject.name`, not `subject.topicIds`.

Legacy / risk notes:

- The default fallback icon URL points to an older storage bucket (`edu-app-77e5e.appspot.com`), not the current bundled Firebase project.
- The UI update flow passes the previously selected `Subject` object into `updateSubject(...)` instead of rebuilding it from the edited form state. In practice, the current screen mostly updates `topicIds` and re-sends old subject field values.
- `topicIds` are only appended with `arrayUnion`; there is no removal path.

### 2. `Topics`

Path:

- `Topics/{topicId}`

Document identity:

- The document path uses a generated UUID as `topicId`.
- Topic creation also writes the same UUID into the document as an explicit `id` field.

Observed fields:

- `id: String`
- `name: String`
- `category: String`
- `description: String?`
- `trending: Int`
- `iconURL: String?`
- `educationLevel: String?`

Query patterns:

- Fetch all topics sorted by `category`

Write paths:

- Create topic from CSV:
  - `setData(...)` on `Topics/{uuid}`
  - Writes `id`, `name`, `category`, `description`, `trending`
- Update topic:
  - `updateData(...)` on `Topics/{topicId}`
  - May write `name`, `category`, `description`, `iconURL`, `trending`, `educationLevel`
- Delete topic:
  - `delete()` on `Topics/{topicId}`
- Education-level backfill:
  - `updateData(["educationLevel": ...])` on each `Topics/{topicId}`
- Icon upload:
  - Uploads image to Firebase Storage, then updates `iconURL`

Current usage notes:

- Topic data is used as the lookup table for question imports and challenge question imports.
- There are two different semantic lookups in code:
  - `filterTopics(by:)` compares against `topic.name`
  - `filterTopicsByCategory(by:)` compares against `topic.category`

Legacy / risk notes:

- `EditTopicView` is currently miswired:
  - the picker stores `topic.id` in `selectedCategory`
  - the edit form then writes `category: selectedCategory`
  - the `name` input is populated from `firstItem.category`
- Result: the current topic-edit screen can write the topic ID into the `category` field and can also swap the intended `name/category` semantics.
- Duplicate prevention during CSV import checks only `category`, not document ID or the full `(name, category)` tuple.

### 3. Root `Questions`

Path:

- `Questions/{questionId}`

Document identity:

- Batch question imports derive `questionId` as `SHA256(questionText)`.
- The imported question payload does not explicitly write an `id` field; identity is primarily the document path.

Observed fields written to root `Questions`:

- `topicID: String`
- `difficulty: String`
- `questionText: String`
- `options: [String]`
- `correctAnswer: String`
- `explanation: String`

Question model fields expected by reads:

- `id: String?`
- `difficulty: String`
- `questionText: String`
- `options: [String]`
- `correctAnswer: String`
- `topic: String?`
- `topicID: String?`
- `explanation: String?`

Important model/write mismatch:

- Imported root-question documents do not write `topic`.
- Imported root-question documents do not explicitly write `id`.

Query patterns:

- Fetch by topic:
  - `where topicID == <topicId>`
- Delete by topic:
  - query `where topicID == <topicId>` then batch delete all matches
- Quiz/question sampling:
  - `where difficulty == <level>`
  - `where topicID in <topicIds>`
  - `limit 15`
- Duplicate check during JSON import:
  - `where documentId in <up to 10 ids>`
  - executed in batches of 10 because Firestore `in` queries are capped

Write paths:

- JSON import from `ImportQuestionsFromJSONView`:
  - loads a local JSON file
  - resolves each question's topic from the loaded Topics collection
  - batch writes new root `Questions/{sha256(questionText)}`
- Challenge import from `AdminCreateChallengeView`:
  - loads question payloads from a challenge JSON file
  - batch writes root `Questions/{sha256(questionText)}`
  - stores the resulting question IDs into the challenge document

Current usage notes:

- All fetch and delete operations target the root `Questions` collection.
- `DeleteQuestionsByTopicView` is hard-coded to root `Questions`, not the nested topic subcollection.

Legacy / risk notes:

- `fetchQuestions(forTopicIDs:level:)` ignores its `topicIDs` parameter and instead uses `getSTEMTopicIDs()`.
- `getSTEMTopicIDs()` filters Topics by `topic.name`, while question imports usually resolve topics by `topic.category`. That makes question lookup semantics inconsistent.
- `uploadQuestionsForChallenges()` does not check for existing question IDs before writing. Because document IDs are deterministic hashes of `questionText`, it can overwrite existing root `Questions` documents.
- The inline comment says `merge: false` is used "to avoid overwriting", but `setData(..., merge: false)` replaces the full document at that path.
- `loadQuestions()` exists in the challenge screen but is never called from the UI.

### 4. Nested `Topics/{topicId}/Questions`

Path:

- `Topics/{topicId}/Questions/{autoId}`

Observed fields:

- Not fixed by the model layer
- Whatever is passed into `uploadQuestion(topicID:questionData:)`

Query patterns:

- None

Write paths:

- `uploadQuestion(topicID:questionData:)` performs `addDocument(data:)` under `Topics/{topicId}/Questions`

Current usage notes:

- This path is not read anywhere in the app.
- This path is not deleted anywhere in the app.
- `uploadQuestion(...)` has no call sites in the repo, so the nested question path is effectively dead code from the current UI.

Legacy / migration note:

- `Topics/{topicId}/Questions` is a legacy path retained in code, but the operational question store for the current app is the root `Questions` collection.
- Any migration should treat the nested topic question subcollection as legacy data unless external clients still depend on it.

### 5. `challenges`

Path:

- `challenges/{challengeId}`

Document identity:

- `createChallenge(...)` uses `addDocument(from:)`, so the default write path uses auto-generated document IDs.

Observed fields:

- `type: String`
- `title: String`
- `description: String`
- `startDate: Timestamp/Date`
- `remainTime: Int?`
- `endDate: Timestamp/Date`
- `difficultyLevel: String` (encoded from `DifficultyLevel`)
- `questions: [String]`
- `rewards: [{type: String, value: Int, description: String?}]`
- `isActive: Bool`
- `createdAt: Timestamp/Date`
- `updatedAt: Timestamp/Date`

Query patterns:

- Current active challenges:
  - `where startDate <= now`
  - `where endDate >= now`
  - `orderBy startDate`
  - real-time listener
- Current active challenges by type:
  - `where type == <type>`
  - `where startDate <= now`
  - `where endDate >= now`
  - `orderBy startDate`
  - real-time listener

Write paths:

- Create challenge:
  - parse local challenge JSON
  - import referenced questions into root `Questions`
  - after a fixed 2-second delay, write a new `challenges` document containing the generated question IDs

Current usage notes:

- The challenge create screen is reachable from the sidebar.
- The challenge read/listener functions exist but are not currently wired to a visible screen in this admin app.

Legacy / risk notes:

- Challenge creation does not await the question batch commit. It waits a fixed 2 seconds, then reads `questionIDsImport` and writes the challenge. This is race-prone.
- The imported challenge JSON includes `difficultyLevel`, but the screen does not map that JSON value back into the picker state before writing the `Challenge` document. The final stored difficulty can therefore diverge from the source JSON.
- The selected topic UI in `AdminCreateChallengeView` is not used to scope the challenge import path that is actually executed.

### 6. `badges`

Path:

- `badges/{badgeId}`

Document identity:

- `createBadge(...)` uses `addDocument(from:)`, so generic create uses an auto-generated ID.
- `createListBadge(...)` can pin badge IDs by writing to `badges/{fixedId}`.

Observed fields:

- `title: String`
- `description: String`
- `icon: String`
- `criteria: {action, topic, accuracy, question, timeLimit, timeWindow, streak}`
- `createdAt: Timestamp/Date`
- `updatedAt: Timestamp/Date?`

Nested `criteria` fields:

- `action: String`
- `topic: String`
- `accuracy: Double`
- `question: Int`
- `timeLimit: Int?`
- `timeWindow: {startTime: String, endTime: String}?`
- `streak: Int?`

Query patterns:

- Fetch all badges sorted by `createdAt desc`
- Real-time listener

Write paths:

- Generic create:
  - `addDocument(from:)`
- Generic update:
  - `setData(from:)` on `badges/{badgeId}`
- Generic delete:
  - `delete()` on `badges/{badgeId}`
- Seed upload:
  - batch `setData(from:)` for a predefined badge list
  - uses fixed badge IDs when present

Current usage notes:

- The visible `Create Badge` screen does not call `createBadge(...)`.
- Pressing `Create Badge` from the current UI runs `uploadBadges()`, which bulk-seeds the predefined badge list instead of using the form inputs.

Legacy / risk notes:

- The badge form is currently preview-only; the actual write path is the seed upload.
- `fetchBadges()`, `createBadge(...)`, `updateBadge(...)`, and `deleteBadge(...)` exist but are not wired to the current UI.
- Badge accuracy semantics are inconsistent:
  - the manual form uses `0.0 ... 1.0`
  - the seeded badge data includes values like `80.0`, `90.0`, `95.0`
  - any consumer assuming normalized accuracy values will get mixed data.

## Legacy / Unwired Firestore Paths Summary

These paths or functions still exist in code but are not part of the current active UI flow:

- `Topics/{topicId}/Questions/{autoId}` via `uploadQuestion(...)`
- challenge listener reads in `ChallengesViewModel`
- generic badge CRUD/listener methods in `BadgesViewModel`
- `loadQuestions()` in `AdminCreateChallengeView`

## Migration-Relevant Conclusions

If the goal is to migrate or redesign production Firestore, the current app behavior implies:

1. The operational question source of truth is root `Questions`, not `Topics/{topicId}/Questions`.
2. Subject-to-topic linkage is partially denormalized:
   - `Subjects.topicIds` exists
   - the UI also derives membership by matching `topic.name == subject.name`
3. Topic writes are currently high-risk because the edit screen can corrupt `name` and `category`.
4. Challenge creation depends on root `Questions` IDs and is not transactionally safe.
5. The visible badge screen seeds a predefined catalog into `badges`; it is not a free-form badge editor yet.

## Recommended Follow-Ups

1. Freeze and verify the canonical data model for `Topics.name` vs `Topics.category`.
2. Decide whether `Subjects.topicIds` or name-based matching is the real relationship.
3. Treat nested `Topics/{topicId}/Questions` as legacy unless another client still reads it.
4. Fix the topic-edit and challenge-create write paths before running any schema migration.
5. Normalize badge `criteria.accuracy` semantics before downstream consumers depend on it.

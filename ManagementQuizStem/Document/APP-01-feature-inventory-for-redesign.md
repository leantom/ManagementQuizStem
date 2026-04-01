# ManagementQuizStem Feature Inventory

## Product Summary

`ManagementQuizStem` is a SwiftUI desktop admin app for managing quiz content stored in Firebase.

It is not a learner-facing quiz app. The current product is an internal content operations tool used to:

- create and maintain topics
- import questions from local files
- delete question sets by topic
- create challenge payloads
- seed or manage badge definitions
- create and update subjects

Core technical characteristics:

- SwiftUI app shell with sidebar navigation
- Firebase app configuration with `dev`, `beta`, and `prod` environments
- Firebase email/password admin authentication
- Firestore as the main database
- Firebase Storage for topic and subject icons
- local file import flows using `NSOpenPanel`

Main code entry points:

- `ManagementQuizStem/ManagementQuizStemApp.swift`
- `ManagementQuizStem/ContentView.swift`
- `ManagementQuizStem/AuthSessionController.swift`
- `ManagementQuizStem/FirebaseConfiguration.swift`

## Primary Navigation

The app currently exposes 7 sidebar actions:

1. Upload from CSV
2. Delete Questions by Topic ID
3. Edit Topics
4. Import Questions from Topics
5. Upload challenges
6. Create Badge
7. Create subject

Source: `ManagementQuizStem/ContentView.swift`

## Feature List By Area

### 1. App Bootstrapping And Access

Features:

- configures Firebase at app startup
- selects Firebase environment from runtime or `Info.plist`
- supports custom Firestore database IDs per environment
- shows a dedicated admin sign-in screen when no valid session exists
- signs in with Firebase email/password credentials
- supports admin allowlisting via configured email addresses
- blocks the main UI behind a loading state until auth is ready
- signs out invalid or unauthorized sessions
- exposes the current admin email and sign-out action in the main toolbar
- shows sign-in and session preparation errors inline

Why it matters for redesign:

- access control is currently invisible to users
- there is an explicit login screen now, but there is still no role view or environment indicator
- if this remains an internal admin tool, environment visibility should likely be part of the shell

Relevant files:

- `ManagementQuizStem/ManagementQuizStemApp.swift`
- `ManagementQuizStem/AdminSignInView.swift`
- `ManagementQuizStem/AuthSessionController.swift`
- `ManagementQuizStem/FirebaseConfiguration.swift`

### 2. Topic Import From CSV

Screen: `Upload Topics from CSV`

Features:

- opens a local file picker restricted to `.csv`
- parses CSV rows after skipping the header
- expects exactly 4 columns per row:
  - topic name
  - category
  - description
  - trending
- creates new topic documents in Firestore
- auto-generates topic IDs
- attempts duplicate prevention by checking existing topics with the same category
- shows success and error messages after upload
- provides a bulk action to update `educationLevel` for all existing topics

Observed implementation details:

- duplicate checking is based on topic `category`, not topic `name`
- education level is auto-classified from category names using hardcoded rules
- unknown categories default to `"Life Sciences"`

Relevant files:

- `ManagementQuizStem/Topics/UploadTopicView.swift`
- `ManagementQuizStem/Topics/TopicsViewModel.swift`

### 3. Topic Editing And Deletion

Screen: `Edit Topic`

Features:

- fetches all topics from Firestore
- lets admins pick an existing topic from a dropdown
- loads topic details into editable fields
- supports editing:
  - name
  - id display
  - description
  - trending score
  - icon
- lets admins pick a local image file for the topic icon
- uploads selected icon images to Firebase Storage
- updates the topic document with the new icon URL
- deletes a topic document from Firestore

Observed implementation details:

- the picker label says `Subject`, but it is selecting a topic
- the dropdown text shows `name - category`, but the selected value is topic ID
- when a topic is selected, the `name` field is populated with `category`, not with the topic name
- delete removes the topic document only; no cascade delete is implemented for related questions

Relevant files:

- `ManagementQuizStem/Topics/EditTopicView.swift`
- `ManagementQuizStem/Topics/TopicsViewModel.swift`

### 4. Question Import From JSON

Screen: `Import Questions from JSON`

Features:

- opens a local file picker restricted to `.json`
- imports a JSON array of questions
- previews imported questions in a list before upload
- displays question text, correct answer, and topic label
- uploads questions to Firestore in batch
- de-duplicates questions using a SHA-256 hash of `questionText`
- resolves each question’s topic by matching the imported `topic` field to topic category
- stores imported questions in the root `Questions` collection
- can optionally mirror imported questions into per-topic subcollections behind a feature flag

Question schema currently expected:

- `difficulty`
- `questionText`
- `options`
- `correctAnswer`
- `topic`
- `topicID` optional
- `explanation` optional

Observed implementation details:

- duplicate detection only considers `questionText`
- topic matching depends on exact category names in Firestore
- upload is file-driven only; there is no inline create or edit flow for a single question

Relevant files:

- `ManagementQuizStem/Questions/ImportQuestionsView.swift`
- `ManagementQuizStem/Questions/QuestionsViewModel.swift`
- `ManagementQuizStem/Firestore/FirestoreRepositories.swift`

### 5. Delete Questions By Topic ID

Screen: `Delete Questions by Topic ID`

Features:

- accepts manual topic ID input
- fetches all questions for that topic from Firestore
- previews the matched questions before deletion
- batch-deletes all matching question documents
- disables the delete action while deletion is in progress or when the result list is empty

Observed implementation details:

- deletion is based on the root `Questions` collection filtered by `topicID`
- there is no additional confirmation modal in the current UI
- there is no undo, backup prompt, or dependency warning

Relevant files:

- `ManagementQuizStem/Questions/DeleteQuestionsByTopicView.swift`
- `ManagementQuizStem/Questions/QuestionsViewModel.swift`

### 6. Challenge Creation

Screen: `Create a New Challenge`

Features:

- creates challenge documents in Firestore
- supports challenge types:
  - daily
  - weekly
- supports challenge difficulty levels:
  - beginner
  - intermediate
  - advanced
- captures:
  - title
  - description
  - start date
  - end date
  - rewards text display
- fetches and displays available topics for multi-select
- imports challenge definitions from a local JSON file
- reads challenge metadata from JSON and pre-fills the form
- uploads imported challenge questions first, then creates the challenge record
- stores question IDs on the challenge document

Challenge JSON currently includes:

- challenge metadata
- embedded question list
- rewards
- active status
- created/updated timestamps

Observed implementation details:

- the `Load Questions` button actually loads a challenge JSON file, not a question bank
- selected topics in the UI are not currently used by `createChallenge()`
- there is a `loadQuestions()` helper to query questions by selected topics and difficulty, but it is not wired to the button flow
- reward editing is effectively display-only because the saved challenge uses rewards from imported JSON
- question upload for challenges does not currently check Firestore for existing duplicates before writing

Relevant files:

- `ManagementQuizStem/Topics/ChallengesView.swift`
- `ManagementQuizStem/Topics/ChallengesViewModel.swift`
- `ManagementQuizStem/Questions/QuestionsViewModel.swift`

### 7. Badge Seeding And Badge Preview

Screen: `Create a New Badge`

Features:

- provides a badge form for:
  - title
  - description
  - icon
  - action
  - topic
  - accuracy
  - created date
- previews a single badge card in the UI
- includes repository methods to fetch, create, update, and delete badges
- includes a bulk seed action that uploads a predefined badge catalog to Firestore

Observed implementation details:

- the primary `Create Badge` button currently calls `uploadBadges()`, which seeds a predefined badge set
- the values typed into the form are only used for preview unless the code is changed
- badge criteria support:
  - action
  - topic
  - accuracy threshold
  - question count
  - time limit
  - time window
  - streak

Relevant files:

- `ManagementQuizStem/Topics/Badge/CreateBadgeView.swift`
- `ManagementQuizStem/Topics/Badge/BadgesViewModel.swift`
- `ManagementQuizStem/Topics/Badge/Badge.swift`

### 8. Subject Creation And Subject Update

Screen: `Create New Subject`

Features:

- fetches all existing subjects
- fetches all topics
- lets admins select an existing subject to prefill the form
- supports creating a new subject
- supports updating an existing subject
- supports editing:
  - name
  - short name
  - description
  - icon URL / uploaded icon
- uploads subject icons to Firebase Storage
- displays a list of all subjects with thumbnails and trending scores
- displays a related topic list for the selected subject
- stores associated topic IDs on the subject record when updating

Observed implementation details:

- existing/duplicate detection is based on subject name
- related topics are derived by matching `topic.name == subject.name`
- topic associations are added on update with `arrayUnion`
- create and update are combined into one screen

Relevant files:

- `ManagementQuizStem/Subjects/CreateNewSubjectView.swift`
- `ManagementQuizStem/Subjects/Subject.swift`
- `ManagementQuizStem/Topics/TopicsViewModel.swift`

## Supporting Data Model

Main Firestore collections:

- `Subjects`
- `Topics`
- `Questions`
- `challenges`
- `badges`

High-level relationships:

- a subject can reference many topic IDs
- a question belongs to one topic via `topicID`
- a challenge stores many question IDs
- badge documents store rule criteria for downstream learner achievements

Relevant files:

- `ManagementQuizStem/Firestore/FirestorePaths.swift`
- `ManagementQuizStem/Firestore/FirestoreRepositories.swift`

## Secondary Or Incomplete Features In Code

These exist in code but are not fully surfaced as complete product features:

- listener-based fetching for current active challenges
- listener-based fetching for challenges filtered by type
- listener-based fetching for badges
- challenge detail screen with a `Start Challenge` button stub
- a separate `EditSubjectView` file that is not connected to the main navigation
- `AppState` singleton used to cache topics and selected difficulty

This matters for redesign because the app likely has partial feature ideas that were started but not completed.

Relevant files:

- `ManagementQuizStem/Topics/ChallengeDetailView.swift`
- `ManagementQuizStem/Topics/EditSubjectView.swift`
- `ManagementQuizStem/Questions/AppState.swift`

## Redesign Implications

### Current Product Positioning

The app behaves like a desktop content operations console for a quiz platform. The redesign should treat it as an internal CMS, not as a learner product.

### Main UX Patterns Today

- file-driven content ingestion
- direct Firestore write operations
- minimal validation and guardrails
- technical terminology exposed directly to operators
- a flat sidebar with separate one-off admin tools

### Clear Pain Points To Address

1. Terminology is inconsistent.
   - `subject`, `topic`, `category`, and `topic ID` are used in overlapping ways.

2. Several screens combine unrelated jobs.
   - Example: the subject screen handles creation, editing, icon upload, and topic association in one place.

3. File imports lack strong visibility into schema requirements.
   - CSV and JSON formats are implicit in code, not explained in the UI.

4. Destructive actions are under-protected.
   - Question deletion has no confirmation or rollback path in the interface.

5. Some UI controls are misleading.
   - Example: challenge topic selection is shown even though the active create flow depends on imported JSON.
   - Example: badge creation form suggests custom badge creation, but the main action seeds predefined badges.

6. Success and error feedback is shallow.
   - There is little progress reporting, no import summaries, and no audit history.

### Recommended Information Architecture For Redesign

A cleaner redesign could group the product into these modules:

- Dashboard
  - environment status
  - recent imports
  - content counts
  - failed jobs

- Content Library
  - Subjects
  - Topics
  - Questions

- Imports
  - Topic CSV import
  - Question JSON import
  - Challenge package import

- Challenges
  - create
  - preview
  - active schedule

- Rewards
  - badges
  - badge rules

- Admin Tools
  - destructive maintenance tasks
  - environment tools
  - data repair tools

## Short Redesign Summary

If the redesign goal is clarity and operational safety, the biggest opportunities are:

- make the app explicitly feel like a content management tool
- consolidate topic, subject, and question management into a coherent content structure
- separate import workflows from manual editing workflows
- add validation, previews, confirmations, and post-action summaries
- remove misleading controls or wire them fully into the underlying behavior

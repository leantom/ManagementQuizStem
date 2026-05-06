# DB-03 Brain Training Firestore Upgrade

## Target collections

The admin app now writes adaptive brain-training questions to:

- `questions/{questionId}`
- `users/{userId}`
- `learningPaths/{pathId}`
- `dailyChallenges/{challengeId}`

Legacy collections that still exist in the app for admin/back-office workflows:

- `Subjects/{subjectId}`
- `Topics/{topicId}`
- `challenges/{challengeId}`
- `badges/{badgeId}`
- `satExamQuestions/{questionId}`

Legacy question paths during migration:

- `Questions/{questionId}` is the old root collection and should be treated as read-only once clients move to `questions`.
- `Topics/{topicId}/Questions/{questionId}` is the old nested topic-question collection.
- `Topics/{topicId}/questions/{questionId}` is only used if `FIRESTORE_MIRROR_IMPORTED_QUESTIONS` is enabled.

## `questions` schema

Each new or imported question writes these fields:

- `source: string`
- `externalId: string`
- `isVerified: boolean`
- `scientificDomain: string`
- `didYouKnow: string`
- `questionText: string`
- `options: array<string>`
- `correctAnswer: string`
- `topicID: string`
- `difficulty: string`
- `cognitiveSkills: array<string>`
- `eloRating: number`

- `hints: array<string>`
- `explanation: string`
- `realWorldContext: string`

Notes:

- `source` and `externalId` identify API-originated questions, for example `source: "opentdb"`. Imports skip rows when an existing `questions` document has the same source/external ID pair.
- `isVerified` marks questions that have been manually edited or fact-checked.
- `scientificDomain` is the adult-focused grouping shown in the learning experience, replacing school-subject-first classification with broader themes such as `Nature`, `Space`, `Logic`, `Health`, and `Technology`.
- `didYouKnow` stores the post-answer fun fact.
- `difficulty` is retained as a legacy/admin label.
- `eloRating` is the primary adaptive difficulty value. The admin app validates manual ELO values from `800...2500`.
- JSON imports that do not include the new fields still work. Defaults are `source: ""`, `externalId: ""`, `isVerified: false`, `scientificDomain` inferred from cognitive skill, `didYouKnow: ""`, `cognitiveSkills: ["logic"]`, `eloRating` inferred from `difficulty`, `hints: []`, and `realWorldContext: ""`.
- Question document IDs still use `SHA256(questionText)` for deterministic duplicate detection.

## `users` schema

The app model expects:

- `mentalRadar: map<string, number>`
- `streak.currentStreak: number`
- `streak.longestStreak: number`
- `streak.lastActiveDate: string`
- `unlocks: array<string>`
- `preferences.goals: array<string>`
- `preferences.focusSkills: array<string>`
- `preferences.preferredDifficultyELO: number`

## `learningPaths` schema

The app model expects:

- `title: string`
- `description: string`
- `difficulty: string`
- `steps: array<map>`
- `createdAt: timestamp`
- `updatedAt: timestamp`

Each step supports:

- `title: string`
- `questionIds: array<string>`
- `cognitiveSkills: array<string>`
- `targetELO: number`

## `dailyChallenges` schema

The app model expects:

- `date: string` using `YYYY-MM-DD`
- `questionId: reference` pointing to `questions/{questionId}`
- `globalStats.totalAttempts: number`
- `globalStats.correctAttempts: number`
- `globalStats.optionDistribution: map<string, number>`

## Firestore rules

Use this ruleset after adding the brain-training collections. It keeps the existing permissive admin rules for `Subjects` and `Topics`, keeps legacy question paths available during migration, and adds `learningPaths`, `dailyChallenges`, and `satExamQuestions`.

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    match /Subjects/{doc} {
      allow read, write: if true;
    }

    match /Topics/{topicId} {
      allow read, write: if true;

      match /Questions/{questionId} {
        allow read, write: if true;
      }

      match /questions/{questionId} {
        allow read, write: if signedIn();
      }
    }

    match /Questions/{doc} {
      allow read, write: if signedIn();
    }

    match /questions/{doc} {
      allow read, write: if signedIn();
    }

    match /learningPaths/{pathId} {
      allow read, write: if signedIn();
    }

    match /dailyChallenges/{challengeId} {
      allow read, write: if signedIn();
    }

    match /challenges/{doc} {
      allow read, write: if signedIn();
    }

    match /badges/{doc} {
      allow read, write: if signedIn();
    }

    match /satExamQuestions/{questionId} {
      allow read, write: if signedIn();
    }

    match /quizzes/{doc} {
      allow read, write: if signedIn();
    }

    match /leaderboards/{boardId} {
      allow read: if signedIn();
      allow write: if false;

      match /entries/{entryUserId} {
        allow read: if signedIn();
        allow write: if false;
      }
    }

    match /users/{userId} {
      allow read, write: if signedIn() && request.auth.uid == userId;

      match /{subcollection=**}/{docId} {
        allow read, write: if signedIn() && request.auth.uid == userId;
      }
    }
  }
}
```

## Migration checklist

1. Export the current Firestore database before changing production traffic.
2. Copy legacy `Questions/{questionId}` documents into `questions/{questionId}`.
3. Backfill missing question metadata:
   - `source` and `externalId` for API-originated rows where the provider ID is known.
   - `isVerified` as `false` until a manual review is completed.
   - `scientificDomain` from cognitive skill, topic/category, or AI tagging.
   - `didYouKnow` as an empty string until fun facts are generated.
   - `cognitiveSkills` from topic/category or AI tagging.
   - `eloRating` from the old difficulty label.
   - `hints` as an empty array until Socratic hints are generated.
   - `realWorldContext` as an empty string until content enrichment is done.
4. Create first `learningPaths` documents using existing question IDs.
5. Create one `dailyChallenges/{YYYY-MM-DD}` document with a `questionId` reference into `questions`.
6. Publish the updated Firestore rules above.
7. Keep legacy `Questions` read-only until all client apps have been updated to read `questions`.

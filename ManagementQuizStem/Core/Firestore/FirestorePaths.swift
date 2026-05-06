//
//  FirestorePaths.swift
//  ManagementQuizStem
//
//  Created by Codex on 01/04/26.
//

import Foundation
import FirebaseFirestore

enum FirestoreCollection: String {
    case subjects = "Subjects"
    case topics = "Topics"
    case questions = "questions"
    case users = "users"
    case learningPaths = "learningPaths"
    case dailyChallenges = "dailyChallenges"
    case challenges = "challenges"
    case satExamQuestions = "satExamQuestions"
    case badges = "badges"
}

enum FirestoreField {
    enum Subject {
        static let name = "name"
        static let shortName = "short_name"
        static let description = "description"
        static let trending = "trending"
        static let iconURL = "icon_url"
        static let colorHex = "color_hex"
        static let topicIDs = "topicIds"
    }

    enum Topic {
        static let id = "id"
        static let name = "name"
        static let category = "category"
        static let description = "description"
        static let trending = "trending"
        static let iconURL = "iconURL"
        static let educationLevel = "educationLevel"
    }

    enum Question {
        static let source = "source"
        static let externalID = "externalId"
        static let isVerified = "isVerified"
        static let scientificDomain = "scientificDomain"
        static let didYouKnow = "didYouKnow"
        static let difficulty = "difficulty"
        static let questionText = "questionText"
        static let options = "options"
        static let correctAnswer = "correctAnswer"
        static let topicID = "topicID"
        static let cognitiveSkills = "cognitiveSkills"
        static let eloRating = "eloRating"
        static let hints = "hints"
        static let explanation = "explanation"
        static let realWorldContext = "realWorldContext"
    }

    enum User {
        static let mentalRadar = "mentalRadar"
        static let streak = "streak"
        static let unlocks = "unlocks"
        static let preferences = "preferences"
    }

    enum LearningPath {
        static let title = "title"
        static let difficulty = "difficulty"
        static let createdAt = "createdAt"
    }

    enum DailyChallenge {
        static let date = "date"
        static let questionID = "questionId"
    }

    enum Challenge {
        static let type = "type"
        static let startDate = "startDate"
        static let endDate = "endDate"
        static let createdAt = "createdAt"
    }

    enum SATExamQuestion {
        static let domain = "domain"
        static let difficulty = "difficulty"
        static let createdAt = "createdAt"
    }

    enum Badge {
        static let createdAt = "createdAt"
    }
}

enum FirestoreFeatureFlags {
    static var mirrorImportedQuestionsToTopicSubcollections: Bool {
        boolFlag(named: "FIRESTORE_MIRROR_IMPORTED_QUESTIONS")
    }

    private static func boolFlag(
        named key: String,
        bundle: Bundle = .main
    ) -> Bool {
        if let runtimeValue = ProcessInfo.processInfo.environment[key] {
            return parseBool(runtimeValue)
        }

        if let configuredValue = bundle.object(forInfoDictionaryKey: key) as? String {
            return parseBool(configuredValue)
        }

        if let configuredValue = bundle.object(forInfoDictionaryKey: key) as? NSNumber {
            return configuredValue.boolValue
        }

        return false
    }

    private static func parseBool(_ rawValue: String) -> Bool {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }
}

enum FirestorePaths {
    static func subjects(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.subjects.rawValue)
    }

    static func subject(_ subjectID: String, in db: Firestore) -> DocumentReference {
        subjects(in: db).document(subjectID)
    }

    static func topics(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.topics.rawValue)
    }

    static func topic(_ topicID: String, in db: Firestore) -> DocumentReference {
        topics(in: db).document(topicID)
    }

    static func rootQuestions(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.questions.rawValue)
    }

    static func rootQuestion(_ questionID: String, in db: Firestore) -> DocumentReference {
        rootQuestions(in: db).document(questionID)
    }

    static func users(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.users.rawValue)
    }

    static func user(_ userID: String, in db: Firestore) -> DocumentReference {
        users(in: db).document(userID)
    }

    static func learningPaths(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.learningPaths.rawValue)
    }

    static func learningPath(_ pathID: String, in db: Firestore) -> DocumentReference {
        learningPaths(in: db).document(pathID)
    }

    static func dailyChallenges(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.dailyChallenges.rawValue)
    }

    static func dailyChallenge(_ challengeID: String, in db: Firestore) -> DocumentReference {
        dailyChallenges(in: db).document(challengeID)
    }

    static func topicQuestions(topicID: String, in db: Firestore) -> CollectionReference {
        topic(topicID, in: db).collection(FirestoreCollection.questions.rawValue)
    }

    static func topicQuestion(
        topicID: String,
        questionID: String,
        in db: Firestore
    ) -> DocumentReference {
        topicQuestions(topicID: topicID, in: db).document(questionID)
    }

    static func challenges(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.challenges.rawValue)
    }

    static func challenge(_ challengeID: String, in db: Firestore) -> DocumentReference {
        challenges(in: db).document(challengeID)
    }

    static func satExamQuestions(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.satExamQuestions.rawValue)
    }

    static func satExamQuestion(_ questionID: String, in db: Firestore) -> DocumentReference {
        satExamQuestions(in: db).document(questionID)
    }

    static func badges(in db: Firestore) -> CollectionReference {
        db.collection(FirestoreCollection.badges.rawValue)
    }

    static func badge(_ badgeID: String, in db: Firestore) -> DocumentReference {
        badges(in: db).document(badgeID)
    }
}

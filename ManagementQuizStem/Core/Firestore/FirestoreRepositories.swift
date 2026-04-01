//
//  FirestoreRepositories.swift
//  ManagementQuizStem
//
//  Created by Codex on 01/04/26.
//

import Foundation
import FirebaseFirestore

private extension QuerySnapshot {
    func decodedDocuments<T: Decodable>(as type: T.Type = T.self) -> [T] {
        documents.compactMap { document in
            try? document.data(as: T.self)
        }
    }
}

protocol FirestoreRepository {
    var db: Firestore { get }
}

extension FirestoreRepository {
    func makeBatch() -> WriteBatch {
        db.batch()
    }
}

struct SubjectsRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func fetchAll(completion: @escaping (Result<[Subject], Error>) -> Void) {
        FirestorePaths.subjects(in: db)
            .order(by: FirestoreField.Subject.trending, descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.decodedDocuments(as: Subject.self) ?? []))
            }
    }

    func checkExists(
        named subjectName: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        FirestorePaths.subjects(in: db)
            .whereField(FirestoreField.Subject.name, isEqualTo: subjectName)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                completion(.success(!(snapshot?.documents.isEmpty ?? true)))
            }
    }

    func create(_ subject: Subject, completion: @escaping (Error?) -> Void) throws {
        guard let subjectID = subject.id else {
            completion(NSError(domain: "SubjectsRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Subject ID is missing."
            ]))
            return
        }

        try FirestorePaths.subject(subjectID, in: db).setData(from: subject, completion: completion)
    }

    func update(
        subjectID: String,
        data: [String: Any],
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.subject(subjectID, in: db).updateData(data, completion: completion)
    }
}

struct TopicsRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func fetchAll(completion: @escaping (Result<[Topic], Error>) -> Void) {
        FirestorePaths.topics(in: db)
            .order(by: FirestoreField.Topic.category)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.decodedDocuments(as: Topic.self) ?? []))
            }
    }

    func fetchAll() async throws -> [Topic] {
        let snapshot = try await FirestorePaths.topics(in: db)
            .order(by: FirestoreField.Topic.category)
            .getDocuments()
        return snapshot.decodedDocuments(as: Topic.self)
    }

    func create(
        topicID: String,
        data: [String: Any],
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.topic(topicID, in: db).setData(data, completion: completion)
    }

    func update(
        topicID: String,
        data: [String: Any],
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.topic(topicID, in: db).updateData(data, completion: completion)
    }

    func updateEducationLevel(
        topicID: String,
        educationLevel: String,
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.topic(topicID, in: db).updateData([
            FirestoreField.Topic.educationLevel: educationLevel
        ], completion: completion)
    }

    func delete(topicID: String, completion: @escaping (Error?) -> Void) {
        FirestorePaths.topic(topicID, in: db).delete(completion: completion)
    }
}

struct QuestionsRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func uploadQuestionToTopicSubcollection(
        topicID: String,
        data: [String: Any],
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.topicQuestions(topicID: topicID, in: db).addDocument(data: data, completion: completion)
    }

    func fetchQuestions(topicID: String) async throws -> [Question] {
        let snapshot = try await FirestorePaths.rootQuestions(in: db)
            .whereField(FirestoreField.Question.topicID, isEqualTo: topicID)
            .getDocuments()
        return snapshot.decodedDocuments(as: Question.self)
    }

    func fetchQuestions(
        topicID: String,
        completion: @escaping (Result<[Question], Error>) -> Void
    ) {
        FirestorePaths.rootQuestions(in: db)
            .whereField(FirestoreField.Question.topicID, isEqualTo: topicID)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.decodedDocuments(as: Question.self) ?? []))
            }
    }

    func deleteQuestions(topicID: String) async throws {
        let snapshot = try await FirestorePaths.rootQuestions(in: db)
            .whereField(FirestoreField.Question.topicID, isEqualTo: topicID)
            .getDocuments()

        let batch = makeBatch()
        snapshot.documents.forEach { document in
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()
    }

    func deleteQuestions(
        topicID: String,
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.rootQuestions(in: db)
            .whereField(FirestoreField.Question.topicID, isEqualTo: topicID)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(error)
                    return
                }

                let batch = makeBatch()
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }

                batch.commit(completion: completion)
            }
    }

    func fetchQuestions(
        level: String,
        topicIDs: [String],
        limit: Int = 15
    ) async throws -> [Question] {
        let snapshot = try await FirestorePaths.rootQuestions(in: db)
            .whereField(FirestoreField.Question.difficulty, isEqualTo: level)
            .whereField(FirestoreField.Question.topicID, in: topicIDs)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: Question.self)
        }
    }

    func fetchExistingQuestionIDs(
        _ questionIDs: [String],
        completion: @escaping (Result<Set<String>, Error>) -> Void
    ) {
        var existingIDs = Set<String>()
        let lock = NSLock()
        let batchSize = 10
        let batches = stride(from: 0, to: questionIDs.count, by: batchSize).map {
            Array(questionIDs[$0..<min($0 + batchSize, questionIDs.count)])
        }

        if batches.isEmpty {
            completion(.success(existingIDs))
            return
        }

        let dispatchGroup = DispatchGroup()
        var capturedError: Error?

        for batch in batches {
            dispatchGroup.enter()
            FirestorePaths.rootQuestions(in: db)
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { snapshot, error in
                    defer { dispatchGroup.leave() }

                    if let error = error {
                        lock.lock()
                        capturedError = error
                        lock.unlock()
                        return
                    }

                    lock.lock()
                    snapshot?.documents.forEach { doc in
                        existingIDs.insert(doc.documentID)
                    }
                    lock.unlock()
                }
        }

        dispatchGroup.notify(queue: .main) {
            if let capturedError = capturedError {
                completion(.failure(capturedError))
            } else {
                completion(.success(existingIDs))
            }
        }
    }

    func importedQuestionReferences(
        topicID: String,
        questionID: String
    ) -> [DocumentReference] {
        var references = [
            FirestorePaths.rootQuestion(questionID, in: db)
        ]

        // This flag allows a migration period where imported questions are mirrored
        // into topic subcollections without changing the current root-question reads.
        if FirestoreFeatureFlags.mirrorImportedQuestionsToTopicSubcollections {
            references.append(
                FirestorePaths.topicQuestion(
                    topicID: topicID,
                    questionID: questionID,
                    in: db
                )
            )
        }

        return references
    }

    func addImportedQuestion(
        to batch: WriteBatch,
        topicID: String,
        questionID: String,
        data: [String: Any]
    ) {
        for reference in importedQuestionReferences(topicID: topicID, questionID: questionID) {
            batch.setData(data, forDocument: reference, merge: false)
        }
    }

    func commit(_ batch: WriteBatch, completion: @escaping (Error?) -> Void) {
        batch.commit(completion: completion)
    }
}

struct ChallengesRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func listenForCurrentChallenges(
        now: Date = Date(),
        onUpdate: @escaping (Result<[Challenge], Error>) -> Void
    ) -> ListenerRegistration {
        FirestorePaths.challenges(in: db)
            .whereField(FirestoreField.Challenge.startDate, isLessThanOrEqualTo: now)
            .whereField(FirestoreField.Challenge.endDate, isGreaterThanOrEqualTo: now)
            .order(by: FirestoreField.Challenge.startDate)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onUpdate(.failure(error))
                    return
                }

                onUpdate(.success(snapshot?.decodedDocuments(as: Challenge.self) ?? []))
            }
    }

    func listenForChallenges(
        ofType type: String,
        now: Date = Date(),
        onUpdate: @escaping (Result<[Challenge], Error>) -> Void
    ) -> ListenerRegistration {
        FirestorePaths.challenges(in: db)
            .whereField(FirestoreField.Challenge.type, isEqualTo: type)
            .whereField(FirestoreField.Challenge.startDate, isLessThanOrEqualTo: now)
            .whereField(FirestoreField.Challenge.endDate, isGreaterThanOrEqualTo: now)
            .order(by: FirestoreField.Challenge.startDate)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onUpdate(.failure(error))
                    return
                }

                onUpdate(.success(snapshot?.decodedDocuments(as: Challenge.self) ?? []))
            }
    }

    func create(_ challenge: Challenge, completion: @escaping (Error?) -> Void) throws {
        try FirestorePaths.challenges(in: db).addDocument(from: challenge, completion: completion)
    }
}

struct BadgesRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func listenForBadges(
        onUpdate: @escaping (Result<[Badge], Error>) -> Void
    ) -> ListenerRegistration {
        FirestorePaths.badges(in: db)
            .order(by: FirestoreField.Badge.createdAt, descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onUpdate(.failure(error))
                    return
                }

                onUpdate(.success(snapshot?.decodedDocuments(as: Badge.self) ?? []))
            }
    }

    func create(_ badge: Badge, completion: @escaping (Error?) -> Void) throws {
        try FirestorePaths.badges(in: db).addDocument(from: badge, completion: completion)
    }

    func update(_ badge: Badge, completion: @escaping (Error?) -> Void) throws {
        guard let badgeID = badge.id else {
            completion(NSError(domain: "BadgesRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Badge ID is missing."
            ]))
            return
        }

        try FirestorePaths.badge(badgeID, in: db).setData(from: badge, completion: completion)
    }

    func delete(badgeID: String, completion: @escaping (Error?) -> Void) {
        FirestorePaths.badge(badgeID, in: db).delete(completion: completion)
    }

    func createListBadge(
        badges: [Badge],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let batch = makeBatch()

        for badge in badges {
            let documentRef: DocumentReference
            if let badgeID = badge.id {
                documentRef = FirestorePaths.badge(badgeID, in: db)
            } else {
                documentRef = FirestorePaths.badges(in: db).document()
            }

            do {
                try batch.setData(from: badge, forDocument: documentRef)
            } catch {
                completion(.failure(error))
                return
            }
        }

        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

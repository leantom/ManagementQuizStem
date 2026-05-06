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

    func countDocuments(
        in query: Query,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        query.count.getAggregation(source: .server) { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            completion(.success(Int(truncating: snapshot?.count ?? 0)))
        }
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

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.subjects(in: db), completion: completion)
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

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.topics(in: db), completion: completion)
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

    func fetchAllQuestions(
        completion: @escaping (Result<[Question], Error>) -> Void
    ) {
        FirestorePaths.rootQuestions(in: db)
            .getDocuments { snapshot, error in
                if let error {
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

    func fetchExistingExternalQuestionKeys(
        _ externalQuestionKeys: [String: Set<String>],
        completion: @escaping (Result<Set<String>, Error>) -> Void
    ) {
        var existingKeys = Set<String>()
        let lock = NSLock()
        let dispatchGroup = DispatchGroup()
        var capturedError: Error?

        for (source, externalIDs) in externalQuestionKeys {
            let cleanedExternalIDs = Array(externalIDs.filter { $0.isEmpty == false })
            let batches = stride(from: 0, to: cleanedExternalIDs.count, by: 10).map {
                Array(cleanedExternalIDs[$0..<min($0 + 10, cleanedExternalIDs.count)])
            }

            for batch in batches {
                dispatchGroup.enter()
                FirestorePaths.rootQuestions(in: db)
                    .whereField(FirestoreField.Question.source, isEqualTo: source)
                    .whereField(FirestoreField.Question.externalID, in: batch)
                    .getDocuments { snapshot, error in
                        defer { dispatchGroup.leave() }

                        if let error {
                            lock.lock()
                            capturedError = error
                            lock.unlock()
                            return
                        }

                        lock.lock()
                        snapshot?.documents.forEach { document in
                            if let externalID = document.data()[FirestoreField.Question.externalID] as? String {
                                existingKeys.insert("\(source):\(externalID)")
                            }
                        }
                        lock.unlock()
                    }
            }
        }

        if externalQuestionKeys.isEmpty {
            completion(.success(existingKeys))
            return
        }

        dispatchGroup.notify(queue: .main) {
            if let capturedError {
                completion(.failure(capturedError))
            } else {
                completion(.success(existingKeys))
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

    func replaceQuestion(
        existingQuestionID: String?,
        existingTopicID: String?,
        newQuestionID: String,
        newTopicID: String,
        data: [String: Any],
        completion: @escaping (Error?) -> Void
    ) {
        let batch = makeBatch()

        if let existingQuestionID, existingQuestionID != newQuestionID {
            batch.deleteDocument(FirestorePaths.rootQuestion(existingQuestionID, in: db))
        }

        if let existingQuestionID, let existingTopicID,
           existingTopicID != newTopicID || existingQuestionID != newQuestionID {
            batch.deleteDocument(
                FirestorePaths.topicQuestion(
                    topicID: existingTopicID,
                    questionID: existingQuestionID,
                    in: db
                )
            )
        }

        for reference in importedQuestionReferences(topicID: newTopicID, questionID: newQuestionID) {
            batch.setData(data, forDocument: reference, merge: false)
        }

        batch.commit(completion: completion)
    }

    func deleteQuestion(
        questionID: String,
        topicID: String?,
        completion: @escaping (Error?) -> Void
    ) {
        let batch = makeBatch()
        batch.deleteDocument(FirestorePaths.rootQuestion(questionID, in: db))

        if let topicID, topicID.isEmpty == false {
            batch.deleteDocument(
                FirestorePaths.topicQuestion(
                    topicID: topicID,
                    questionID: questionID,
                    in: db
                )
            )
        }

        batch.commit(completion: completion)
    }

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.rootQuestions(in: db), completion: completion)
    }

    func countQuestions(
        topicIDs: [String],
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let uniqueTopicIDs = Array(Set(topicIDs)).filter { !$0.isEmpty }

        guard uniqueTopicIDs.isEmpty == false else {
            completion(.success(0))
            return
        }

        let batchSize = 10
        let batches = stride(from: 0, to: uniqueTopicIDs.count, by: batchSize).map {
            Array(uniqueTopicIDs[$0..<min($0 + batchSize, uniqueTopicIDs.count)])
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var totalCount = 0
        var capturedError: Error?

        for batch in batches {
            group.enter()
            let query = FirestorePaths.rootQuestions(in: db)
                .whereField(FirestoreField.Question.topicID, in: batch)

            countDocuments(in: query) { result in
                defer { group.leave() }

                lock.lock()
                defer { lock.unlock() }

                switch result {
                case .success(let count):
                    totalCount += count
                case .failure(let error):
                    capturedError = error
                }
            }
        }

        group.notify(queue: .main) {
            if let capturedError {
                completion(.failure(capturedError))
            } else {
                completion(.success(totalCount))
            }
        }
    }
}

struct UsersRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func fetchProfile(
        userID: String,
        completion: @escaping (Result<BrainTrainingUserProfile?, Error>) -> Void
    ) {
        FirestorePaths.user(userID, in: db).getDocument { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            completion(.success(try? snapshot?.data(as: BrainTrainingUserProfile.self)))
        }
    }

    func upsertProfile(
        _ profile: BrainTrainingUserProfile,
        userID: String,
        completion: @escaping (Error?) -> Void
    ) throws {
        try FirestorePaths.user(userID, in: db).setData(from: profile, merge: true, completion: completion)
    }

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.users(in: db), completion: completion)
    }
}

struct LearningPathsRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func fetchAll(completion: @escaping (Result<[LearningPath], Error>) -> Void) {
        FirestorePaths.learningPaths(in: db)
            .order(by: FirestoreField.LearningPath.createdAt, descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.decodedDocuments(as: LearningPath.self) ?? []))
            }
    }

    func create(_ path: LearningPath, completion: @escaping (Error?) -> Void) throws {
        if let pathID = path.id, pathID.isEmpty == false {
            try FirestorePaths.learningPath(pathID, in: db).setData(from: path, completion: completion)
        } else {
            try FirestorePaths.learningPaths(in: db).addDocument(from: path, completion: completion)
        }
    }

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.learningPaths(in: db), completion: completion)
    }
}

struct DailyChallengesRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func fetchByDate(
        _ date: String,
        completion: @escaping (Result<DailyChallenge?, Error>) -> Void
    ) {
        FirestorePaths.dailyChallenges(in: db)
            .whereField(FirestoreField.DailyChallenge.date, isEqualTo: date)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.decodedDocuments(as: DailyChallenge.self).first))
            }
    }

    func upsert(
        _ challenge: DailyChallenge,
        challengeID: String,
        completion: @escaping (Error?) -> Void
    ) throws {
        try FirestorePaths.dailyChallenge(challengeID, in: db)
            .setData(from: challenge, merge: true, completion: completion)
    }

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.dailyChallenges(in: db), completion: completion)
    }
}

struct ChallengesRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func listenForAllChallenges(
        onUpdate: @escaping (Result<[Challenge], Error>) -> Void
    ) -> ListenerRegistration {
        FirestorePaths.challenges(in: db)
            .order(by: FirestoreField.Challenge.startDate, descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onUpdate(.failure(error))
                    return
                }

                onUpdate(.success(snapshot?.decodedDocuments(as: Challenge.self) ?? []))
            }
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

    func fetchCurrentChallengesPreview(
        now: Date = Date(),
        limit: Int = 3,
        completion: @escaping (Result<[Challenge], Error>) -> Void
    ) {
        FirestorePaths.challenges(in: db)
            .whereField(FirestoreField.Challenge.startDate, isLessThanOrEqualTo: now)
            .whereField(FirestoreField.Challenge.endDate, isGreaterThanOrEqualTo: now)
            .order(by: FirestoreField.Challenge.startDate)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.decodedDocuments(as: Challenge.self) ?? []))
            }
    }

    func countCurrentChallenges(
        now: Date = Date(),
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let query = FirestorePaths.challenges(in: db)
            .whereField(FirestoreField.Challenge.startDate, isLessThanOrEqualTo: now)
            .whereField(FirestoreField.Challenge.endDate, isGreaterThanOrEqualTo: now)

        countDocuments(in: query, completion: completion)
    }

    func create(_ challenge: Challenge, completion: @escaping (Error?) -> Void) throws {
        try FirestorePaths.challenges(in: db).addDocument(from: challenge, completion: completion)
    }
}

struct SATExamQuestionsRepository: FirestoreRepository {
    let db: Firestore

    init(db: Firestore = AppFirestore.database()) {
        self.db = db
    }

    func fetchAll(completion: @escaping (Result<[SATExamQuestion], Error>) -> Void) {
        FirestorePaths.satExamQuestions(in: db)
            .order(by: FirestoreField.SATExamQuestion.createdAt, descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.decodedDocuments(as: SATExamQuestion.self) ?? []))
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
            FirestorePaths.satExamQuestions(in: db)
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { snapshot, error in
                    defer { dispatchGroup.leave() }

                    if let error {
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
            if let capturedError {
                completion(.failure(capturedError))
            } else {
                completion(.success(existingIDs))
            }
        }
    }

    func addImportedQuestion(
        to batch: WriteBatch,
        question: SATExamQuestion
    ) throws {
        guard let questionID = question.id, questionID.isEmpty == false else {
            throw NSError(domain: "SATExamQuestionsRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "SAT exam question ID is missing."
            ])
        }

        try batch.setData(
            from: question,
            forDocument: FirestorePaths.satExamQuestion(questionID, in: db),
            merge: true
        )
    }

    func commit(_ batch: WriteBatch, completion: @escaping (Error?) -> Void) {
        batch.commit(completion: completion)
    }

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.satExamQuestions(in: db), completion: completion)
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

    func countAll(completion: @escaping (Result<Int, Error>) -> Void) {
        countDocuments(in: FirestorePaths.badges(in: db), completion: completion)
    }
}

//
//  QuestionsViewModel.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 15/11/24.
//


import SwiftUI
import FirebaseFirestore
import CryptoKit

struct Question: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var source: String?
    var externalId: String?
    var isVerified: Bool?
    var scientificDomain: String?
    var didYouKnow: String?
    var difficulty: String
    var questionText: String
    var options: [String]
    var correctAnswer: String
    var topic: String?
    var topicID: String?
    var cognitiveSkills: [String]?
    var eloRating: Int?
    var hints: [String]?
    var explanation: String?
    var realWorldContext: String?
}

struct QuestionImport: Identifiable, Codable {
    var id = UUID()

    var source: String?
    var externalId: String?
    var isVerified: Bool?
    var scientificDomain: String?
    var didYouKnow: String?
    var difficulty: String
    var questionText: String
    var options: [String]
    var correctAnswer: String
    var topic: String?
    var topicID: String?
    var cognitiveSkills: [String]?
    var eloRating: Int?
    var hints: [String]?
    var explanation: String?
    var realWorldContext: String?

    enum CodingKeys: String, CodingKey {
        case source
        case externalId
        case isVerified
        case scientificDomain
        case didYouKnow
        case difficulty
        case questionText
        case options
        case correctAnswer
        case topic
        case topicID
        case cognitiveSkills
        case eloRating
        case hints
        case explanation
        case realWorldContext
    }

    init(
        id: UUID = UUID(),
        source: String? = nil,
        externalId: String? = nil,
        isVerified: Bool? = nil,
        scientificDomain: String? = nil,
        didYouKnow: String? = nil,
        difficulty: String,
        questionText: String,
        options: [String],
        correctAnswer: String,
        topic: String?,
        topicID: String?,
        cognitiveSkills: [String]? = nil,
        eloRating: Int? = nil,
        hints: [String]? = nil,
        explanation: String?,
        realWorldContext: String? = nil
    ) {
        self.id = id
        self.source = source
        self.externalId = externalId
        self.isVerified = isVerified
        self.scientificDomain = scientificDomain
        self.didYouKnow = didYouKnow
        self.difficulty = difficulty
        self.questionText = questionText
        self.options = options
        self.correctAnswer = correctAnswer
        self.topic = topic
        self.topicID = topicID
        self.cognitiveSkills = cognitiveSkills
        self.eloRating = eloRating
        self.hints = hints
        self.explanation = explanation
        self.realWorldContext = realWorldContext
    }
}

class QuestionsViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var topics: [Topic] = [] // Store all topics for the Picker
    @Published var listQuestions: [QuestionImport] = []
    @Published var questions: [Question] = []
    @Published var libraryQuestions: [Question] = []
    private let topicsRepository = TopicsRepository()
    private let questionsRepository = QuestionsRepository()
    @Published var questionIDsImport:[String] = []
    @Published var selectedQuestionID: String?
    @Published var isLoadingLibrary = false
    @Published var isSavingDraft = false
    @Published var isDeletingQuestion = false
    @Published var isCreatingNewQuestion = false
    @Published var draftQuestionText = ""
    @Published var draftDifficulty = "Medium"
    @Published var draftOptions: [String] = ["", "", "", ""]
    @Published var draftCorrectAnswer = ""
    @Published var draftTopicID = ""
    @Published var draftCognitiveSkillsText = "logic"
    @Published var draftEloRating = "1200"
    @Published var draftHintsText = ""
    @Published var draftExplanation = ""
    @Published var draftRealWorldContext = ""
    @Published var draftSource = ""
    @Published var draftExternalID = ""
    @Published var draftIsVerified = false
    @Published var draftScientificDomain = "Logic"
    @Published var draftDidYouKnow = ""

    private let defaultDifficultyOptions = [
        "Easy",
        "Medium",
        "Hard",
        "Beginner",
        "Intermediate",
        "Advanced"
    ]

    let scientificDomainOptions = [
        "Nature",
        "Space",
        "Logic",
        "Health",
        "Technology",
        "Data Literacy",
        "Estimation"
    ]

    var selectedQuestion: Question? {
        libraryQuestions.first { $0.id == selectedQuestionID }
    }

    var subjectOptions: [String] {
        uniqueSortedValues(from: topics.map(\.name))
    }

    var difficultyOptions: [String] {
        uniqueSortedValues(from: libraryQuestions.map(\.difficulty) + defaultDifficultyOptions)
    }

    var draftReference: String {
        selectedQuestionID ?? "DRAFT-NEW"
    }

    var draftTopic: Topic? {
        topics.first { $0.id == draftTopicID }
    }

    var draftWarnings: [String] {
        var warnings: [String] = []

        if draftQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Question prompt is required.")
        }

        if trimmedDraftOptions().count < 2 {
            warnings.append("Add at least two answer options.")
        }

        if draftCorrectAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Correct answer is missing.")
        }

        if draftTopicID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Assign the question to a topic before saving.")
        }

        if normalizedSkills(from: draftCognitiveSkillsText).isEmpty {
            warnings.append("Add at least one cognitive skill tag.")
        }

        if normalizedEloRating() == nil {
            warnings.append("ELO rating must be a number between 800 and 2500.")
        }

        return warnings
    }
    
    func fetchAllTopics() {
        topicsRepository.fetchAll { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let topics):
                    self.topics = topics
                case .failure(let error):
                    self.errorMessage = "Failed to fetch topics: \(error.localizedDescription)"
                }
            }
        }
    }

    func loadLibrary(force: Bool = false) {
        if isLoadingLibrary && force == false {
            return
        }

        isLoadingLibrary = true
        errorMessage = nil

        let group = DispatchGroup()
        var loadedTopics = topics
        var loadedQuestions = libraryQuestions
        var capturedErrors: [String] = []

        group.enter()
        topicsRepository.fetchAll { result in
            defer { group.leave() }

            switch result {
            case .success(let topics):
                loadedTopics = topics
            case .failure(let error):
                capturedErrors.append("Topics: \(error.localizedDescription)")
            }
        }

        group.enter()
        questionsRepository.fetchAllQuestions { result in
            defer { group.leave() }

            switch result {
            case .success(let questions):
                loadedQuestions = questions
            case .failure(let error):
                capturedErrors.append("Questions: \(error.localizedDescription)")
            }
        }

        group.notify(queue: .main) {
            self.isLoadingLibrary = false
            self.topics = loadedTopics.sorted {
                let subjectComparison = $0.name.localizedCaseInsensitiveCompare($1.name)
                if subjectComparison == .orderedSame {
                    return $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
                }

                return subjectComparison == .orderedAscending
            }
            self.libraryQuestions = loadedQuestions.sorted {
                $0.questionText.localizedCaseInsensitiveCompare($1.questionText) == .orderedAscending
            }

            if let selectedQuestionID = self.selectedQuestionID,
               let selectedQuestion = self.libraryQuestions.first(where: { $0.id == selectedQuestionID }) {
                self.selectQuestion(selectedQuestion)
            } else if self.isCreatingNewQuestion == false, let firstQuestion = self.libraryQuestions.first {
                self.selectQuestion(firstQuestion)
            } else if self.libraryQuestions.isEmpty {
                self.startCreatingNewQuestion()
            }

            if capturedErrors.isEmpty == false {
                self.errorMessage = capturedErrors.joined(separator: "\n")
            }
        }
    }
    
    // Function to upload a question to Firestore under a specific topic
    func uploadQuestion(topicID: String, questionData: [String: Any]) {
        questionsRepository.uploadQuestionToTopicSubcollection(topicID: topicID, data: questionData) { error in
            if let error = error {
                self.errorMessage = "Failed to upload question: \(error.localizedDescription)"
            } else {
                self.successMessage = "Questions imported successfully!"
            }
        }
    }
    
    func filterTopics(by name: String) -> Topic? {
        topics.first { topic in
            return topic.category == name
        }
    }
    
    func filterTopicsByCategory(by category: String) -> Topic? {
        topics.first { topic in
            return topic.category == category
        }
    }

    func selectQuestion(_ question: Question) {
        selectedQuestionID = question.id
        isCreatingNewQuestion = false

        draftQuestionText = question.questionText
        draftDifficulty = question.difficulty
        draftOptions = normalizedDraftOptions(from: question.options)
        draftCorrectAnswer = question.correctAnswer
        draftTopicID = question.topicID ?? ""
        draftCognitiveSkillsText = (question.cognitiveSkills?.isEmpty == false)
            ? (question.cognitiveSkills ?? []).joined(separator: ", ")
            : "logic"
        draftEloRating = "\(question.eloRating ?? defaultEloRating(for: question.difficulty))"
        draftHintsText = (question.hints ?? []).joined(separator: "\n")
        draftExplanation = question.explanation ?? ""
        draftRealWorldContext = question.realWorldContext ?? ""
        draftSource = question.source ?? ""
        draftExternalID = question.externalId ?? ""
        draftIsVerified = question.isVerified ?? false
        draftScientificDomain = question.scientificDomain ?? defaultScientificDomain(for: question)
        draftDidYouKnow = question.didYouKnow ?? ""
    }

    func startCreatingNewQuestion() {
        isCreatingNewQuestion = true
        selectedQuestionID = nil
        successMessage = nil
        errorMessage = nil

        draftQuestionText = ""
        draftDifficulty = defaultDifficultyOptions[1]
        draftOptions = ["", "", "", ""]
        draftCorrectAnswer = ""
        draftTopicID = topics.first?.id ?? ""
        draftCognitiveSkillsText = "logic"
        draftEloRating = "1200"
        draftHintsText = ""
        draftExplanation = ""
        draftRealWorldContext = ""
        draftSource = ""
        draftExternalID = ""
        draftIsVerified = true
        draftScientificDomain = "Logic"
        draftDidYouKnow = ""
    }

    func discardDraftChanges() {
        if let selectedQuestion {
            selectQuestion(selectedQuestion)
        } else {
            startCreatingNewQuestion()
        }
    }

    func saveDraftQuestion() {
        let questionText = draftQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let difficulty = draftDifficulty.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = trimmedDraftOptions()
        let rawCorrectAnswer = draftCorrectAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let cognitiveSkills = normalizedSkills(from: draftCognitiveSkillsText)
        let hints = normalizedLines(from: draftHintsText)
        let realWorldContext = draftRealWorldContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let explanation = draftExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = draftSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let externalID = draftExternalID.trimmingCharacters(in: .whitespacesAndNewlines)
        let scientificDomain = draftScientificDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        let didYouKnow = draftDidYouKnow.trimmingCharacters(in: .whitespacesAndNewlines)

        guard questionText.isEmpty == false else {
            errorMessage = "Question prompt is required."
            return
        }

        guard options.count >= 2 else {
            errorMessage = "Add at least two non-empty options before saving."
            return
        }

        guard draftTopicID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            errorMessage = "Select a topic for this question."
            return
        }

        guard cognitiveSkills.isEmpty == false else {
            errorMessage = "Add at least one cognitive skill tag."
            return
        }

        guard let eloRating = normalizedEloRating() else {
            errorMessage = "ELO rating must be a number between 800 and 2500."
            return
        }

        guard let canonicalCorrectAnswer = options.first(where: {
            $0.caseInsensitiveCompare(rawCorrectAnswer) == .orderedSame
        }) else {
            errorMessage = "Correct answer must match one of the listed options."
            return
        }

        let duplicateQuestion = libraryQuestions.first {
            $0.id != selectedQuestion?.id &&
            $0.questionText.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(questionText) == .orderedSame
        }

        if duplicateQuestion != nil {
            errorMessage = "A different question already uses the same prompt."
            return
        }

        let targetQuestionID = selectedQuestion?.id ?? hashedQuestionID(for: questionText)

        let data: [String: Any] = [
            FirestoreField.Question.source: source,
            FirestoreField.Question.externalID: externalID,
            FirestoreField.Question.isVerified: draftIsVerified,
            FirestoreField.Question.scientificDomain: scientificDomain.isEmpty ? "Logic" : scientificDomain,
            FirestoreField.Question.didYouKnow: didYouKnow,
            FirestoreField.Question.difficulty: difficulty.isEmpty ? "Medium" : difficulty,
            FirestoreField.Question.questionText: questionText,
            FirestoreField.Question.options: options,
            FirestoreField.Question.correctAnswer: canonicalCorrectAnswer,
            FirestoreField.Question.topicID: draftTopicID,
            FirestoreField.Question.cognitiveSkills: cognitiveSkills,
            FirestoreField.Question.eloRating: eloRating,
            FirestoreField.Question.hints: hints,
            FirestoreField.Question.explanation: explanation,
            FirestoreField.Question.realWorldContext: realWorldContext
        ]

        isSavingDraft = true
        errorMessage = nil

        questionsRepository.replaceQuestion(
            existingQuestionID: selectedQuestion?.id,
            existingTopicID: selectedQuestion?.topicID,
            newQuestionID: targetQuestionID,
            newTopicID: draftTopicID,
            data: data
        ) { error in
            DispatchQueue.main.async {
                self.isSavingDraft = false

                if let error {
                    self.errorMessage = "Failed to save question: \(error.localizedDescription)"
                    return
                }

                self.successMessage = self.selectedQuestion == nil
                    ? "Question created successfully."
                    : "Question updated successfully."
                self.isCreatingNewQuestion = false
                self.selectedQuestionID = targetQuestionID
                self.loadLibrary(force: true)
            }
        }
    }

    func deleteSelectedQuestion() {
        guard let selectedQuestion, let questionID = selectedQuestion.id else {
            errorMessage = "Select a question before deleting."
            return
        }

        isDeletingQuestion = true
        errorMessage = nil

        questionsRepository.deleteQuestion(
            questionID: questionID,
            topicID: selectedQuestion.topicID
        ) { error in
            DispatchQueue.main.async {
                self.isDeletingQuestion = false

                if let error {
                    self.errorMessage = "Failed to delete question: \(error.localizedDescription)"
                    return
                }

                self.libraryQuestions.removeAll { $0.id == questionID }
                self.successMessage = "Question deleted successfully."

                if let firstQuestion = self.libraryQuestions.first {
                    self.selectQuestion(firstQuestion)
                } else {
                    self.startCreatingNewQuestion()
                }
            }
        }
    }

    func subjectName(for topicID: String?) -> String {
        guard let topicID, let topic = topics.first(where: { $0.id == topicID }) else {
            return "Unassigned"
        }

        return topic.name
    }

    func topicName(for topicID: String?) -> String {
        guard let topicID, let topic = topics.first(where: { $0.id == topicID }) else {
            return "Unknown Topic"
        }

        return topic.category
    }

    func exportData(for questions: [Question]) throws -> Data {
        let payload = questions.map { question in
            QuestionImport(
                source: question.source,
                externalId: question.externalId,
                isVerified: question.isVerified,
                scientificDomain: question.scientificDomain,
                didYouKnow: question.didYouKnow,
                difficulty: question.difficulty,
                questionText: question.questionText,
                options: question.options,
                correctAnswer: question.correctAnswer,
                topic: topics.first(where: { $0.id == question.topicID })?.category ?? question.topic,
                topicID: question.topicID,
                cognitiveSkills: question.cognitiveSkills,
                eloRating: question.eloRating,
                hints: question.hints,
                explanation: question.explanation,
                realWorldContext: question.realWorldContext
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
    
    func getSTEMTopicIDs() -> [String] {
        let stemCategories = ["Chemistry", "Physics", "Engineering", "Math"]
        let stemTopics = AppState.shared.topics.filter { stemCategories.contains($0.name) }
        return stemTopics.compactMap { $0.id }
    }
    
    func fetchQuestionsByTopic(topicID: String) async -> [Question] {
        do {
            return try await questionsRepository.fetchQuestions(topicID: topicID)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch questions: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    func deleteQuestionsByTopic(topicID: String) async {
        do {
            try await questionsRepository.deleteQuestions(topicID: topicID)
            
            await MainActor.run {
                self.successMessage = "Questions deleted successfully!"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete questions: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchQuestions(forTopicIDs topicIDs: [String], level: String) async {
        var selectedTopicIDs = topicIDs.isEmpty ? getSTEMTopicIDs() : topicIDs.shuffled()
        if selectedTopicIDs.count > 30 {
            selectedTopicIDs = Array(selectedTopicIDs.prefix(20))
        }

        do {
            let _questions = try await questionsRepository.fetchQuestions(
                level: level,
                topicIDs: selectedTopicIDs,
                limit: 15
            )
            await MainActor.run {
                self.questions = _questions.shuffled()
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch questions: \(error.localizedDescription)"
            }
            // Handle any errors during the Firestore fetch
            
        }
    }
    
    // Function to parse JSON file and upload questions based on topicID
    func importQuestionsFromJSON(url: URL) {
        listQuestions.removeAll()
        self.successMessage = nil
        self.errorMessage = nil
        
        do {
            let data = try Data(contentsOf: url)
            let questions = try JSONDecoder().decode([QuestionImport].self, from: data)
            
            listQuestions.append(contentsOf: questions)
        } catch {
            self.errorMessage = jsonImportErrorMessage(for: error)
        }
    }
    
    // Function to parse JSON file and upload questions based on topicID
    func importChallengesFromJSON(url: URL) -> ChallengeImport? {
        listQuestions.removeAll()
        self.successMessage = nil
        self.errorMessage = nil
        
        do {
            let data = try Data(contentsOf: url)
            
            let challenges = try JSONDecoder().decode(ChallengeImport.self, from: data)
            
            if challenges.questions.count > 0 {
                
                listQuestions.append(contentsOf: challenges.questions)
                
            } else {
                self.errorMessage = "Failed to import JSON file"
            }
            return challenges
        } catch {
            self.errorMessage = jsonImportErrorMessage(for: error)
            return nil
        }
    }

    private func jsonImportErrorMessage(for error: Error) -> String {
        switch error {
        case let DecodingError.keyNotFound(key, context):
            let path = (context.codingPath + [key]).map(\.stringValue).joined(separator: ".")
            return "Failed to import JSON file: missing field '\(path)'."
        case let DecodingError.typeMismatch(_, context),
             let DecodingError.valueNotFound(_, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            if path.isEmpty {
                return "Failed to import JSON file: invalid JSON structure."
            }
            return "Failed to import JSON file: invalid value at '\(path)'."
        case let DecodingError.dataCorrupted(context):
            return "Failed to import JSON file: \(context.debugDescription)"
        default:
            return "Failed to import JSON file: \(error.localizedDescription)"
        }
    }
    
    
    func uploadQuestionsForChallenges(
        completion: ((Result<[String], Error>) -> Void)? = nil
    ) {
        questionIDsImport.removeAll()

        guard !listQuestions.isEmpty else {
            let error = NSError(
                domain: "QuestionsViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No questions to upload."]
            )
            self.errorMessage = error.localizedDescription
            completion?(.failure(error))
            return
        }
        
        // Step 1: Generate questionIDs by hashing questionText
        let questionIDMap: [String: QuestionImport] = Dictionary(uniqueKeysWithValues: listQuestions.map { question in
            let questionID = SHA256.hash(data: Data(question.questionText.utf8))
                .compactMap { String(format: "%02x", $0) }
                .joined()
            return (questionID, question)
        })
        
        let allQuestionIDs = Array(questionIDMap.keys)
        
        // Step 3: Filter out questions that already exist
        let newQuestionIDs = allQuestionIDs
        let newQuestions = newQuestionIDs.compactMap { questionIDMap[$0] }
        
        if newQuestions.isEmpty {
            DispatchQueue.main.async {
                self.successMessage = "No new questions to upload."
                completion?(.success(allQuestionIDs))
            }
            return
        }
        
        // Step 4: Prepare batch upload for new questions
        let batch = questionsRepository.makeBatch()
        
        for question in newQuestions {
            guard let topicName = question.topic else {
                continue
            }
            guard let topic = self.filterTopics(by: topicName) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Topic not found for question: \(question.questionText)"
                    let error = NSError(
                        domain: "QuestionsViewModel",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Topic not found for question: \(question.questionText)"]
                    )
                    completion?(.failure(error))
                }
                return
            }
            
            let questionID = SHA256.hash(data: Data(question.questionText.utf8))
                .compactMap { String(format: "%02x", $0) }
                .joined()
            
            questionsRepository.addImportedQuestion(
                to: batch,
                topicID: topic.id,
                questionID: questionID,
                data: importedQuestionData(for: question, topicID: topic.id)
            )
            self.questionIDsImport.append(questionID)
        }
        
        // Step 5: Commit the batch
        questionsRepository.commit(batch) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to upload questions: \(error.localizedDescription)"
                    completion?(.failure(error))
                } else {
                    self.successMessage = "\(newQuestions.count) Questions imported successfully!"
                    completion?(.success(self.questionIDsImport))
                    print(self.successMessage as Any)
                }
            }
        }
    }
    
    
    func uploadQuestions() {
        guard !listQuestions.isEmpty else {
            self.errorMessage = "No questions to upload."
            return
        }
        
        // Step 1: Generate questionIDs by hashing questionText
        let questionIDMap: [String: QuestionImport] = Dictionary(uniqueKeysWithValues: listQuestions.map { question in
            let questionID = SHA256.hash(data: Data(question.questionText.utf8))
                .compactMap { String(format: "%02x", $0) }
                .joined()
            return (questionID, question)
        })
        
        let allQuestionIDs = Array(questionIDMap.keys)
        
        // Step 2: Fetch existing questionIDs from Firestore
        fetchExistingQuestionIDs(questionIDs: allQuestionIDs) { existingIDs in
            self.fetchExistingExternalQuestionKeys(for: Array(questionIDMap.values)) { existingExternalKeys in
                // Step 3: Filter out questions that already exist by document ID or API source key.
                let newQuestionIDs = allQuestionIDs.filter { questionID in
                    guard existingIDs.contains(questionID) == false,
                          let question = questionIDMap[questionID] else {
                        return false
                    }

                    if let externalKey = self.externalQuestionKey(for: question),
                       existingExternalKeys.contains(externalKey) {
                        return false
                    }

                    return true
                }
                let newQuestions = newQuestionIDs.compactMap { questionIDMap[$0] }
                
                if newQuestions.isEmpty {
                    DispatchQueue.main.async {
                        self.successMessage = "No new questions to upload."
                    }
                    return
                }
                
                // Step 4: Prepare batch upload for new questions
                let batch = self.questionsRepository.makeBatch()
                
                for question in newQuestions {
                    guard let topicCategory = question.topic else {
                        continue
                    }
                    guard let topic = self.filterTopicsByCategory(by: topicCategory) else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Topic not found for question: \(question.questionText)"
                        }
                        return
                    }
                    
                    let questionID = SHA256.hash(data: Data(question.questionText.utf8))
                        .compactMap { String(format: "%02x", $0) }
                        .joined()
                    
                    self.questionsRepository.addImportedQuestion(
                        to: batch,
                        topicID: topic.id,
                        questionID: questionID,
                        data: self.importedQuestionData(for: question, topicID: topic.id)
                    )
                    self.questionIDsImport.append(questionID)
                }
                
                // Step 5: Commit the batch
                self.questionsRepository.commit(batch) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = "Failed to upload questions: \(error.localizedDescription)"
                        } else {
                            self.successMessage = "\(newQuestions.count) Questions imported successfully!"
                            self.loadLibrary(force: true)
                            print(self.successMessage as Any)
                        }
                    }
                }
            }
        }
    }
    
    /// Fetches existing question IDs from Firestore.
    /// - Parameters:
    ///   - questionIDs: Array of question IDs to check.
    ///   - completion: Closure returning a set of existing question IDs.
    private func fetchExistingQuestionIDs(questionIDs: [String], completion: @escaping (Set<String>) -> Void) {
        questionsRepository.fetchExistingQuestionIDs(questionIDs) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let existingIDs):
                    completion(existingIDs)
                case .failure(let error):
                    self.errorMessage = "Error checking duplicates: \(error.localizedDescription)"
                    completion([])
                }
            }
        }
    }

    private func fetchExistingExternalQuestionKeys(
        for questions: [QuestionImport],
        completion: @escaping (Set<String>) -> Void
    ) {
        let groupedKeys = questions.reduce(into: [String: Set<String>]()) { result, question in
            guard let source = normalizedOptionalImportValue(question.source),
                  let externalID = normalizedOptionalImportValue(question.externalId) else {
                return
            }

            result[source, default: []].insert(externalID)
        }

        questionsRepository.fetchExistingExternalQuestionKeys(groupedKeys) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let existingKeys):
                    completion(existingKeys)
                case .failure(let error):
                    self.errorMessage = "Error checking external duplicates: \(error.localizedDescription)"
                    completion([])
                }
            }
        }
    }
    
    func fetchQuestionsByTopic(topicID: String, completion: @escaping ([Question]) -> Void) {
        questionsRepository.fetchQuestions(topicID: topicID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let questions):
                    completion(questions)
                case .failure(let error):
                    self.errorMessage = "Failed to fetch questions: \(error.localizedDescription)"
                    completion([])
                }
            }
        }
    }
    
    func deleteQuestionsByTopic(topicID: String, completion: @escaping () -> Void) {
        questionsRepository.deleteQuestions(topicID: topicID) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to delete questions: \(error.localizedDescription)"
                } else {
                    self.successMessage = "Questions deleted successfully!"
                    completion()
                }
            }
        }
    }

    private func normalizedDraftOptions(from options: [String]) -> [String] {
        let cleanedOptions = options.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if cleanedOptions.count >= 4 {
            return cleanedOptions
        }

        return cleanedOptions + Array(repeating: "", count: 4 - cleanedOptions.count)
    }

    private func trimmedDraftOptions() -> [String] {
        draftOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func normalizedSkills(from rawValue: String) -> [String] {
        rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "_")
            }
            .filter { $0.isEmpty == false }
    }

    private func normalizedLines(from rawValue: String) -> [String] {
        rawValue
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func normalizedEloRating() -> Int? {
        let trimmedValue = draftEloRating.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmedValue), (800...2500).contains(value) else {
            return nil
        }

        return value
    }

    private func defaultEloRating(for difficulty: String) -> Int {
        switch difficulty.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "easy", "beginner":
            return 900
        case "hard", "advanced":
            return 1700
        default:
            return 1200
        }
    }

    private func importedQuestionData(for question: QuestionImport, topicID: String) -> [String: Any] {
        [
            FirestoreField.Question.source: normalizedOptionalImportValue(question.source) ?? "",
            FirestoreField.Question.externalID: normalizedOptionalImportValue(question.externalId) ?? "",
            FirestoreField.Question.isVerified: question.isVerified ?? false,
            FirestoreField.Question.scientificDomain: normalizedOptionalImportValue(question.scientificDomain)
                ?? defaultScientificDomain(for: question),
            FirestoreField.Question.didYouKnow: normalizedOptionalImportValue(question.didYouKnow) ?? "",
            FirestoreField.Question.topicID: topicID,
            FirestoreField.Question.difficulty: question.difficulty,
            FirestoreField.Question.questionText: question.questionText,
            FirestoreField.Question.options: question.options,
            FirestoreField.Question.correctAnswer: question.correctAnswer,
            FirestoreField.Question.cognitiveSkills: question.cognitiveSkills ?? ["logic"],
            FirestoreField.Question.eloRating: question.eloRating ?? defaultEloRating(for: question.difficulty),
            FirestoreField.Question.hints: question.hints ?? [],
            FirestoreField.Question.explanation: question.explanation ?? "",
            FirestoreField.Question.realWorldContext: question.realWorldContext ?? ""
        ]
    }

    private func normalizedOptionalImportValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func externalQuestionKey(for question: QuestionImport) -> String? {
        guard let source = normalizedOptionalImportValue(question.source),
              let externalID = normalizedOptionalImportValue(question.externalId) else {
            return nil
        }

        return "\(source):\(externalID)"
    }

    private func defaultScientificDomain(for question: Question) -> String {
        if let skill = question.cognitiveSkills?.first {
            return scientificDomain(forSkill: skill)
        }

        return "Logic"
    }

    private func defaultScientificDomain(for question: QuestionImport) -> String {
        if let skill = question.cognitiveSkills?.first {
            return scientificDomain(forSkill: skill)
        }

        return "Logic"
    }

    private func scientificDomain(forSkill skill: String) -> String {
        switch skill.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "data_literacy", "data literacy", "statistics", "probability":
            return "Data Literacy"
        case "estimation", "mental_math", "mental math":
            return "Estimation"
        case "health", "biology", "medicine":
            return "Health"
        case "technology", "computer_science", "computer science", "engineering":
            return "Technology"
        case "space", "astronomy", "physics":
            return "Space"
        case "nature", "chemistry", "earth_science", "earth science":
            return "Nature"
        default:
            return "Logic"
        }
    }

    private func hashedQuestionID(for questionText: String) -> String {
        SHA256.hash(data: Data(questionText.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func uniqueSortedValues(from values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

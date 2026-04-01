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
    var difficulty: String
    var questionText: String
    var options: [String]
    var correctAnswer: String
    var topic: String?
    var topicID: String?
    var explanation: String?
}

struct QuestionImport: Identifiable, Codable {
    var id = UUID()

    var difficulty: String
    var questionText: String
    var options: [String]
    var correctAnswer: String
    var topic: String?
    var topicID: String?
    var explanation: String?

    enum CodingKeys: String, CodingKey {
        case difficulty
        case questionText
        case options
        case correctAnswer
        case topic
        case topicID
        case explanation
    }

    init(
        id: UUID = UUID(),
        difficulty: String,
        questionText: String,
        options: [String],
        correctAnswer: String,
        topic: String?,
        topicID: String?,
        explanation: String?
    ) {
        self.id = id
        self.difficulty = difficulty
        self.questionText = questionText
        self.options = options
        self.correctAnswer = correctAnswer
        self.topic = topic
        self.topicID = topicID
        self.explanation = explanation
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
    @Published var draftExplanation = ""

    private let defaultDifficultyOptions = [
        "Easy",
        "Medium",
        "Hard",
        "Beginner",
        "Intermediate",
        "Advanced"
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
        draftExplanation = question.explanation ?? ""
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
        draftExplanation = ""
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
        let explanation = draftExplanation.trimmingCharacters(in: .whitespacesAndNewlines)

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
            FirestoreField.Question.difficulty: difficulty.isEmpty ? "Medium" : difficulty,
            FirestoreField.Question.questionText: questionText,
            FirestoreField.Question.options: options,
            FirestoreField.Question.correctAnswer: canonicalCorrectAnswer,
            FirestoreField.Question.topicID: draftTopicID,
            FirestoreField.Question.explanation: explanation
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
                difficulty: question.difficulty,
                questionText: question.questionText,
                options: question.options,
                correctAnswer: question.correctAnswer,
                topic: topics.first(where: { $0.id == question.topicID })?.category ?? question.topic,
                topicID: question.topicID,
                explanation: question.explanation
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
            self.errorMessage = "Failed to import JSON file: \(error.localizedDescription)"
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
            self.errorMessage = "Failed to import JSON file: \(error.localizedDescription)"
            return nil
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
                data: [
                    FirestoreField.Question.topicID: topic.id,
                    FirestoreField.Question.difficulty: question.difficulty,
                    FirestoreField.Question.questionText: question.questionText,
                    FirestoreField.Question.options: question.options,
                    FirestoreField.Question.correctAnswer: question.correctAnswer,
                    FirestoreField.Question.explanation: question.explanation ?? ""
                ]
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
            // Step 3: Filter out questions that already exist
            let newQuestionIDs = allQuestionIDs.filter { !existingIDs.contains($0) }
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
                    data: [
                        FirestoreField.Question.topicID: topic.id,
                        FirestoreField.Question.difficulty: question.difficulty,
                        FirestoreField.Question.questionText: question.questionText,
                        FirestoreField.Question.options: question.options,
                        FirestoreField.Question.correctAnswer: question.correctAnswer,
                        FirestoreField.Question.explanation: question.explanation ?? ""
                    ]
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

//
//  QuestionsViewModel.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 15/11/24.
//


import SwiftUI
import FirebaseFirestore
import CryptoKit

struct Question: Identifiable, Codable {
    var id: String? = UUID().uuidString
    var difficulty: String
    var questionText: String
    var options: [String]
    var correctAnswer: String
    var topic: String?
    var topicID: String?
    var explanation: String?
}

struct QuestionImport: Identifiable, Codable {
    var id: Int? = Int.random(in: 1...1000000)
    
    var difficulty: String
    var questionText: String
    var options: [String]
    var correctAnswer: String
    var topic: String?
    var topicID: String?
    var explanation: String?
}

class QuestionsViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var topics: [Topic] = [] // Store all topics for the Picker
    @Published var listQuestions: [QuestionImport] = []
    @Published var questions: [Question] = []
    private let topicsRepository = TopicsRepository()
    private let questionsRepository = QuestionsRepository()
    @Published var questionIDsImport:[String] = []
    
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
    
    func getSTEMTopicIDs() -> [String] {
        let stemCategories = ["Chemistry", "Physics", "Engineering", "Math"]
        let stemTopics = AppState.shared.topics.filter { stemCategories.contains($0.name) }
        return stemTopics.compactMap { $0.id }
    }
    
    func fetchQuestionsByTopic(topicID: String) async -> [Question] {
        do {
            return try await questionsRepository.fetchQuestions(topicID: topicID)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to fetch questions: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    func deleteQuestionsByTopic(topicID: String) async {
        do {
            try await questionsRepository.deleteQuestions(topicID: topicID)
            
            DispatchQueue.main.async {
                self.successMessage = "Questions deleted successfully!"
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to delete questions: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchQuestions(forTopicIDs topicIDs: [String], level: String) async {
        // Firestore 'in' queries are limited to 10 items
        // Batch the topic IDs if necessary
        var topics = getSTEMTopicIDs().shuffled()
        if topics.count > 30 {
            topics = Array(topics.prefix(20))
        }
        do {
            // Query Firestore for questions with the specified criteria
            let _questions = try await questionsRepository.fetchQuestions(
                level: level,
                topicIDs: topics,
                limit: 15
            )
            DispatchQueue.main.async {
                self.questions = _questions.shuffled()
            }
            
        } catch {
            DispatchQueue.main.async {
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
    
    
    func uploadQuestionsForChallenges() {
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
        
        // Step 3: Filter out questions that already exist
        let newQuestionIDs = allQuestionIDs
        let newQuestions = newQuestionIDs.compactMap { questionIDMap[$0] }
        
        if newQuestions.isEmpty {
            DispatchQueue.main.async {
                self.successMessage = "No new questions to upload."
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
                } else {
                    self.successMessage = "\(newQuestions.count) Questions imported successfully!"
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
}

//
//  ChallengesViewModel.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 20/11/24.
//


//
//  ChallengesViewModel.swift
//  QuizStem
//
//  Created by QuangHo on 20/11/24.
//


import SwiftUI
import FirebaseFirestore
import Foundation

enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

struct ChallengeImport: Codable {
    var type: String         // "daily" or "weekly"
    var title: String
    var description: String
    var startDate: String
    var remainTime: Int?
    var endDate: String
    var difficultyLevel: DifficultyLevel // Updated to use the enum
    var questions: [QuestionImport]  // Array of question IDs
    var rewards: [Reward]?       // Array of reward objects
    var isActive: Bool
    var createdAt: String
    var updatedAt: String
}

struct Challenge: Identifiable, Codable {
    @DocumentID var id: String?
    var type: String         // "daily" or "weekly"
    var title: String
    var description: String
    var startDate: Date
    var remainTime: Int?
    var endDate: Date
    var difficultyLevel: DifficultyLevel // Updated to use the enum
    var questions: [String]  // Array of question IDs
    var rewards: [Reward]?       // Array of reward objects
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}


struct Reward: Codable {
    var type: String     // e.g., "points", "badge"
    var value: Int       // Number of points or identifier for badge
    var description: String?
}


class ChallengesViewModel: ObservableObject {
    @Published var currentChallenges: [Challenge] = []
    @Published var errorMessage: String?
    @Published var successMessage: String?

    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var type: String = "daily"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var rewards: String = ""
    
    @State  var selectedTopics: [Topic] = []
    @State  var selectedQuestions: [Question] = []
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    deinit {
        listenerRegistration?.remove()
    }

    func fetchCurrentChallenges() {
        let now = Date()
        listenerRegistration = db.collection("challenges")
            .whereField("startDate", isLessThanOrEqualTo: now)
            .whereField("endDate", isGreaterThanOrEqualTo: now)
            .order(by: "startDate")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.errorMessage = "Failed to fetch challenges: \(error.localizedDescription)"
                } else {
                    self.currentChallenges = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Challenge.self)
                    } ?? []
                }
            }
    }
    
    func fetchChallenges(ofType type: String) {
        let now = Date()
        listenerRegistration = db.collection("challenges")
            .whereField("type", isEqualTo: type)
            .whereField("startDate", isLessThanOrEqualTo: now)
            .whereField("endDate", isGreaterThanOrEqualTo: now)
            .order(by: "startDate")
            .addSnapshotListener { [weak self] snapshot, error in
                // Handle data as above
            }
    }
    
    func createChallenge(_ challenge: Challenge) {
        do {
            let _ = try db.collection("challenges").addDocument(from: challenge) { [weak self] error in
                if let error = error {
                    self?.errorMessage = "Failed to create challenge: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Challenge created successfully!"
                }
            }
        } catch {
            self.errorMessage = "Failed to encode challenge: \(error.localizedDescription)"
        }
    }
    
}

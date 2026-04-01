//
//  ChallengesViewModel.swift
//  ManagementQuizStem
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
    @Published var allChallenges: [Challenge] = []
    @Published var currentChallenges: [Challenge] = []
    @Published var isLoadingLibrary = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let repository = ChallengesRepository()
    private var listenerRegistration: ListenerRegistration?
    private var hasLoadedLibrary = false

    deinit {
        listenerRegistration?.remove()
    }

    func loadChallengeLibrary(force: Bool = false) {
        guard hasLoadedLibrary == false || force else { return }

        hasLoadedLibrary = true
        isLoadingLibrary = true
        errorMessage = nil
        listenerRegistration?.remove()

        listenerRegistration = repository.listenForAllChallenges { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoadingLibrary = false

                switch result {
                case .success(let challenges):
                    self.allChallenges = challenges
                    self.currentChallenges = challenges.filter { challenge in
                        challenge.isActive && challenge.startDate <= .now && challenge.endDate >= .now
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to fetch challenges: \(error.localizedDescription)"
                }
            }
        }
    }

    func fetchCurrentChallenges() {
        listenerRegistration = repository.listenForCurrentChallenges { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let challenges):
                self.currentChallenges = challenges
                self.allChallenges = challenges
            case .failure(let error):
                self.errorMessage = "Failed to fetch challenges: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchChallenges(ofType type: String) {
        listenerRegistration = repository.listenForChallenges(ofType: type) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let challenges):
                self.currentChallenges = challenges
            case .failure(let error):
                self.errorMessage = "Failed to fetch challenges: \(error.localizedDescription)"
            }
        }
    }
    
    func createChallenge(_ challenge: Challenge) {
        do {
            try repository.create(challenge) { [weak self] error in
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

    func createChallenge(
        _ challenge: Challenge,
        onSuccess: (() -> Void)? = nil
    ) {
        do {
            try repository.create(challenge) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = "Failed to create challenge: \(error.localizedDescription)"
                    } else {
                        self?.successMessage = "Challenge created successfully!"
                        onSuccess?()
                    }
                }
            }
        } catch {
            errorMessage = "Failed to encode challenge: \(error.localizedDescription)"
        }
    }
}

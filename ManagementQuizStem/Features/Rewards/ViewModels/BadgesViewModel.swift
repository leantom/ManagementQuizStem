//
//  BadgesViewModel.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 22/11/24.
//
import FirebaseFirestore
import Foundation

class BadgesViewModel: ObservableObject {
    @Published var badges: [Badge] = []
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let repository = BadgesRepository()
    private var listenerRegistration: ListenerRegistration?
    
    deinit {
        listenerRegistration?.remove()
    }
    
    /// Fetch all badges from Firestore
    func fetchBadges() {
        listenerRegistration = repository.listenForBadges { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let badges):
                self.badges = badges
            case .failure(let error):
                self.errorMessage = "Failed to fetch badges: \(error.localizedDescription)"
            }
        }
    }
    
    /// Create a new badge in Firestore
    func createBadge(_ badge: Badge) {
        do {
            try repository.create(badge) { [weak self] error in
                if let error = error {
                    self?.errorMessage = "Failed to create badge: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Badge created successfully!"
                }
            }
        } catch {
            self.errorMessage = "Failed to encode badge: \(error.localizedDescription)"
        }
    }
    
    /// Update an existing badge
    func updateBadge(_ badge: Badge) {
        guard let badgeID = badge.id else {
            errorMessage = "Badge ID is missing."
            return
        }
        do {
            try repository.update(badge) { [weak self] error in
                if let error = error {
                    self?.errorMessage = "Failed to update badge: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Badge updated successfully!"
                }
            }
        } catch {
            self.errorMessage = "Failed to encode badge: \(error.localizedDescription)"
        }
    }
    
    /// Delete a badge
    func deleteBadge(_ badge: Badge) {
        guard let badgeID = badge.id else {
            errorMessage = "Badge ID is missing."
            return
        }
        repository.delete(badgeID: badgeID) { [weak self] error in
            if let error = error {
                self?.errorMessage = "Failed to delete badge: \(error.localizedDescription)"
            } else {
                self?.successMessage = "Badge deleted successfully!"
            }
        }
    }
    
    func createListBadge(badges: [Badge], completion: @escaping (Result<Void, Error>) -> Void) {
        repository.createListBadge(badges: badges, completion: completion)
    }
    
    
    /// Example function to upload predefined badges with fixed UUIDs
    func uploadBadges() {
        // Define BadgeCriteria instances (as per your initial definitions)
        // Starter Level Badges
        let curiousLearnerCriteria = BadgeCriteria(
            action: "complete_question",
            topic: "any",
            accuracy: 0.0,
            question: 1,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        let topicExplorerCriteria = BadgeCriteria(
            action: "complete_topic",
            topic: "beginner",
            accuracy: 0.0,
            question: 0,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        let firstSuccessCriteria = BadgeCriteria(
            action: "score_quiz",
            topic: "any",
            accuracy: 80.0,
            question: 0,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        // Intermediate Level Badges
        let stemChallengerCriteria = BadgeCriteria(
            action: "complete_questions",
            topic: "any",
            accuracy: 0.0,
            question: 50,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        let focusedLearnerCriteria = BadgeCriteria(
            action: "complete_topics",
            topic: "intermediate",
            accuracy: 0.0,
            question: 0,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        let persistencePaysCriteria = BadgeCriteria(
            action: "achieve_accuracy",
            topic: "intermediate",
            accuracy: 90.0,
            question: 0,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        // Advanced Level Badges
        let topicMasterCriteria = BadgeCriteria(
            action: "complete_topic_with_excellence",
            topic: "advanced",
            accuracy: 95.0,
            question: 0,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        let criticalThinkerCriteria = BadgeCriteria(
            action: "solve_difficult_questions_in_a_row",
            topic: "difficult",
            accuracy: 0.0,
            question: 10,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        let stemTrailblazerCriteria = BadgeCriteria(
            action: "complete_questions",
            topic: "all_levels",
            accuracy: 0.0,
            question: 100,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        // Gamified Challenge Badges
        let fastLearnerCriteria = BadgeCriteria(
            action: "solve_questions_within_time",
            topic: "any",
            accuracy: 0.0,
            question: 5,
            timeLimit: 180, // 3 minutes
            timeWindow: nil,
            streak: nil
        )
        
        let precisionExpertCriteria = BadgeCriteria(
            action: "solve_consecutive_questions_without_errors",
            topic: "any",
            accuracy: 100.0,
            question: 10,
            timeLimit: nil,
            timeWindow: nil,
            streak: nil
        )
        
        let nightOwlCriteria = BadgeCriteria(
            action: "solve_questions_within_time_window",
            topic: "any",
            accuracy: 0.0,
            question: 10,
            timeLimit: nil,
            timeWindow: TimeWindow(startTime: "22:00", endTime: "06:00"),
            streak: nil
        )
        
        let earlyBirdCriteria = BadgeCriteria(
            action: "solve_question_before_time_with_streak",
            topic: "any",
            accuracy: 0.0,
            question: 1, // First question each day
            timeLimit: nil,
            timeWindow: TimeWindow(startTime: "00:00", endTime: "09:00"),
            streak: 7 // 7 consecutive days
        )
        
        // Define Badge instances with fixed UUIDs
        let badges: [Badge] = [
            // Starter Level Badges
            Badge(
                id: "E1B8D9A2-7D4F-4F1B-8F8A-2D3C4B5A6F7E", // Fixed UUID
                title: "🌟 Curious Learner",
                description: "🌟 Take the first step on your learning journey by completing your first question in any topic. 🎉",
                icon: "🌟",
                criteria: curiousLearnerCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "A2C9E0B3-8F5G-5G2C-9H9B-3E4D5C6B7G8F", // Fixed UUID
                title: "🗺️ Topic Explorer",
                description: "🗺️ Dive into learning by successfully completing one beginner-level topic. 🚀",
                icon: "🗺️",
                criteria: topicExplorerCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "B3D0F1C4-9G6H-6H3D-0I0C-4F5G6D7C8H9G", // Fixed UUID
                title: "🏆 First Success",
                description: "🏆 Achieve your first milestone by scoring 80% or higher in a single quiz. 🌟",
                icon: "🏆",
                criteria: firstSuccessCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            
            // Intermediate Level Badges
            Badge(
                id: "C4E1G2D5-0H7I-7I4E-1J1D-5G6H7E8D9I0J", // Fixed UUID
                title: "💪 STEM Challenger",
                description: "💪 Push your boundaries by completing 50 questions in any topic. 🔢",
                icon: "💪",
                criteria: stemChallengerCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "D5F2H3E6-1I8J-8J5F-2K2E-6H7I8F9E0J1K", // Fixed UUID
                title: "🎯 Focused Learner",
                description: "🎯 Stay committed to progress by completing three intermediate-level topics. 📚",
                icon: "🎯",
                criteria: focusedLearnerCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "E6G3I4F7-2J9K-9K6G-3L3F-7I8J9G0F1K2L", // Fixed UUID
                title: "🔥 Persistence Pays",
                description: "🔥 Show determination by achieving 90% accuracy across an intermediate-level topic. 💼",
                icon: "🔥",
                criteria: persistencePaysCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            
            // Advanced Level Badges
            Badge(
                id: "F7H4J5G8-3K0L-0L7H-4M4G-8J9K0H1G2L3M", // Fixed UUID
                title: "👑 Topic Master",
                description: "👑 Demonstrate mastery by completing an advanced-level topic with excellence. 🏅",
                icon: "👑",
                criteria: topicMasterCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "G8I5K6H9-4L1M-1M8I-5N5H-9K0L1I2H3M4N", // Fixed UUID
                title: "🧠 Critical Thinker",
                description: "🧠 Show your problem-solving prowess by solving 10 difficult questions in a row. 💡",
                icon: "🧠",
                criteria: criticalThinkerCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "H9J6L7I0-5M2N-2N9J-6O6I-0L1M2J3I4N5O", // Fixed UUID
                title: "🚀 STEM Trailblazer",
                description: "🚀 Lead the way in STEM by completing 100 questions across all levels. 🌌",
                icon: "🚀",
                criteria: stemTrailblazerCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            
            // Gamified Challenge Badges
            Badge(
                id: "I0K7M8J1-6N3O-3O0K-7P7J-1M2N3K4J5O6P", // Fixed UUID
                title: "⚡ Fast Learner",
                description: "⚡ Solve 5 questions in less than 3 minutes. 🕒",
                icon: "⚡",
                criteria: fastLearnerCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "J1L8N9K2-7O4P-4P1L-8Q8K-2N3O4L5K6P7Q", // Fixed UUID
                title: "🎯 Precision Expert",
                description: "🎯 Solve 10 questions in a row without errors. 🏅",
                icon: "🎯",
                criteria: precisionExpertCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "K2M9O0L3-8P5Q-5Q2M-9R9L-3O4P5M6L7Q8R", // Fixed UUID
                title: "🌙 Night Owl",
                description: "🌙 Solve 10 questions between 10 PM and 6 AM. 🌌",
                icon: "🌙",
                criteria: nightOwlCriteria,
                createdAt: Date(),
                updatedAt: nil
            ),
            Badge(
                id: "L3N0P1M4-9Q6R-6R3N-0S0M-4P5Q6N7M8R9S", // Fixed UUID
                title: "🐦 Early Bird",
                description: "🐦 Solve your first question before 9 AM for 7 days in a row. 🌅",
                icon: "🐦",
                criteria: earlyBirdCriteria,
                createdAt: Date(),
                updatedAt: nil
            )
        ]
        
        // Upload the badges
        createListBadge(badges: badges) { result in
            switch result {
            case .success():
                print("All badges successfully uploaded to Firestore.")
                self.successMessage = "All badges successfully uploaded to Firestore."
            case .failure(let error):
                print("Failed to upload badges: \(error.localizedDescription)")
                self.errorMessage = "Failed to upload badges: \(error.localizedDescription)"
            }
        }
    }
    
    
}

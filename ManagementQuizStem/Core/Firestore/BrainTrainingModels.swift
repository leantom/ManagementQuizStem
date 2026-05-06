import Foundation
import FirebaseFirestore

struct BrainTrainingUserProfile: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var mentalRadar: [String: Int]
    var streak: UserStreak
    var unlocks: [String]
    var preferences: UserTrainingPreferences

    enum CodingKeys: String, CodingKey {
        case id
        case mentalRadar
        case mentalQuotient
        case streak
        case unlocks
        case preferences
    }

    init(
        id: String? = nil,
        mentalRadar: [String: Int],
        streak: UserStreak,
        unlocks: [String],
        preferences: UserTrainingPreferences
    ) {
        self.id = id
        self.mentalRadar = mentalRadar
        self.streak = streak
        self.unlocks = unlocks
        self.preferences = preferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        mentalRadar = try container.decodeIfPresent([String: Int].self, forKey: .mentalRadar)
            ?? container.decodeIfPresent([String: Int].self, forKey: .mentalQuotient)
            ?? [:]
        streak = try container.decodeIfPresent(UserStreak.self, forKey: .streak)
            ?? UserStreak(currentStreak: 0, longestStreak: 0, lastActiveDate: nil)
        unlocks = try container.decodeIfPresent([String].self, forKey: .unlocks) ?? []
        preferences = try container.decodeIfPresent(UserTrainingPreferences.self, forKey: .preferences)
            ?? UserTrainingPreferences(goals: [], focusSkills: [], preferredDifficultyELO: nil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mentalRadar, forKey: .mentalRadar)
        try container.encode(streak, forKey: .streak)
        try container.encode(unlocks, forKey: .unlocks)
        try container.encode(preferences, forKey: .preferences)
    }
}

struct UserStreak: Codable, Hashable {
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: String?
}

struct UserTrainingPreferences: Codable, Hashable {
    var goals: [String]
    var focusSkills: [String]
    var preferredDifficultyELO: Int?
}

struct LearningPath: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var difficulty: String
    var steps: [LearningPathStep]
    var createdAt: Date?
    var updatedAt: Date?
}

struct LearningPathStep: Codable, Hashable {
    var title: String
    var questionIds: [String]
    var cognitiveSkills: [String]
    var targetELO: Int?
}

struct DailyChallenge: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var date: String
    var questionId: DocumentReference?
    var globalStats: DailyChallengeGlobalStats
}

struct DailyChallengeGlobalStats: Codable, Hashable {
    var totalAttempts: Int
    var correctAttempts: Int
    var optionDistribution: [String: Int]
}

import FirebaseFirestore

struct Badge: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var icon: String
    var criteria: BadgeCriteria
    var createdAt: Date
    var updatedAt: Date?
}

struct BadgeCriteria: Codable, Hashable {
    var action: String
    var topic: String
    var accuracy: Double
    var question: Int
    var timeLimit: Int? // Time in seconds (optional)
    var timeWindow: TimeWindow? // Specific time frames (optional)
    var streak: Int? // Number of consecutive days or actions (optional)
}


struct TimeWindow: Codable, Hashable {
    var startTime: String // Format "HH:mm" (24-hour)
    var endTime: String // Format "HH:mm" (24-hour)
}

import FirebaseFirestore

struct Subject: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var short_name: String
    var description: String
    var trending: Int
    var icon_url: String
    var color_hex: String?
    var topicIds: [String]?

    init(
        id: String = UUID().uuidString,
        name: String,
        short_name: String,
        description: String,
        trending: Int,
        icon_url: String,
        color_hex: String = "FFFFFF",
        topicIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.short_name = short_name
        self.description = description
        self.trending = trending
        self.icon_url = icon_url
        self.color_hex = color_hex.uppercased()
        self.topicIds = topicIds
    }
}

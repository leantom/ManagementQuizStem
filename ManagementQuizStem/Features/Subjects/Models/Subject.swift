import FirebaseFirestore

struct Subject: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var short_name: String
    var description: String
    var trending: Int
    var icon_url: String
    var topicIds: [String]?

    init(
        id: String = UUID().uuidString,
        name: String,
        short_name: String,
        description: String,
        trending: Int,
        icon_url: String,
        topicIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.short_name = short_name
        self.description = description
        self.trending = trending
        self.icon_url = icon_url
        self.topicIds = topicIds
    }
}

import FirebaseFirestore

struct Subject: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var short_name: String
    var description: String
    var trending: Int
    var icon_url: String
    var topicIds: [String]?
    
    // Custom initializer to auto-generate `id`
    init(id: String = UUID().uuidString, name: String, short_name: String, description: String, trending: Int, icon_url: String,topicIds: [String] = []) {
        self.id = id
        self.name = name
        self.short_name = short_name
        self.description = description
        self.trending = trending
        self.icon_url = icon_url
        self.topicIds = topicIds
    }

    enum CodingKeys: String, CodingKey {
            case id = "id"
            case name
            case short_name
            case description
            case trending
            case icon_url
            case topicIds
        }

    
    // Custom decoder to provide default `id`
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try to get `id` from Firestore document data
        if let idValue = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = idValue
        } else {
            self.id = ""
        }
        self.name = try container.decode(String.self, forKey: .name)
        self.short_name = try container.decode(String.self, forKey: .short_name)
        self.description = try container.decode(String.self, forKey: .description)
        self.trending = try container.decode(Int.self, forKey: .trending)
        self.icon_url = try container.decode(String.self, forKey: .icon_url)
        self.topicIds = try container.decodeIfPresent([String].self, forKey: .topicIds) ?? []
    }
}

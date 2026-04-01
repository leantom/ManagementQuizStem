//
//  TopicsViewModel.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 14/11/24.
//


import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct Topic: Identifiable, Codable {
    var id: String
    var name: String
    var category: String
    var description: String?
    var iconURL: String?
    
    var educationLevel: String? // Add the new field
    var trending: Int? = 0 // Default value
}



class TopicsViewModel: ObservableObject {
    @Published var trending = 0
    @Published var name = ""
    @Published var category = ""
    @Published var description = ""
    @Published var iconURL = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    @Published var topics: [Topic] = [] // Store all topics for the Picker
    
    func fetchAllTopics() {
        db.collection("Topics")
            .order(by: "category")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch topics: \(error.localizedDescription)"
                } else {
                    self.topics = snapshot?.documents.compactMap { doc -> Topic? in
                        try? doc.data(as: Topic.self)
                    } ?? []
                    print(self.topics.count)
                }
            }
    }
    
    func fetchAllTopicsASync() async {
        AppState.shared.topics.removeAll()
        do {
            let snapshot = try await db.collection("Topics")
                .order(by: "category")
                .getDocuments()
            let topics = snapshot.documents.compactMap { doc -> Topic? in
                try? doc.data(as: Topic.self)
            }
            DispatchQueue.main.async {
                self.topics = topics
            }
          
            
            AppState.shared.topics.append(contentsOf: topics)
            
        } catch {
            self.errorMessage = "Failed to fetch topics: \(error.localizedDescription)"
        }
    }
    
    func filterTopics(by name: String) -> Topic? {
        topics.first { topic in
            return topic.name == name
        }
    }
    
    func filterTopicsId(by id: String) -> Topic? {
        topics.first { topic in
            return topic.id == id
        }
    }
    
    func filterTopicsCategory(by category: String) -> Topic? {
        topics.first { topic in
            return topic.category == category
        }
    }
    
    func removeTopic(by id: String) {
        db.collection("Topics").document(id).delete { error in
            if let error = error {
                self.errorMessage = "Failed to delete topic: \(error.localizedDescription)"
            } else {
                self.successMessage = "Topic deleted successfully!"
                DispatchQueue.main.async {
                    self.topics.removeAll { $0.id == id }
                }
            }
        }
    }
    
    //MARK: Function to upload a new topic to Firestore
    func uploadTopic(topicData: [String: Any]) {
        guard let name = topicData["name"],
              let category = topicData["category"] as? String,
              let description = topicData["description"],
              let trending = topicData["trending"] else {
            self.errorMessage = "Invalid topic data in CSV file."
            return
        }
        
        let topicExist = filterTopicsCategory(by: category)
        if topicExist != nil {
            print("topic exist : \(topicExist!)")
            return
        }
        
        let topicID = UUID().uuidString
        let topic = [
            "id": topicID,
            "name": name,
            "category": category,
            "description": description,
            "trending": trending,
        ]
        
        db.collection("Topics").document(topicID).setData(topic) { error in
            if let error = error {
                self.errorMessage = "Failed to upload topic: \(error.localizedDescription)"
            } else {
                self.successMessage = "Topic uploaded successfully!"
            }
        }
    }
    
    //MARK: Function to update a topic in Firestore
    func updateTopic(topic: Topic) {
        var updateData: [String: Any] = [:]

        if !topic.name.isEmpty {
            updateData["name"] = topic.name
        }
        if !topic.category.isEmpty {
            updateData["category"] = topic.category
        }
        if let description = topic.description, !description.isEmpty {
            updateData["description"] = description
        }
        if let iconURL = topic.iconURL, !iconURL.isEmpty {
            updateData["iconURL"] = iconURL
        }
        if let trending = topic.trending {
            updateData["trending"] = trending
        }
        if let educationLevel = topic.educationLevel, !educationLevel.isEmpty {
            updateData["educationLevel"] = educationLevel
        }

        guard !updateData.isEmpty else {
            self.errorMessage = "No valid fields to update."
            return
        }

        db.collection("Topics").document(topic.id).updateData(updateData) { error in
            if let error = error {
                self.errorMessage = "Failed to update topic: \(error.localizedDescription)"
                self.successMessage = nil
            } else {
                self.successMessage = "Topic updated successfully!"
                self.errorMessage = nil
            }
        }
    }
    
    func uploadIconImage(topic: Topic, image: NSImage) {
        let storageRef = storage.reference().child("icons/\(topic.id).jpg")
        
        
        // Resize the image to 500x500
        let targetSize = NSSize(width: 500, height: 500)
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()
        
        // Convert the resized image to JPEG data
        guard let resizedImageData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: resizedImageData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            self.errorMessage = "Could not create JPEG data from resized image."
            return
        }
        
        // Upload image data to Firebase Storage
        storageRef.putData(jpegData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                self?.errorMessage = "Failed to upload icon: \(error.localizedDescription)"
                return
            }
            
            // Get the download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    self?.errorMessage = "Failed to retrieve download URL: \(error.localizedDescription)"
                    return
                }
                
                guard let downloadURL = url else {
                    self?.errorMessage = "Download URL not available."
                    return
                }
                
                // Update topic with new icon URL
                var updatedTopic = topic
                updatedTopic.iconURL = downloadURL.absoluteString
                self?.updateTopic(topic: updatedTopic)
            }
        }
    }
    //MARK: Function to upload topics from CSV file
    func uploadTopicsFromCSV(url: URL) {
        do {
            let data = try String(contentsOf: url)
            let rows = data.components(separatedBy: "\n").dropFirst() // Skip the header row

            for (index, row) in rows.enumerated() {
                // Skip empty rows
                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }

                // Use a regular expression to parse CSV respecting quoted fields
                let regex = try NSRegularExpression(pattern: #"(?:[^",]+|"(?:\\.|[^"])*")"#)
                let matches = regex.matches(in: row, range: NSRange(row.startIndex..., in: row))

                // Extract the columns from the matches
                let columns = matches.map { match in
                    String(row[Range(match.range, in: row)!])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }

                // Validate the number of columns
                if columns.count == 4 {
                    let topicData: [String: Any] = [
                        "category": columns[1].trimmingCharacters(in: .whitespaces), // Category
                        "name": columns[0].trimmingCharacters(in: .whitespaces), // Name
                        "description": columns[2].trimmingCharacters(in: .whitespaces), // Description
                        "trending": Int(columns[3].trimmingCharacters(in: .whitespaces)) ?? 0 // Trending as Int
                    ]
                    uploadTopic(topicData: topicData)
                } else {
                    self.errorMessage = "CSV format error at row \(index + 2): Expected 4 columns, found \(columns.count)."
                    break
                }
            }
        } catch {
            self.errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
        }
    }
    
    private func clearFields() {
        name = ""
        category = ""
        description = ""
        iconURL = ""
    }
    
    func updateEducationLevelAll() {
        for topic in topics {
            updateEducationLevel(for: topic)
        }
    }
    
    func updateEducationLevel(for topic: Topic) {
        // Dynamically classify the education level
        let newEducationLevel = classifyEducationLevel(for: topic.category)
        
        // Create a copy of the topic with the updated educationLevel
        var updatedTopic = topic
        updatedTopic.educationLevel = newEducationLevel
        
        // Update the Firestore document
        db.collection("Topics").document(topic.id).updateData([
            "educationLevel": newEducationLevel
        ]) { error in
            if let error = error {
                self.errorMessage = "Failed to update education level: \(error.localizedDescription)"
            } else {
                self.successMessage = "Education level updated successfully!"
            }
        }
    }
    
    
    func classifyEducationLevel(for name: String) -> String {
        let lowercasedName = name.lowercased()
        
        switch lowercasedName {
        case "algebra", "geometry", "trigonometry":
            return "Secondary"
        case "calculus", "statistics & probability", "linear algebra":
            return "High School"
        case "quantum mechanics", "machine learning", "data science":
            return "University"
        case "relativity", "particle physics", "advanced quantum mechanics":
            return "Postgraduate"
        default:
            return "Life Sciences"
        }
    }
}

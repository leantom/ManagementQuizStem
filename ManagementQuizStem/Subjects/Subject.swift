//
//  Subject.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 23/12/24.
//


import FirebaseFirestore
import SwiftUI
import FirebaseStorage

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

class SubjectsViewModel: ObservableObject {
    @Published var subjects: [Subject] = []
    @Published var name = ""
    @Published var shortName = ""
    @Published var description = ""
    @Published var iconURL = ""
    @Published var selectedImage: NSImage?
    @Published var trending = 0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isExist: Bool = false
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - Fetch All Subjects
    func fetchAllSubjects() {
        db.collection("Subjects")
            .order(by: "trending", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Failed to fetch subjects: \(error.localizedDescription)"
                    } else {
                        let resp = snapshot?.documents.compactMap { doc -> Subject? in
                            var sub = try? doc.data(as: Subject.self)
                            //sub.id = doc.documentID
                            return sub
                        } ?? []
                        if resp.isEmpty == false {
                            self.subjects =  resp
                        }
                    }
                }
            }
    }
    // MARK: - Check if Subject Name Exists
    func checkSubjectExists(name: String) {
        db.collection("Subjects")
            .whereField("name", isEqualTo: name)
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to check subject: \(error.localizedDescription)"
                    
                    self.isExist = false
                } else {
                    
                    self.isExist = !(snapshot?.documents.isEmpty ?? true)
                    
                }
            }
    }

    // MARK: - Create New Subject
    func createSubject() {
        guard !name.isEmpty, !shortName.isEmpty, !description.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        if self.selectedImage == nil {
            iconURL = "https://firebasestorage.googleapis.com/v0/b/edu-app-77e5e.appspot.com/o/default-icon.png?alt=media&token=e5e444e4-a45e-4651-a45b-e444e451a45b"
        }
        
        let subjectID = UUID().uuidString
        let newSubject = Subject(
            id: subjectID,
            name: name,
            short_name: shortName,
            description: description,
            trending: trending,
            icon_url: iconURL
        )
        if self.selectedImage != nil {
            uploadIconImage(for: newSubject, image: self.selectedImage!)
        }

        do {
            try db.collection("Subjects").document(subjectID).setData(from: newSubject) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Failed to create subject: \(error.localizedDescription)"
                    } else {
                        self.successMessage = "Subject created successfully!"
                        self.subjects.append(newSubject)
                        self.clearFields()
                    }
                }
            }
        } catch {
            errorMessage = "Error saving subject: \(error.localizedDescription)"
        }
    }

    // MARK: - Update Existing Subject
    func updateSubject(_ subject: Subject, listTopicID: [Topic]) {
        var updateData: [String: Any] = [:]

        if !subject.name.isEmpty { updateData["name"] = subject.name }
        if !subject.short_name.isEmpty { updateData["short_name"] = subject.short_name }
        if !subject.description.isEmpty { updateData["description"] = subject.description }
        if !subject.icon_url.isEmpty { updateData["icon_url"] = subject.icon_url }
        if !listTopicID.isEmpty {
            let topicIDs = listTopicID.map { $0.id }
            updateData["topicIds"] = FieldValue.arrayUnion(topicIDs)
        }
        updateData["trending"] = subject.trending
        print("subject update: \(updateData)")
        
        guard !updateData.isEmpty else {
            errorMessage = "No valid fields to update."
            return
        }

        db.collection("Subjects").document(subject.id!).updateData(updateData) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to update subject: \(error.localizedDescription)"
                    self.successMessage = nil
                } else {
                    self.successMessage = "Subject updated successfully!"
                    self.errorMessage = nil
                   
                }
            }
        }
    }

    // MARK: - Upload Icon Image
    func uploadIconImage(for subject: Subject, image: NSImage) {
        let storageRef = storage.reference().child("icons/\(subject.id).jpg")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            self.errorMessage = "Failed to process image."
            return
        }

        storageRef.putData(jpegData, metadata: nil) { [weak self] _, error in
            if let error = error {
                self?.errorMessage = "Failed to upload icon: \(error.localizedDescription)"
                return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    self?.errorMessage = "Failed to retrieve download URL: \(error.localizedDescription)"
                    return
                }
                guard let downloadURL = url else {
                    self?.errorMessage = "Download URL not available."
                    return
                }
                var updatedSubject = subject
                updatedSubject.icon_url = downloadURL.absoluteString
                self?.updateSubject(updatedSubject, listTopicID: [])
            }
        }
    }

    // MARK: - Clear Fields
    private func clearFields() {
        name = ""
        shortName = ""
        description = ""
        iconURL = ""
        selectedImage = nil
        trending = 0
    }
}



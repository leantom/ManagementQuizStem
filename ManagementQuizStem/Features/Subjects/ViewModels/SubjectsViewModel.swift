import FirebaseFirestore
import FirebaseStorage
import SwiftUI

final class SubjectsViewModel: ObservableObject {
    @Published var subjects: [Subject] = []
    @Published var name = ""
    @Published var shortName = ""
    @Published var description = ""
    @Published var iconURL = ""
    @Published var selectedImage: NSImage?
    @Published var trending = 0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isExist = false

    private let repository = SubjectsRepository()
    private let storage = Storage.storage()

    func fetchAllSubjects() {
        repository.fetchAll { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let subjects):
                    if subjects.isEmpty == false {
                        self.subjects = subjects
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to fetch subjects: \(error.localizedDescription)"
                }
            }
        }
    }

    func checkSubjectExists(name: String) {
        repository.checkExists(named: name) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let exists):
                    self.isExist = exists
                case .failure(let error):
                    self.errorMessage = "Failed to check subject: \(error.localizedDescription)"
                    self.isExist = false
                }
            }
        }
    }

    func createSubject() {
        guard !name.isEmpty, !shortName.isEmpty, !description.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        if selectedImage == nil {
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

        if let selectedImage {
            uploadIconImage(for: newSubject, image: selectedImage)
        }

        do {
            try repository.create(newSubject) { error in
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

    func updateSubject(_ subject: Subject, listTopicID: [Topic]) {
        var updateData: [String: Any] = [:]

        if !subject.name.isEmpty { updateData[FirestoreField.Subject.name] = subject.name }
        if !subject.short_name.isEmpty { updateData[FirestoreField.Subject.shortName] = subject.short_name }
        if !subject.description.isEmpty { updateData[FirestoreField.Subject.description] = subject.description }
        if !subject.icon_url.isEmpty { updateData[FirestoreField.Subject.iconURL] = subject.icon_url }
        if !listTopicID.isEmpty {
            let topicIDs = listTopicID.map(\.id)
            updateData[FirestoreField.Subject.topicIDs] = FieldValue.arrayUnion(topicIDs)
        }
        updateData[FirestoreField.Subject.trending] = subject.trending

        guard let subjectID = subject.id, updateData.isEmpty == false else {
            errorMessage = "No valid subject fields to update."
            return
        }

        repository.update(subjectID: subjectID, data: updateData) { error in
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

    func uploadIconImage(for subject: Subject, image: NSImage) {
        let storageRef = storage.reference().child("icons/\(subject.id).jpg")

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else {
            errorMessage = "Failed to process image."
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

    private func clearFields() {
        name = ""
        shortName = ""
        description = ""
        iconURL = ""
        selectedImage = nil
        trending = 0
    }
}

import AppKit
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

struct Topic: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var category: String
    var description: String?
    var iconURL: String?
    var educationLevel: String?
    var trending: Int? = 0
}

struct TopicBatchImportFailure: Identifiable {
    let id = UUID()
    let topic: Topic
    let errorMessage: String
}

struct TopicBatchImportResult {
    let importedTopics: [Topic]
    let failures: [TopicBatchImportFailure]

    var attemptedCount: Int {
        importedTopics.count + failures.count
    }
}

final class TopicsViewModel: ObservableObject {
    @Published var trending = 0
    @Published var name = ""
    @Published var category = ""
    @Published var description = ""
    @Published var iconURL = ""
    @Published var educationLevel = ""
    @Published var selectedImage: NSImage?

    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var topics: [Topic] = []

    @Published var selectedTopicID: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isCreatingNew = false

    private let repository = TopicsRepository()
    private let storage = Storage.storage()

    var selectedTopic: Topic? {
        topics.first(where: { $0.id == selectedTopicID })
    }

    var selectedTopicReference: String {
        selectedTopicID ?? "DRAFT-NEW"
    }

    var parentSubjectOptions: [String] {
        uniqueSortedValues(from: topics.map(\.name))
    }

    var educationLevelOptions: [String] {
        let defaults = [
            "Core",
            "Advanced",
            "Honors",
            "Secondary",
            "High School",
            "Undergraduate",
            "University",
            "Professional",
            "Postgraduate"
        ]

        return uniqueSortedValues(from: topics.compactMap(\.educationLevel) + defaults)
    }

    var trendingTopicCount: Int {
        topics.filter { ($0.trending ?? 0) > 0 }.count
    }

    var draftWarnings: [String] {
        var warnings: [String] = []

        if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Topic name is required before saving.")
        }

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Parent subject is missing.")
        }

        if educationLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Education level is not assigned.")
        }

        if selectedImage == nil && iconURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Material icon is missing from this topic.")
        }

        return warnings
    }

    func loadLibrary(force: Bool = false) {
        if isLoading && force == false {
            return
        }

        isLoading = true
        errorMessage = nil

        repository.fetchAll { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let topics):
                    self.applyLoadedTopics(topics)
                case .failure(let error):
                    self.errorMessage = "Failed to fetch topics: \(error.localizedDescription)"
                }
            }
        }
    }

    func fetchAllTopics() {
        loadLibrary(force: true)
    }

    func fetchAllTopicsASync() async {
        AppState.shared.topics.removeAll()

        do {
            let topics = try await repository.fetchAll()

            await MainActor.run {
                self.applyLoadedTopics(topics)
            }

            AppState.shared.topics.append(contentsOf: topics)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch topics: \(error.localizedDescription)"
            }
        }
    }

    func filteredTopics(
        matching searchText: String = "",
        parentSubject: String? = nil,
        educationLevel: String? = nil
    ) -> [Topic] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedParentSubject = parentSubject?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEducationLevel = educationLevel?.trimmingCharacters(in: .whitespacesAndNewlines)

        return topics.filter { topic in
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    topic.category.localizedCaseInsensitiveContains(query) ||
                    topic.name.localizedCaseInsensitiveContains(query) ||
                    (topic.description?.localizedCaseInsensitiveContains(query) ?? false) ||
                    topic.id.localizedCaseInsensitiveContains(query)
            }

            let matchesParentSubject: Bool
            if let normalizedParentSubject, normalizedParentSubject.isEmpty == false {
                matchesParentSubject = topic.name.caseInsensitiveCompare(normalizedParentSubject) == .orderedSame
            } else {
                matchesParentSubject = true
            }

            let matchesEducationLevel: Bool
            if let normalizedEducationLevel, normalizedEducationLevel.isEmpty == false {
                matchesEducationLevel = topic.educationLevel?.caseInsensitiveCompare(normalizedEducationLevel) == .orderedSame
            } else {
                matchesEducationLevel = true
            }

            return matchesSearch && matchesParentSubject && matchesEducationLevel
        }
    }

    func selectTopic(_ topic: Topic) {
        selectedTopicID = topic.id
        isCreatingNew = false
        successMessage = nil

        name = topic.name
        category = topic.category
        description = topic.description ?? ""
        iconURL = topic.iconURL ?? ""
        educationLevel = topic.educationLevel ?? ""
        trending = topic.trending ?? 0
        selectedImage = nil
    }

    func startCreatingNewTopic() {
        isCreatingNew = true
        selectedTopicID = nil
        successMessage = nil
        errorMessage = nil

        clearFields()
    }

    func discardDraftChanges() {
        if let selectedTopic {
            selectTopic(selectedTopic)
        } else {
            startCreatingNewTopic()
        }
    }

    func saveTopic() {
        let trimmedParentSubject = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTopicName = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEducationLevel = educationLevel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTopicName.isEmpty == false else {
            errorMessage = "Enter a topic name."
            return
        }

        guard trimmedParentSubject.isEmpty == false else {
            errorMessage = "Enter a parent subject."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let topicID = selectedTopicID ?? UUID().uuidString
        let draft = Topic(
            id: topicID,
            name: trimmedParentSubject,
            category: trimmedTopicName,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            iconURL: iconURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : iconURL.trimmingCharacters(in: .whitespacesAndNewlines),
            educationLevel: trimmedEducationLevel.isEmpty ? nil : trimmedEducationLevel,
            trending: trending
        )

        let persist: (Topic) -> Void = { [weak self] topic in
            guard let self else { return }
            self.persistTopic(topic, isNew: self.selectedTopicID == nil)
        }

        if let selectedImage {
            uploadIconImage(topicID: topicID, image: selectedImage) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }

                    switch result {
                    case .success(let resolvedIconURL):
                        var resolvedTopic = draft
                        resolvedTopic.iconURL = resolvedIconURL
                        self.iconURL = resolvedIconURL
                        persist(resolvedTopic)
                    case .failure(let error):
                        self.isSaving = false
                        self.errorMessage = "Failed to upload icon: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            persist(draft)
        }
    }

    func deleteSelectedTopic() {
        guard let selectedTopicID else {
            errorMessage = "Select a topic before deleting."
            return
        }

        repository.delete(topicID: selectedTopicID) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.errorMessage = "Failed to delete topic: \(error.localizedDescription)"
                    return
                }

                self.successMessage = "Topic deleted successfully."
                self.errorMessage = nil
                self.topics.removeAll { $0.id == selectedTopicID }

                if let replacement = self.topics.first {
                    self.selectTopic(replacement)
                } else {
                    self.startCreatingNewTopic()
                }
            }
        }
    }

    func filterTopics(by name: String) -> Topic? {
        topics.first { topic in
            topic.name == name
        }
    }

    func filterTopicsId(by id: String) -> Topic? {
        topics.first { topic in
            topic.id == id
        }
    }

    func filterTopicsCategory(by category: String) -> Topic? {
        topics.first { topic in
            topic.category == category
        }
    }

    func removeTopic(by id: String) {
        repository.delete(topicID: id) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.errorMessage = "Failed to delete topic: \(error.localizedDescription)"
                } else {
                    self.successMessage = "Topic deleted successfully!"
                    self.topics.removeAll { $0.id == id }
                }
            }
        }
    }

    func uploadTopic(topicData: [String: Any]) {
        guard let name = topicData[FirestoreField.Topic.name],
              let category = topicData[FirestoreField.Topic.category] as? String,
              let description = topicData[FirestoreField.Topic.description],
              let trending = topicData[FirestoreField.Topic.trending] else {
            self.errorMessage = "Invalid topic data in CSV file."
            return
        }

        let topicExist = filterTopicsCategory(by: category)
        if topicExist != nil {
            return
        }

        let topicID = UUID().uuidString
        var topic: [String: Any] = [
            FirestoreField.Topic.id: topicID,
            FirestoreField.Topic.name: name,
            FirestoreField.Topic.category: category,
            FirestoreField.Topic.description: description,
            FirestoreField.Topic.trending: trending
        ]

        if let educationLevel = topicData[FirestoreField.Topic.educationLevel] as? String,
           educationLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            topic[FirestoreField.Topic.educationLevel] = educationLevel
        }

        repository.create(topicID: topicID, data: topic) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.errorMessage = "Failed to upload topic: \(error.localizedDescription)"
                } else {
                    self.successMessage = "Topic uploaded successfully!"
                    self.fetchAllTopics()
                }
            }
        }
    }

    func updateTopic(topic: Topic) {
        repository.update(topicID: topic.id, data: makeUpdateData(for: topic)) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.errorMessage = "Failed to update topic: \(error.localizedDescription)"
                    self.successMessage = nil
                } else {
                    self.replaceLocalTopic(topic)
                    self.successMessage = "Topic updated successfully!"
                    self.errorMessage = nil
                }
            }
        }
    }

    func uploadIconImage(topic: Topic, image: NSImage) {
        uploadIconImage(topicID: topic.id, image: image) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let resolvedIconURL):
                    var updatedTopic = topic
                    updatedTopic.iconURL = resolvedIconURL
                    self.updateTopic(topic: updatedTopic)
                case .failure(let error):
                    self.errorMessage = "Failed to upload icon: \(error.localizedDescription)"
                }
            }
        }
    }

    func uploadTopicsFromCSV(url: URL) {
        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            let rows = data.components(separatedBy: "\n").dropFirst()

            for (index, row) in rows.enumerated() {
                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }

                let regex = try NSRegularExpression(pattern: #"(?:[^",]+|"(?:\\.|[^"])*")"#)
                let matches = regex.matches(in: row, range: NSRange(row.startIndex..., in: row))

                let columns = matches.map { match in
                    String(row[Range(match.range, in: row)!])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }

                if columns.count == 4 {
                    let topicData: [String: Any] = [
                        FirestoreField.Topic.category: columns[1].trimmingCharacters(in: .whitespaces),
                        FirestoreField.Topic.name: columns[0].trimmingCharacters(in: .whitespaces),
                        FirestoreField.Topic.description: columns[2].trimmingCharacters(in: .whitespaces),
                        FirestoreField.Topic.trending: Int(columns[3].trimmingCharacters(in: .whitespaces)) ?? 0
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

    @MainActor
    func importPreparedTopics(_ topics: [Topic]) async -> TopicBatchImportResult {
        guard topics.isEmpty == false else {
            errorMessage = "There are no valid topic rows ready to import."
            successMessage = nil
            return TopicBatchImportResult(importedTopics: [], failures: [])
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        var importedTopics: [Topic] = []
        var failures: [TopicBatchImportFailure] = []

        for topic in topics {
            do {
                try await createTopic(topic)
                importedTopics.append(topic)
                replaceLocalTopic(topic)
            } catch {
                failures.append(
                    TopicBatchImportFailure(
                        topic: topic,
                        errorMessage: error.localizedDescription
                    )
                )
            }
        }

        isSaving = false

        if importedTopics.isEmpty == false {
            successMessage = "Imported \(importedTopics.count) topic\(importedTopics.count == 1 ? "" : "s")."
        } else {
            successMessage = nil
        }

        if failures.isEmpty == false {
            errorMessage = "\(failures.count) topic row\(failures.count == 1 ? "" : "s") failed during import."
        } else {
            errorMessage = nil
        }

        return TopicBatchImportResult(
            importedTopics: importedTopics,
            failures: failures
        )
    }

    func updateEducationLevelAll() {
        for topic in topics {
            updateEducationLevel(for: topic)
        }
    }

    func updateEducationLevel(for topic: Topic) {
        let newEducationLevel = classifyEducationLevel(for: topic.category)
        var updatedTopic = topic
        updatedTopic.educationLevel = newEducationLevel

        repository.updateEducationLevel(
            topicID: topic.id,
            educationLevel: newEducationLevel
        ) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.errorMessage = "Failed to update education level: \(error.localizedDescription)"
                } else {
                    self.replaceLocalTopic(updatedTopic)
                    self.successMessage = "Education level updated successfully!"
                }
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

    private func persistTopic(_ topic: Topic, isNew: Bool) {
        let completion: (Error?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false

                if let error {
                    self.errorMessage = "Failed to save topic: \(error.localizedDescription)"
                    self.successMessage = nil
                    return
                }

                self.replaceLocalTopic(topic)
                self.selectTopic(topic)
                self.successMessage = isNew ? "Topic created successfully." : "Topic updated successfully."
                self.errorMessage = nil
            }
        }

        if isNew {
            repository.create(topicID: topic.id, data: makeTopicData(for: topic), completion: completion)
        } else {
            repository.update(topicID: topic.id, data: makeUpdateData(for: topic), completion: completion)
        }
    }

    private func makeTopicData(for topic: Topic) -> [String: Any] {
        var data: [String: Any] = [
            FirestoreField.Topic.id: topic.id,
            FirestoreField.Topic.name: topic.name,
            FirestoreField.Topic.category: topic.category,
            FirestoreField.Topic.trending: topic.trending ?? 0
        ]

        if let description = topic.description, description.isEmpty == false {
            data[FirestoreField.Topic.description] = description
        }

        if let iconURL = topic.iconURL, iconURL.isEmpty == false {
            data[FirestoreField.Topic.iconURL] = iconURL
        }

        if let educationLevel = topic.educationLevel, educationLevel.isEmpty == false {
            data[FirestoreField.Topic.educationLevel] = educationLevel
        }

        return data
    }

    private func makeUpdateData(for topic: Topic) -> [String: Any] {
        var updateData: [String: Any] = [
            FirestoreField.Topic.name: topic.name,
            FirestoreField.Topic.category: topic.category,
            FirestoreField.Topic.trending: topic.trending ?? 0
        ]

        if let description = topic.description, description.isEmpty == false {
            updateData[FirestoreField.Topic.description] = description
        } else {
            updateData[FirestoreField.Topic.description] = FieldValue.delete()
        }

        if let iconURL = topic.iconURL, iconURL.isEmpty == false {
            updateData[FirestoreField.Topic.iconURL] = iconURL
        } else {
            updateData[FirestoreField.Topic.iconURL] = FieldValue.delete()
        }

        if let educationLevel = topic.educationLevel, educationLevel.isEmpty == false {
            updateData[FirestoreField.Topic.educationLevel] = educationLevel
        } else {
            updateData[FirestoreField.Topic.educationLevel] = FieldValue.delete()
        }

        return updateData
    }

    private func uploadIconImage(
        topicID: String,
        image: NSImage,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let storageRef = storage.reference().child("icons/\(topicID).jpg")
        let targetSize = NSSize(width: 500, height: 500)
        let resizedImage = NSImage(size: targetSize)

        resizedImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()

        guard
            let resizedImageData = resizedImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: resizedImageData),
            let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else {
            completion(.failure(NSError(domain: "TopicsViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create JPEG data from resized image."
            ])))
            return
        }

        storageRef.putData(jpegData, metadata: nil) { _, error in
            if let error {
                completion(.failure(error))
                return
            }

            storageRef.downloadURL { url, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let url else {
                    completion(.failure(NSError(domain: "TopicsViewModel", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "Download URL not available."
                    ])))
                    return
                }

                completion(.success(url.absoluteString))
            }
        }
    }

    private func createTopic(_ topic: Topic) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            repository.create(topicID: topic.id, data: makeTopicData(for: topic)) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func applyLoadedTopics(_ loadedTopics: [Topic]) {
        topics = loadedTopics.sorted {
            $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
        }

        if let selectedTopicID,
           let topic = topics.first(where: { $0.id == selectedTopicID }) {
            selectTopic(topic)
        } else if topics.isEmpty {
            startCreatingNewTopic()
        } else if isCreatingNew {
            return
        } else if let firstTopic = topics.first {
            selectTopic(firstTopic)
        }
    }

    private func replaceLocalTopic(_ topic: Topic) {
        if let index = topics.firstIndex(where: { $0.id == topic.id }) {
            topics[index] = topic
        } else {
            topics.append(topic)
        }

        topics.sort {
            $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
        }
    }

    private func uniqueSortedValues(from values: [String]) -> [String] {
        let deduplicated = values.reduce(into: [String]()) { result, value in
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedValue.isEmpty == false else { return }

            if result.contains(where: { $0.caseInsensitiveCompare(trimmedValue) == .orderedSame }) == false {
                result.append(trimmedValue)
            }
        }

        return deduplicated.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func clearFields() {
        trending = 0
        name = ""
        category = ""
        description = ""
        iconURL = ""
        educationLevel = ""
        selectedImage = nil
    }
}

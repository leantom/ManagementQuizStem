import FirebaseFirestore
import FirebaseStorage
import SwiftUI

enum SubjectCurriculumLevel: String, CaseIterable {
    case core = "Core"
    case advanced = "Advanced"
    case honors = "Honors"
}

enum SubjectCategoryMapping: String, CaseIterable {
    case science = "Science"
    case technology = "Technology"
    case engineering = "Engineering"
    case math = "Math"
    case arts = "Arts"

    static func mapping(for subjectName: String) -> SubjectCategoryMapping {
        switch subjectName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "science", "physics", "chemistry", "biology", "earth science":
            return .science
        case "technology", "computer science", "technology & innovation", "aws certified developer - associate":
            return .technology
        case "engineering":
            return .engineering
        case "mathematics", "math":
            return .math
        case "arts", "art", "music", "design":
            return .arts
        default:
            return .science
        }
    }

    var icon: String {
        switch self {
        case .science:
            return "flask.fill"
        case .technology:
            return "desktopcomputer"
        case .engineering:
            return "gearshape.2.fill"
        case .math:
            return "function"
        case .arts:
            return "paintpalette.fill"
        }
    }
}

final class SubjectsViewModel: ObservableObject {
    @Published var subjects: [Subject] = []
    @Published var topics: [Topic] = []

    @Published var name = ""
    @Published var shortName = ""
    @Published var description = ""
    @Published var iconURL = ""
    @Published var colorHex = "FFFFFF"
    @Published var selectedImage: NSImage?

    @Published var selectedSubjectID: String?
    @Published var selectedTopicIDs: Set<String> = []
    @Published var selectedCategoryMapping = SubjectCategoryMapping.science.rawValue
    @Published var selectedCurriculumLevel = SubjectCurriculumLevel.core.rawValue
    @Published var totalQuestionCount = 0

    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isCreatingNew = false

    private let repository = SubjectsRepository()
    private let topicsRepository = TopicsRepository()
    private let questionsRepository = QuestionsRepository()
    private let storage = Storage.storage()

    var selectedSubject: Subject? {
        subjects.first(where: { $0.id == selectedSubjectID })
    }

    var categoryMappings: [String] {
        SubjectCategoryMapping.allCases.map(\.rawValue)
    }

    var curriculumLevels: [SubjectCurriculumLevel] {
        SubjectCurriculumLevel.allCases
    }

    var selectedTopicCount: Int {
        resolvedTopicsForCurrentDraft().count
    }

    var selectedPassingRate: Double {
        let baseValue = Double(selectedSubject?.trending ?? max(64, min(96, 60 + selectedTopicCount * 4)))
        return min(max(baseValue, 0), 100)
    }

    var selectedSubjectReference: String {
        let rawReference = shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        return rawReference.isEmpty ? "DRAFT-NEW" : rawReference.uppercased()
    }

    var subjectSlug: String {
        let rawValue = shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawValue.isEmpty == false {
            return rawValue.lowercased()
        }

        return makeSlug(from: name)
    }

    var selectedCategoryIcon: String {
        SubjectCategoryMapping(rawValue: selectedCategoryMapping)?.icon ?? "books.vertical.fill"
    }

    func loadLibrary() {
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()
        var loadedSubjects: [Subject] = []
        var loadedTopics: [Topic] = []
        var capturedError: String?

        group.enter()
        repository.fetchAll { result in
            defer { group.leave() }

            switch result {
            case .success(let subjects):
                loadedSubjects = subjects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .failure(let error):
                capturedError = "Failed to fetch subjects: \(error.localizedDescription)"
            }
        }

        group.enter()
        topicsRepository.fetchAll { result in
            defer { group.leave() }

            switch result {
            case .success(let topics):
                loadedTopics = topics.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .failure(let error):
                capturedError = capturedError ?? "Failed to fetch topics: \(error.localizedDescription)"
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
            self.subjects = loadedSubjects
            self.topics = loadedTopics

            if let capturedError {
                self.errorMessage = capturedError
            }

            if let selectedSubjectID = self.selectedSubjectID,
               let subject = loadedSubjects.first(where: { $0.id == selectedSubjectID }) {
                self.selectSubject(subject)
            } else if let firstSubject = loadedSubjects.first {
                self.selectSubject(firstSubject)
            } else {
                self.startCreatingNewSubject()
            }
        }
    }

    func filteredSubjects(matching searchText: String = "") -> [Subject] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return subjects }

        return subjects.filter { subject in
            subject.name.localizedCaseInsensitiveContains(query) ||
            subject.short_name.localizedCaseInsensitiveContains(query) ||
            subject.description.localizedCaseInsensitiveContains(query) ||
            (subject.id?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func selectSubject(_ subject: Subject) {
        selectedSubjectID = subject.id
        isCreatingNew = false
        successMessage = nil

        name = subject.name
        shortName = subject.short_name
        description = subject.description
        iconURL = subject.icon_url
        colorHex = subject.color_hex ?? "fff"
        selectedImage = nil

        let linkedTopics = resolvedTopics(for: subject)
        selectedTopicIDs = Set(linkedTopics.map(\.id))
        selectedCategoryMapping = SubjectCategoryMapping.mapping(for: subject.name).rawValue
        selectedCurriculumLevel = derivedCurriculumLevel(from: linkedTopics).rawValue

        refreshQuestionCount(for: linkedTopics.map(\.id))
    }

    func startCreatingNewSubject() {
        isCreatingNew = true
        selectedSubjectID = nil
        successMessage = nil
        errorMessage = nil

        name = ""
        shortName = ""
        description = ""
        iconURL = ""
        colorHex = "FFFFFF"
        selectedImage = nil
        selectedTopicIDs = []
        selectedCategoryMapping = SubjectCategoryMapping.science.rawValue
        selectedCurriculumLevel = SubjectCurriculumLevel.core.rawValue
        totalQuestionCount = 0
    }

    func archiveSelectedSubject() {
        errorMessage = "Archive subject is not wired to Firestore yet."
    }

    func saveSubject() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedShortName = shortName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            errorMessage = "Enter a subject display name."
            return
        }

        guard trimmedDescription.isEmpty == false else {
            errorMessage = "Enter a subject description."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let subjectID = selectedSubjectID ?? UUID().uuidString
        let resolvedShortName = trimmedShortName.isEmpty ? makeSlug(from: trimmedName) : trimmedShortName
        let linkedTopics = resolvedTopicsForCurrentDraft()
        let resolvedColorHex = normalizedColorHex(colorHex)

        let finalizeSave: (String) -> Void = { resolvedIconURL in
            let subject = Subject(
                id: subjectID,
                name: trimmedName,
                short_name: resolvedShortName,
                description: trimmedDescription,
                trending: self.selectedSubject?.trending ?? Int(self.selectedPassingRate.rounded()),
                icon_url: resolvedIconURL,
                color_hex: resolvedColorHex,
                topicIds: linkedTopics.map(\.id)
            )

            self.persistSubject(subject, linkedTopics: linkedTopics, isNew: self.selectedSubjectID == nil)
        }

        if let selectedImage {
            uploadIconImage(subjectID: subjectID, image: selectedImage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let remoteURL):
                        finalizeSave(remoteURL)
                    case .failure(let error):
                        self.isSaving = false
                        self.errorMessage = "Failed to upload icon: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            let resolvedIconURL = iconURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultIconURL
                : iconURL.trimmingCharacters(in: .whitespacesAndNewlines)
            finalizeSave(resolvedIconURL)
        }
    }

    func resolvedTopicsForCurrentDraft() -> [Topic] {
        guard selectedTopicIDs.isEmpty == false else { return [] }

        return topics.filter { selectedTopicIDs.contains($0.id) }
    }

    func isTopicSelected(_ topic: Topic) -> Bool {
        selectedTopicIDs.contains(topic.id)
    }

    func toggleTopicSelection(_ topic: Topic) {
        if selectedTopicIDs.contains(topic.id) {
            selectedTopicIDs.remove(topic.id)
        } else {
            selectedTopicIDs.insert(topic.id)
        }

        refreshQuestionCount(for: Array(selectedTopicIDs))
    }

    func categoryMapping(for subject: Subject) -> String {
        SubjectCategoryMapping.mapping(for: subject.name).rawValue
    }

    func subjectReference(for subject: Subject) -> String {
        let reference = subject.short_name.trimmingCharacters(in: .whitespacesAndNewlines)
        return reference.isEmpty ? "SUB-\(subject.id?.prefix(4).uppercased() ?? "NEW")" : reference.uppercased()
    }

    func topicCount(for subject: Subject) -> Int {
        resolvedTopics(for: subject).count
    }

    func lastUpdatedLabel(for subject: Subject) -> String {
        let suffix = subject.id?.suffix(4).uppercased() ?? "LIVE"
        return "SYNC-\(suffix)"
    }

    private func persistSubject(_ subject: Subject, linkedTopics: [Topic], isNew: Bool) {
        let completion: (Error?) -> Void = { error in
            DispatchQueue.main.async {
                if let error {
                    self.isSaving = false
                    self.errorMessage = "Failed to save subject: \(error.localizedDescription)"
                    return
                }

                self.syncCurriculumLevel(for: linkedTopics, to: self.selectedCurriculumLevel)
                self.replaceLocalSubject(subject)
                self.selectedSubjectID = subject.id
                self.isCreatingNew = false
                self.iconURL = subject.icon_url
                self.colorHex = subject.color_hex ?? "ffffff"
                self.selectedImage = nil
                self.successMessage = isNew ? "Subject created successfully!" : "Subject updated successfully!"
                self.refreshQuestionCount(for: linkedTopics.map(\.id))
                self.isSaving = false
            }
        }

        if isNew {
            do {
                try repository.create(subject, completion: completion)
            } catch {
                isSaving = false
                errorMessage = "Failed to save subject: \(error.localizedDescription)"
            }
            return
        }

        let updateData = makeUpdateData(for: subject)
        guard let subjectID = subject.id else {
            isSaving = false
            errorMessage = "Missing subject ID."
            return
        }

        repository.update(subjectID: subjectID, data: updateData, completion: completion)
    }

    private func makeUpdateData(for subject: Subject) -> [String: Any] {
        var updateData: [String: Any] = [
            FirestoreField.Subject.name: subject.name,
            FirestoreField.Subject.shortName: subject.short_name,
            FirestoreField.Subject.description: subject.description,
            FirestoreField.Subject.trending: subject.trending,
            FirestoreField.Subject.colorHex: subject.color_hex,
            FirestoreField.Subject.topicIDs: subject.topicIds ?? []
        ]

        if subject.icon_url.isEmpty == false {
            updateData[FirestoreField.Subject.iconURL] = subject.icon_url
        }

        return updateData
    }

    private func replaceLocalSubject(_ subject: Subject) {
        if let index = subjects.firstIndex(where: { $0.id == subject.id }) {
            subjects[index] = subject
        } else {
            subjects.append(subject)
        }

        subjects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func resolvedTopics(for subject: Subject) -> [Topic] {
        if let topicIDs = subject.topicIds, topicIDs.isEmpty == false {
            let explicitlyLinkedTopics = topics.filter { topicIDs.contains($0.id) }
            if explicitlyLinkedTopics.isEmpty == false {
                return explicitlyLinkedTopics
            }
        }

        let normalizedName = subject.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return topics.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
        }
    }

    private func refreshQuestionCount(for topicIDs: [String]) {
        questionsRepository.countQuestions(topicIDs: topicIDs) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    self.totalQuestionCount = count
                case .failure(let error):
                    self.totalQuestionCount = 0
                    self.errorMessage = "Failed to load subject metrics: \(error.localizedDescription)"
                }
            }
        }
    }

    private func derivedCurriculumLevel(from topics: [Topic]) -> SubjectCurriculumLevel {
        let normalizedLevels = topics.compactMap { topic in
            SubjectCurriculumLevel.allCases.first {
                topic.educationLevel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == $0.rawValue.lowercased()
            }
        }

        guard normalizedLevels.isEmpty == false else {
            return .core
        }

        if normalizedLevels.contains(.honors) { return .honors }
        if normalizedLevels.contains(.advanced) { return .advanced }
        return .core
    }

    private func syncCurriculumLevel(for linkedTopics: [Topic], to level: String) {
        guard linkedTopics.isEmpty == false else { return }

        linkedTopics.forEach { topic in
            topicsRepository.updateEducationLevel(topicID: topic.id, educationLevel: level) { _ in }
        }

        topics = topics.map { topic in
            guard linkedTopics.contains(where: { $0.id == topic.id }) else { return topic }
            var updatedTopic = topic
            updatedTopic.educationLevel = level
            return updatedTopic
        }
    }

    private func uploadIconImage(
        subjectID: String,
        image: NSImage,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let storageRef = storage.reference().child("icons/\(subjectID).jpg")

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else {
            completion(.failure(NSError(domain: "SubjectsViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to process image."
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
                    completion(.failure(NSError(domain: "SubjectsViewModel", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "Download URL not available."
                    ])))
                    return
                }

                completion(.success(url.absoluteString))
            }
        }
    }

    private func makeSlug(from rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")
    }

    private func normalizedColorHex(_ rawValue: String) -> String {
        let sanitized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .uppercased()

        guard sanitized.count == 6,
              sanitized.allSatisfy({ $0.isHexDigit }) else {
            return "FFFFFF"
        }

        return sanitized
    }

    private static let defaultIconURL = "https://firebasestorage.googleapis.com/v0/b/edu-app-77e5e.appspot.com/o/default-icon.png?alt=media&token=e5e444e4-a45e-4651-a45b-e444e451a45b"
}

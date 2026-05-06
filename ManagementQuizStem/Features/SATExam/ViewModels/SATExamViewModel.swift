import Foundation
import FirebaseFirestore

final class SATExamViewModel: ObservableObject {
    @Published var analysis: SATExamImportAnalysis?
    @Published var libraryQuestions: [SATExamQuestion] = []
    @Published var isLoadingLibrary = false
    @Published var isUploading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let repository = SATExamQuestionsRepository()

    var importedQuestionCount: Int {
        analysis?.questionCount ?? 0
    }

    var existingQuestionCount: Int {
        libraryQuestions.count
    }

    var duplicateImportCount: Int {
        guard let analysis else { return 0 }

        let existingIDs = Set(libraryQuestions.compactMap(\.id))
        return analysis.importedQuestions.filter { existingIDs.contains($0.id) }.count
    }

    var newImportCount: Int {
        max(0, importedQuestionCount - duplicateImportCount)
    }

    func loadLibrary(force: Bool = false) {
        if isLoadingLibrary && force == false {
            return
        }

        isLoadingLibrary = true
        errorMessage = nil

        repository.fetchAll { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                self.isLoadingLibrary = false

                switch result {
                case .success(let questions):
                    self.libraryQuestions = questions
                case .failure(let error):
                    self.errorMessage = "Failed to load SAT exam library: \(error.localizedDescription)"
                }
            }
        }
    }

    func importSATExamJSON(from url: URL) {
        successMessage = nil
        errorMessage = nil

        do {
            let data = try Data(contentsOf: url)
            let importedQuestions = try JSONDecoder().decode([SATExamQuestionImport].self, from: data)
            let validationWarnings = validate(importedQuestions)

            guard validationWarnings.isEmpty else {
                analysis = nil
                errorMessage = validationWarnings.joined(separator: " ")
                return
            }

            analysis = SATExamImportAnalysis(fileURL: url, importedQuestions: importedQuestions)
            successMessage = "Loaded \(importedQuestions.count) SAT exam questions from \(url.lastPathComponent)."
        } catch {
            analysis = nil
            errorMessage = jsonImportErrorMessage(for: error)
        }
    }

    func uploadImportedQuestions() {
        guard let analysis, analysis.importedQuestions.isEmpty == false else {
            errorMessage = "Choose a SAT exam JSON file before uploading."
            return
        }

        isUploading = true
        successMessage = nil
        errorMessage = nil

        let importedIDs = analysis.importedQuestions.map(\.documentID)

        repository.fetchExistingQuestionIDs(importedIDs) { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isUploading = false
                    self.errorMessage = "Failed to check existing SAT questions: \(error.localizedDescription)"
                }
            case .success(let existingIDs):
                self.commitNewQuestions(from: analysis, excluding: existingIDs)
            }
        }
    }

    private func commitNewQuestions(
        from analysis: SATExamImportAnalysis,
        excluding existingIDs: Set<String>
    ) {
        let newImports = analysis.importedQuestions.filter { existingIDs.contains($0.id) == false }

        guard newImports.isEmpty == false else {
            DispatchQueue.main.async {
                self.isUploading = false
                self.successMessage = "No new SAT questions to upload. \(existingIDs.count) already exist."
                self.loadLibrary(force: true)
            }
            return
        }

        commitQuestionChunks(
            Array(newImports),
            skippedDuplicateCount: existingIDs.count,
            uploadedCount: 0
        )
    }

    private func commitQuestionChunks(
        _ imports: [SATExamQuestionImport],
        skippedDuplicateCount: Int,
        uploadedCount: Int
    ) {
        let batchLimit = 450
        let chunk = Array(imports.prefix(batchLimit))
        let remaining = Array(imports.dropFirst(batchLimit))

        guard chunk.isEmpty == false else {
            DispatchQueue.main.async {
                self.isUploading = false
                self.successMessage = "Uploaded \(uploadedCount) SAT exam questions. Skipped \(skippedDuplicateCount) duplicates."
                self.loadLibrary(force: true)
            }
            return
        }

        let batch = repository.makeBatch()
        let now = Date()

        do {
            for importedQuestion in chunk {
                try repository.addImportedQuestion(
                    to: batch,
                    question: importedQuestion.makeQuestion(now: now)
                )
            }
        } catch {
            DispatchQueue.main.async {
                self.isUploading = false
                self.errorMessage = error.localizedDescription
            }
            return
        }

        repository.commit(batch) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.isUploading = false
                    self.errorMessage = "Failed to upload SAT exam questions: \(error.localizedDescription)"
                } else {
                    self.commitQuestionChunks(
                        remaining,
                        skippedDuplicateCount: skippedDuplicateCount,
                        uploadedCount: uploadedCount + chunk.count
                    )
                }
            }
        }
    }

    private func validate(_ imports: [SATExamQuestionImport]) -> [String] {
        if imports.isEmpty {
            return ["The selected JSON file does not contain any SAT exam questions."]
        }

        var warnings: [String] = []
        let duplicateIDs = Dictionary(grouping: imports, by: \.documentID)
            .filter { $0.value.count > 1 }
            .keys

        if duplicateIDs.isEmpty == false {
            warnings.append("Duplicate SAT question IDs found: \(duplicateIDs.sorted().prefix(5).joined(separator: ", ")).")
        }

        let invalidQuestions = imports.filter { item in
            item.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            item.question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            item.question.paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            item.question.choices.count < 2 ||
            item.question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if invalidQuestions.isEmpty == false {
            warnings.append("\(invalidQuestions.count) questions are missing required SAT fields.")
        }

        return warnings
    }

    private func jsonImportErrorMessage(for error: Error) -> String {
        switch error {
        case let DecodingError.keyNotFound(key, context):
            let path = (context.codingPath + [key]).map(\.stringValue).joined(separator: ".")
            return "Failed to import SAT exam JSON: missing field '\(path)'."
        case let DecodingError.typeMismatch(_, context),
             let DecodingError.valueNotFound(_, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            if path.isEmpty {
                return "Failed to import SAT exam JSON: invalid JSON structure."
            }
            return "Failed to import SAT exam JSON: invalid value at '\(path)'."
        case let DecodingError.dataCorrupted(context):
            return "Failed to import SAT exam JSON: \(context.debugDescription)"
        default:
            return "Failed to import SAT exam JSON: \(error.localizedDescription)"
        }
    }
}

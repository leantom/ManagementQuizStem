import FirebaseFirestore
import Foundation

struct SATExamQuestion: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var sourceID: String
    var domain: String
    var difficulty: String
    var passage: String
    var prompt: String
    var options: [String]
    var choiceLabels: [String]
    var correctAnswer: String
    var explanation: String
    var visualType: String?
    var svgContent: String?
    var source: String
    var createdAt: Date
    var updatedAt: Date
}

struct SATExamQuestionImport: Identifiable, Decodable, Hashable {
    let sourceID: String
    let domain: String
    let visuals: SATExamVisualsImport?
    let question: SATExamQuestionPayloadImport
    let difficulty: String

    var id: String {
        documentID
    }

    var documentID: String {
        let rawID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = sanitizedDocumentIDComponent(rawID.isEmpty ? "sat-question" : rawID)
        return "\(prefix)-\(stableContentHash(question.question + question.paragraph))"
    }

    enum CodingKeys: String, CodingKey {
        case sourceID = "id"
        case domain
        case visuals
        case question
        case difficulty
    }

    func makeQuestion(now: Date = Date()) -> SATExamQuestion {
        let sortedChoices = question.choices.sorted { lhs, rhs in
            lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
        }

        let visualType = normalizedOptional(visuals?.type)
        let svgContent = normalizedOptional(visuals?.svgContent)

        return SATExamQuestion(
            id: documentID,
            sourceID: sourceID.trimmingCharacters(in: .whitespacesAndNewlines),
            domain: domain.trimmingCharacters(in: .whitespacesAndNewlines),
            difficulty: difficulty.trimmingCharacters(in: .whitespacesAndNewlines),
            passage: question.paragraph.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: question.question.trimmingCharacters(in: .whitespacesAndNewlines),
            options: sortedChoices.map(\.value),
            choiceLabels: sortedChoices.map(\.key),
            correctAnswer: question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
            explanation: question.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
            visualType: visualType,
            svgContent: svgContent,
            source: "SAT",
            createdAt: now,
            updatedAt: now
        )
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false,
              value.lowercased() != "null" else {
            return nil
        }

        return value
    }

    private func sanitizedDocumentIDComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }

        let sanitized = String(scalars)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
            .lowercased()

        return sanitized.isEmpty ? "sat-question" : sanitized
    }

    private func stableContentHash(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }

        return String(format: "%016llx", hash)
    }
}

struct SATExamVisualsImport: Decodable, Hashable {
    let type: String?
    let svgContent: String?

    enum CodingKeys: String, CodingKey {
        case type
        case svgContent = "svg_content"
    }
}

struct SATExamQuestionPayloadImport: Decodable, Hashable {
    let choices: [String: String]
    let question: String
    let paragraph: String
    let explanation: String
    let correctAnswer: String

    enum CodingKeys: String, CodingKey {
        case choices
        case question
        case paragraph
        case explanation
        case correctAnswer = "correct_answer"
    }
}

struct SATExamImportAnalysis {
    let fileURL: URL
    let importedQuestions: [SATExamQuestionImport]

    var fileName: String {
        fileURL.lastPathComponent
    }

    var questionCount: Int {
        importedQuestions.count
    }

    var domains: [String] {
        Self.uniqueSortedValues(from: importedQuestions.map(\.domain))
    }

    var difficulties: [String] {
        Self.uniqueSortedValues(from: importedQuestions.map(\.difficulty))
    }

    var domainCounts: [(domain: String, count: Int)] {
        countValues(importedQuestions.map(\.domain))
    }

    var difficultyCounts: [(difficulty: String, count: Int)] {
        countValues(importedQuestions.map(\.difficulty))
    }

    var previewQuestions: [SATExamQuestionImport] {
        Array(importedQuestions.prefix(8))
    }

    private func countValues(_ values: [String]) -> [(String, Int)] {
        let counts = Dictionary(grouping: values) { value in
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .mapValues(\.count)

        return counts
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.localizedStandardCompare(rhs.0) == .orderedAscending
                }

                return lhs.1 > rhs.1
            }
    }

    private static func uniqueSortedValues(from values: [String]) -> [String] {
        Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { $0.isEmpty == false }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

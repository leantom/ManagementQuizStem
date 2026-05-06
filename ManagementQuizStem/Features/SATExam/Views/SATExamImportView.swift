import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SATExamImportView: View {
    @StateObject private var viewModel = SATExamViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            metrics
            mainContent

            if let successMessage = viewModel.successMessage {
                SATExamInlineBanner(title: "SAT exam update", message: successMessage, tint: SATExamPalette.success)
            }

            if let errorMessage = viewModel.errorMessage {
                SATExamInlineBanner(title: "Import warning", message: errorMessage, tint: SATExamPalette.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task {
            viewModel.loadLibrary()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Exams")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(SATExamPalette.subtleInk)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SATExamPalette.subtleInk.opacity(0.7))

                    Text("SAT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(SATExamPalette.primary)
                }

                Text("SAT Exam Import")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(SATExamPalette.ink)

                Text("Import SAT reading and writing exam questions into a dedicated Firestore collection with domain, difficulty, passage, answer, and explanation metadata.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(SATExamPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                Button {
                    selectJSONFile()
                } label: {
                    Label("Choose SAT JSON", systemImage: "doc.badge.plus")
                }
                .buttonStyle(SATExamSecondaryButtonStyle())

                Button {
                    viewModel.uploadImportedQuestions()
                } label: {
                    Label(viewModel.isUploading ? "Uploading..." : "Upload Questions", systemImage: "arrow.up.doc.fill")
                }
                .buttonStyle(SATExamPrimaryButtonStyle())
                .disabled(viewModel.analysis == nil || viewModel.isUploading)
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: 14) {
            SATExamMetricCard(
                title: "Imported File",
                value: "\(viewModel.importedQuestionCount)",
                caption: viewModel.analysis?.fileName ?? "No file selected",
                icon: "doc.text.magnifyingglass"
            )

            SATExamMetricCard(
                title: "New Questions",
                value: "\(viewModel.newImportCount)",
                caption: "\(viewModel.duplicateImportCount) duplicates detected",
                icon: "plus.rectangle.on.folder.fill"
            )

            SATExamMetricCard(
                title: "SAT Library",
                value: "\(viewModel.existingQuestionCount)",
                caption: viewModel.isLoadingLibrary ? "Loading Firestore..." : "Questions in Firestore",
                icon: "graduationcap.fill"
            )
        }
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 18) {
            SATExamCard(title: "Package Preview") {
                if let analysis = viewModel.analysis {
                    VStack(alignment: .leading, spacing: 18) {
                        packageSummary(analysis)
                        Divider()
                            .overlay(SATExamPalette.border)
                        previewList(analysis)
                    }
                } else {
                    emptyImportState
                }
            }

            VStack(spacing: 18) {
                SATExamCard(title: "Domain Mix") {
                    if let analysis = viewModel.analysis {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(analysis.domainCounts, id: \.domain) { item in
                                SATExamDistributionRow(
                                    title: item.domain,
                                    value: item.count,
                                    total: max(analysis.questionCount, 1),
                                    tint: SATExamPalette.primary
                                )
                            }
                        }
                    } else {
                        SATExamMutedText("Domains appear after a SAT JSON file is selected.")
                    }
                }

                SATExamCard(title: "Difficulty") {
                    if let analysis = viewModel.analysis {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(analysis.difficultyCounts, id: \.difficulty) { item in
                                SATExamDistributionRow(
                                    title: item.difficulty,
                                    value: item.count,
                                    total: max(analysis.questionCount, 1),
                                    tint: SATExamPalette.accent
                                )
                            }
                        }
                    } else {
                        SATExamMutedText("Difficulty distribution appears after validation.")
                    }
                }
            }
            .frame(width: 330)
        }
    }

    private func packageSummary(_ analysis: SATExamImportAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SATExamPalette.primary.opacity(0.12))

                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(SATExamPalette.primary)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 5) {
                    Text(analysis.fileName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(SATExamPalette.ink)

                    Text("\(analysis.questionCount) questions across \(analysis.domains.count) SAT domains.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(SATExamPalette.subtleInk)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ForEach(analysis.domains.prefix(4), id: \.self) { domain in
                    SATExamTag(title: domain, tint: SATExamPalette.primary)
                }

                if analysis.domains.count > 4 {
                    SATExamTag(title: "+\(analysis.domains.count - 4)", tint: SATExamPalette.subtleInk)
                }
            }
        }
    }

    private func previewList(_ analysis: SATExamImportAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Question Preview")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SATExamPalette.ink)

            LazyVStack(spacing: 10) {
                ForEach(analysis.previewQuestions) { item in
                    SATExamQuestionPreviewRow(item: item)
                }
            }
        }
    }

    private var emptyImportState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SATExamPalette.primary.opacity(0.12))

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(SATExamPalette.primary)
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 6) {
                    Text("No SAT package selected")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(SATExamPalette.ink)

                    Text("Choose a JSON array with SAT question IDs, domains, passages, answer choices, correct answers, explanations, and optional visuals.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(SATExamPalette.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                selectJSONFile()
            } label: {
                Label("Select JSON File", systemImage: "plus.circle.fill")
            }
            .buttonStyle(SATExamPrimaryButtonStyle())
        }
    }

    private func selectJSONFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importSATExamJSON(from: url)
        }
    }
}

private struct SATExamQuestionPreviewRow: View {
    let item: SATExamQuestionImport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SATExamTag(title: item.domain, tint: SATExamPalette.primary)
                SATExamTag(title: item.difficulty, tint: SATExamPalette.accent)
                Spacer(minLength: 0)
                Text(item.id)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(SATExamPalette.subtleInk)
                    .lineLimit(1)
            }

            Text(item.question.question)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(SATExamPalette.ink)
                .lineLimit(2)

            Text(item.question.paragraph)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(SATExamPalette.subtleInk)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SATExamPalette.surfaceSecondary)
        )
    }
}

private struct SATExamDistributionRow: View {
    let title: String
    let value: Int
    let total: Int
    let tint: Color

    private var progress: CGFloat {
        CGFloat(value) / CGFloat(max(total, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(SATExamPalette.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(value)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(SATExamPalette.border.opacity(0.8))

                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct SATExamMetricCard: View {
    let title: String
    let value: String
    let caption: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SATExamPalette.primary.opacity(0.12))

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SATExamPalette.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(SATExamPalette.subtleInk)

                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(SATExamPalette.ink)

                Text(caption)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(SATExamPalette.subtleInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SATExamPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SATExamPalette.border, lineWidth: 1)
        )
    }
}

private struct SATExamCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SATExamPalette.ink)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SATExamPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SATExamPalette.border, lineWidth: 1)
        )
    }
}

private struct SATExamInlineBanner: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(SATExamPalette.ink)

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SATExamPalette.subtleInk)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}

private struct SATExamTag: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct SATExamMutedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(SATExamPalette.subtleInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SATExamPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SATExamPalette.primary.opacity(configuration.isPressed ? 0.82 : 1))
            )
    }
}

private struct SATExamSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(SATExamPalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? SATExamPalette.border.opacity(0.7) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SATExamPalette.border, lineWidth: 1)
            )
    }
}

private enum SATExamPalette {
    static let primary = Color(red: 0.08, green: 0.36, blue: 0.72)
    static let accent = Color(red: 0.71, green: 0.28, blue: 0.20)
    static let success = Color(red: 0.10, green: 0.55, blue: 0.32)
    static let danger = Color(red: 0.74, green: 0.18, blue: 0.22)
    static let surface = Color.white
    static let surfaceSecondary = Color(red: 0.96, green: 0.98, blue: 0.99)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.35, green: 0.39, blue: 0.49)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
}

#Preview {
    SATExamImportView()
}

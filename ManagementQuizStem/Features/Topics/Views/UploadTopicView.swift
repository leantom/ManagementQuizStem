import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct UploadFromCSVView: View {
    @StateObject private var viewModel = TopicsViewModel()
    @State private var step: TopicImportStep = .upload
    @State private var analysis: TopicImportAnalysis?
    @State private var previewMode: TopicImportPreviewMode = .all
    @State private var importResult: TopicBatchImportResult?
    @State private var attemptedImportCount = 0
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            stepRail
            activeContent
            footerCards

            if let successMessage = viewModel.successMessage {
                TopicImportInlineBanner(
                    title: "Updated",
                    message: successMessage,
                    tint: TopicImportPalette.success
                )
            }

            if let errorMessage = viewModel.errorMessage {
                TopicImportInlineBanner(
                    title: "Attention",
                    message: errorMessage,
                    tint: TopicImportPalette.warning
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task {
            await viewModel.fetchAllTopicsASync()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Topics")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(TopicImportPalette.subtleInk)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(TopicImportPalette.subtleInk.opacity(0.7))

                    Text("CSV Import")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(TopicImportPalette.primary)
                }

                Text("Topic CSV Import")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(TopicImportPalette.ink)

                Text("Validate headers, review duplicates, and import only the topic rows you actually want to commit.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(TopicImportPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                downloadTemplate()
            } label: {
                Label("Download CSV Template", systemImage: "arrow.down.doc")
            }
            .buttonStyle(TopicImportSecondaryButtonStyle())
        }
    }

    private var stepRail: some View {
        HStack(spacing: 12) {
            ForEach(TopicImportStep.allCases, id: \.self) { item in
                TopicImportStepItem(
                    title: item.title,
                    index: item.rawValue + 1,
                    isActive: step == item,
                    isCompleted: step.rawValue > item.rawValue
                )
            }
        }
    }

    @ViewBuilder
    private var activeContent: some View {
        switch step {
        case .upload:
            uploadStage
        case .validate:
            validationStage
        case .preview:
            previewStage
        case .commit:
            commitStage
        }
    }

    private var uploadStage: some View {
        HStack(alignment: .top, spacing: 18) {
            TopicImportCard(
                title: "Upload File",
                trailingTitle: analysis?.fileURL.lastPathComponent
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Start with a structured topic CSV.")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(TopicImportPalette.ink)

                        Text("The importer understands the current topic schema and will flag duplicates against the live library before anything is written.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(TopicImportPalette.subtleInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        TopicImportMetricCard(
                            title: "Library Topics",
                            value: "\(viewModel.topics.count)",
                            icon: "square.stack.3d.up.fill"
                        )

                        TopicImportMetricCard(
                            title: "Subjects",
                            value: "\(viewModel.parentSubjectOptions.count)",
                            icon: "books.vertical.fill"
                        )

                        TopicImportMetricCard(
                            title: "Levels",
                            value: "\(viewModel.educationLevelOptions.count)",
                            icon: "graduationcap.fill"
                        )
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(TopicImportPalette.primary.opacity(0.12))

                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(TopicImportPalette.primary)
                            }
                            .frame(width: 72, height: 72)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(analysis?.fileURL.lastPathComponent ?? "No CSV selected")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(TopicImportPalette.ink)

                                Text(analysis?.fileSizeLabel ?? "Choose a local CSV file to start the validation pass.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(TopicImportPalette.subtleInk)

                                if let analysis {
                                    Text("Detected headers: \(analysis.headerSummary)")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(TopicImportPalette.primary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 12) {
                            Button {
                                selectCSVFile()
                            } label: {
                                Label("Choose CSV File", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(TopicImportPrimaryButtonStyle())

                            if analysis != nil {
                                Button {
                                    step = .validate
                                } label: {
                                    Label("Review Validation", systemImage: "arrow.right")
                                }
                                .buttonStyle(TopicImportSecondaryButtonStyle())
                            }
                        }
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(TopicImportPalette.surfaceSecondary)
                    )
                }
            }

            VStack(spacing: 18) {
                TopicImportCard(title: "Schema Guide") {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(TopicCSVImportParser.columnGuides.enumerated()), id: \.element.field) { index, guide in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(guide.header)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(TopicImportPalette.ink)

                                    TopicImportTag(
                                        title: guide.isRequired ? "Required" : "Optional",
                                        tint: guide.isRequired ? TopicImportPalette.primary : TopicImportPalette.subtleInk
                                    )
                                }

                                Text(guide.description)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(TopicImportPalette.subtleInk)

                                Text("Accepted aliases: \(guide.aliases.joined(separator: ", "))")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(TopicImportPalette.subtleInk.opacity(0.86))
                            }

                            if index < TopicCSVImportParser.columnGuides.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                TopicImportCard(title: "Quick Topic List") {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.topics.isEmpty {
                            Text("Topics will appear here after the library sync completes.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(TopicImportPalette.subtleInk)
                        } else {
                            ForEach(Array(viewModel.topics.prefix(6))) { topic in
                                HStack(spacing: 12) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(TopicImportPalette.primary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(TopicImportPalette.primary.opacity(0.12))
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(topic.category)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(TopicImportPalette.ink)

                                        Text(topic.name)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(TopicImportPalette.subtleInk)
                                    }

                                    Spacer(minLength: 0)

                                    if let educationLevel = topic.educationLevel, educationLevel.isEmpty == false {
                                        TopicImportTag(title: educationLevel, tint: TopicImportPalette.success)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 360)
        }
    }

    private var validationStage: some View {
        HStack(alignment: .top, spacing: 18) {
            TopicImportCard(title: "Validation Status") {
                VStack(alignment: .leading, spacing: 18) {
                    if let analysis {
                        validationMetric(title: "Total Rows", value: "\(analysis.totalRows)")
                        validationMetric(title: "Valid Rows", value: "\(analysis.validRowsCount)", tint: TopicImportPalette.success)
                        validationMetric(title: "Invalid Rows", value: "\(analysis.invalidRowsCount)", tint: analysis.invalidRowsCount > 0 ? TopicImportPalette.warning : TopicImportPalette.subtleInk)
                        validationMetric(title: "Duplicate Matches", value: "\(analysis.duplicateCount)", tint: analysis.duplicateCount > 0 ? TopicImportPalette.warning : TopicImportPalette.subtleInk)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("File Details")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(TopicImportPalette.subtleInk)

                            Text(analysis.fileURL.lastPathComponent)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(TopicImportPalette.ink)

                            Text("\(analysis.fileSizeLabel) • \(analysis.headers.count) headers detected")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(TopicImportPalette.subtleInk)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(TopicImportPalette.surfaceSecondary)
                        )
                    } else {
                        Text("Choose a CSV file to start validation.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(TopicImportPalette.subtleInk)
                    }
                }
            }
            .frame(width: 280)

            TopicImportCard(
                title: "Error Report & Mapping",
                trailingTitle: analysis != nil ? "RE-SCAN FILE" : nil,
                trailingAction: analysis != nil ? rescanSelectedFile : nil
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 0) {
                        TopicImportTableHeader(title: "Row", width: 80)
                        TopicImportTableHeader(title: "Field", width: 120)
                        TopicImportTableHeader(title: "Detected Value", width: 180)
                        TopicImportTableHeader(title: "Validation Message", width: nil)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(TopicImportPalette.surfaceSecondary)

                    if let analysis, analysis.reportEntries.isEmpty == false {
                        VStack(spacing: 0) {
                            ForEach(Array(analysis.reportEntries.prefix(8))) { entry in
                                TopicImportReportRow(entry: entry)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                        )

                        if analysis.reportEntries.count > 8 {
                            Text("\(analysis.reportEntries.count - 8) additional validation items are hidden from this summary view.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(TopicImportPalette.subtleInk)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No blocking issues detected.")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(TopicImportPalette.success)

                            Text("This file matches the supported topic schema and is ready for preview.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(TopicImportPalette.subtleInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(TopicImportPalette.surfaceSecondary)
                        )
                    }

                    HStack(spacing: 12) {
                        Button {
                            step = .upload
                        } label: {
                            Text("Back To Upload")
                        }
                        .buttonStyle(TopicImportGhostButtonStyle())

                        Button {
                            previewMode = .validOnly
                            step = .preview
                        } label: {
                            Text("Skip Invalid Rows")
                        }
                        .buttonStyle(TopicImportSecondaryButtonStyle())
                        .disabled((analysis?.validRowsCount ?? 0) == 0)

                        Button {
                            previewMode = .all
                            step = .preview
                        } label: {
                            Text("Preview & Continue")
                        }
                        .buttonStyle(TopicImportPrimaryButtonStyle())
                        .disabled(analysis?.hasBlockingIssues ?? true)
                    }
                }
            }
        }
    }

    private var previewStage: some View {
        TopicImportCard(title: "Preview Records", trailingTitle: previewMode.title) {
            VStack(alignment: .leading, spacing: 18) {
                if let analysis {
                    HStack(spacing: 12) {
                        TopicImportMetricCard(
                            title: "Preview Rows",
                            value: "\(analysis.previewRows(scope: previewMode).count)",
                            icon: "eye.fill"
                        )

                        TopicImportMetricCard(
                            title: "Auto Levels",
                            value: "\(analysis.autoAssignedEducationLevelCount(scope: previewMode))",
                            icon: "wand.and.stars"
                        )

                        TopicImportMetricCard(
                            title: "Ready To Import",
                            value: "\(analysis.validRowsCount)",
                            icon: "checkmark.seal.fill"
                        )
                    }

                    previewTable(for: analysis)

                    HStack(spacing: 12) {
                        Button {
                            step = .validate
                        } label: {
                            Text("Back To Validation")
                        }
                        .buttonStyle(TopicImportGhostButtonStyle())

                        Button {
                            importValidRows()
                        } label: {
                            Label(isImporting ? "Importing..." : "Commit Import", systemImage: "square.and.arrow.down.fill")
                        }
                        .buttonStyle(TopicImportPrimaryButtonStyle())
                        .disabled(isImporting || analysis.previewRows(scope: previewMode).isEmpty)
                    }
                }
            }
        }
    }

    private func previewTable(for analysis: TopicImportAnalysis) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TopicImportTableHeader(title: "Row", width: 72)
                TopicImportTableHeader(title: "Topic", width: 220)
                TopicImportTableHeader(title: "Parent Subject", width: 180)
                TopicImportTableHeader(title: "Level", width: 130)
                TopicImportTableHeader(title: "Trend", width: 80)
                TopicImportTableHeader(title: "Status", width: nil)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(TopicImportPalette.surfaceSecondary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(analysis.previewRows(scope: previewMode)) { record in
                        TopicImportPreviewRow(record: record)
                    }
                }
            }
            .frame(minHeight: 360, maxHeight: 420)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TopicImportPalette.border, lineWidth: 1)
        )
    }

    private var commitStage: some View {
        TopicImportCard(title: "Import Summary") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    TopicImportMetricCard(
                        title: "Attempted",
                        value: "\(attemptedImportCount)",
                        icon: "tray.and.arrow.down.fill"
                    )

                    TopicImportMetricCard(
                        title: "Imported",
                        value: "\(importResult?.importedTopics.count ?? 0)",
                        icon: "checkmark.circle.fill"
                    )

                    TopicImportMetricCard(
                        title: "Failed",
                        value: "\(importResult?.failures.count ?? 0)",
                        icon: "exclamationmark.triangle.fill"
                    )
                }

                if let result = importResult {
                    if result.importedTopics.isEmpty == false {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Imported Topics")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(TopicImportPalette.ink)

                            ForEach(Array(result.importedTopics.prefix(8))) { topic in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(TopicImportPalette.success)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(topic.category)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(TopicImportPalette.ink)

                                        Text(topic.name)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(TopicImportPalette.subtleInk)
                                    }
                                }
                            }
                        }
                    }

                    if result.failures.isEmpty == false {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Failed Rows")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(TopicImportPalette.warning)

                            ForEach(Array(result.failures.prefix(6))) { failure in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(failure.topic.category) • \(failure.topic.name)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(TopicImportPalette.ink)

                                    Text(failure.errorMessage)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(TopicImportPalette.subtleInk)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(TopicImportPalette.warning.opacity(0.08))
                                )
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        resetFlow()
                    } label: {
                        Text("Import Another File")
                    }
                    .buttonStyle(TopicImportGhostButtonStyle())

                    Button {
                        step = .upload
                    } label: {
                        Text("Back To Upload")
                    }
                    .buttonStyle(TopicImportSecondaryButtonStyle())
                }
            }
        }
    }

    private var footerCards: some View {
        HStack(spacing: 14) {
            TopicImportFooterCard(
                title: "Performance",
                message: viewModel.isLoading ? "Refreshing topic library before validation." : "Preview computed locally before writes.",
                icon: "speedometer"
            )

            TopicImportFooterCard(
                title: "Data Integrity",
                message: (analysis?.hasBlockingIssues ?? false) ? "Blocking issues found. Import only valid rows." : "Schema pass complete for the current preview.",
                icon: "shield.lefthalf.filled"
            )

            TopicImportFooterCard(
                title: "Destination",
                message: "ManagementQuizStem.Topics collection",
                icon: "tray.full.fill"
            )
        }
    }

    private func validationMetric(title: String, value: String, tint: Color = TopicImportPalette.ink) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(TopicImportPalette.subtleInk)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    private func selectCSVFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a topic CSV file"
        openPanel.allowedContentTypes = [.commaSeparatedText]
        openPanel.allowsMultipleSelection = false

        guard openPanel.runModal() == .OK, let url = openPanel.url else {
            return
        }

        Task {
            await viewModel.fetchAllTopicsASync()
            await MainActor.run {
                analyzeFile(url)
            }
        }
    }

    private func rescanSelectedFile() {
        guard let url = analysis?.fileURL else { return }

        Task {
            await viewModel.fetchAllTopicsASync()
            await MainActor.run {
                analyzeFile(url)
            }
        }
    }

    private func analyzeFile(_ url: URL) {
        do {
            let parsedAnalysis = try TopicCSVImportParser.analyze(
                fileURL: url,
                existingTopics: viewModel.topics,
                classifyEducationLevel: viewModel.classifyEducationLevel(for:)
            )

            analysis = parsedAnalysis
            importResult = nil
            attemptedImportCount = 0
            previewMode = parsedAnalysis.hasBlockingIssues ? .validOnly : .all
            step = .validate
            viewModel.successMessage = nil
            viewModel.errorMessage = nil
        } catch {
            viewModel.errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
        }
    }

    private func importValidRows() {
        guard let analysis else { return }

        let records = analysis.previewRows(scope: previewMode)
        guard records.isEmpty == false else {
            viewModel.errorMessage = "There are no valid rows available to import."
            return
        }

        isImporting = true
        attemptedImportCount = records.count

        Task {
            let result = await viewModel.importPreparedTopics(records.map(\.draft))
            await MainActor.run {
                importResult = result
                isImporting = false
                step = .commit
            }
        }
    }

    private func resetFlow() {
        step = .upload
        analysis = nil
        importResult = nil
        previewMode = .all
        attemptedImportCount = 0
        isImporting = false
        viewModel.successMessage = nil
        viewModel.errorMessage = nil
    }

    private func downloadTemplate() {
        let panel = NSSavePanel()
        panel.title = "Save topic CSV template"
        panel.nameFieldStringValue = "topic-import-template.csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try TopicCSVImportParser.templateCSV.write(to: url, atomically: true, encoding: .utf8)
            viewModel.successMessage = "Template saved to \(url.lastPathComponent)."
            viewModel.errorMessage = nil
        } catch {
            viewModel.errorMessage = "Failed to save template: \(error.localizedDescription)"
        }
    }
}

private enum TopicImportStep: Int, CaseIterable {
    case upload
    case validate
    case preview
    case commit

    var title: String {
        switch self {
        case .upload:
            return "Upload File"
        case .validate:
            return "Validate Schema"
        case .preview:
            return "Preview Records"
        case .commit:
            return "Commit Import"
        }
    }
}

private enum TopicImportPreviewMode {
    case all
    case validOnly

    var title: String {
        switch self {
        case .all:
            return "ALL ROWS"
        case .validOnly:
            return "VALID ROWS ONLY"
        }
    }
}

private enum TopicImportIssueSeverity {
    case blocking
    case warning

    var tint: Color {
        switch self {
        case .blocking:
            return TopicImportPalette.warning
        case .warning:
            return TopicImportPalette.primary
        }
    }

    var statusTitle: String {
        switch self {
        case .blocking:
            return "Blocked"
        case .warning:
            return "Review"
        }
    }
}

private enum TopicImportField: CaseIterable, Hashable {
    case parentSubject
    case topicName
    case description
    case trending
    case educationLevel

    var header: String {
        switch self {
        case .parentSubject:
            return "parent_subject"
        case .topicName:
            return "topic_name"
        case .description:
            return "description"
        case .trending:
            return "trending"
        case .educationLevel:
            return "education_level"
        }
    }

    var label: String {
        switch self {
        case .parentSubject:
            return "parent_subject"
        case .topicName:
            return "topic_name"
        case .description:
            return "description"
        case .trending:
            return "trending"
        case .educationLevel:
            return "education_level"
        }
    }
}

private struct TopicImportColumnGuide {
    let field: TopicImportField
    let header: String
    let description: String
    let aliases: [String]
    let isRequired: Bool
}

private struct TopicImportReportEntry: Identifiable {
    let id = UUID()
    let rowLabel: String
    let field: String
    let detectedValue: String
    let message: String
    let severity: TopicImportIssueSeverity
}

private struct TopicImportRecord: Identifiable {
    let id: String
    let rowNumber: Int
    let parentSubject: String
    let topicName: String
    let description: String
    let trending: Int
    let educationLevel: String
    let educationLevelWasAutoAssigned: Bool
    let issues: [TopicImportReportEntry]
    let draft: Topic

    var isImportable: Bool {
        issues.contains(where: { $0.severity == .blocking }) == false
    }

    var statusTitle: String {
        if isImportable {
            return educationLevelWasAutoAssigned ? "Ready • Auto level" : "Ready"
        }

        return "Blocked"
    }

    var statusTint: Color {
        isImportable ? TopicImportPalette.success : TopicImportPalette.warning
    }
}

private struct TopicImportAnalysis {
    let fileURL: URL
    let fileSizeLabel: String
    let headers: [String]
    let records: [TopicImportRecord]
    let reportEntries: [TopicImportReportEntry]

    var totalRows: Int {
        records.count
    }

    var validRowsCount: Int {
        records.filter(\.isImportable).count
    }

    var invalidRowsCount: Int {
        totalRows - validRowsCount
    }

    var duplicateCount: Int {
        reportEntries.filter {
            $0.message.localizedCaseInsensitiveContains("duplicate") ||
            $0.message.localizedCaseInsensitiveContains("already exists")
        }.count
    }

    var hasBlockingIssues: Bool {
        reportEntries.contains { $0.severity == .blocking }
    }

    var headerSummary: String {
        headers.joined(separator: ", ")
    }

    func previewRows(scope: TopicImportPreviewMode) -> [TopicImportRecord] {
        switch scope {
        case .all:
            return records
        case .validOnly:
            return records.filter(\.isImportable)
        }
    }

    func autoAssignedEducationLevelCount(scope: TopicImportPreviewMode) -> Int {
        previewRows(scope: scope).filter(\.educationLevelWasAutoAssigned).count
    }
}

private enum TopicCSVImportParser {
    static let columnGuides: [TopicImportColumnGuide] = [
        TopicImportColumnGuide(
            field: .parentSubject,
            header: "parent_subject",
            description: "Subject or library parent that groups the topic in the admin UI.",
            aliases: ["parent_subject", "subject", "subject_name", "name"],
            isRequired: true
        ),
        TopicImportColumnGuide(
            field: .topicName,
            header: "topic_name",
            description: "Human-readable topic title stored in the current Topics library.",
            aliases: ["topic_name", "topic", "category"],
            isRequired: true
        ),
        TopicImportColumnGuide(
            field: .description,
            header: "description",
            description: "Optional supporting description for editors.",
            aliases: ["description", "topic_description"],
            isRequired: false
        ),
        TopicImportColumnGuide(
            field: .trending,
            header: "trending",
            description: "Optional integer ranking. Blank values default to 0.",
            aliases: ["trending", "trend", "score"],
            isRequired: false
        ),
        TopicImportColumnGuide(
            field: .educationLevel,
            header: "education_level",
            description: "Optional curriculum label. When blank, the importer infers one from topic_name.",
            aliases: ["education_level", "educationlevel", "level"],
            isRequired: false
        )
    ]

    static let templateCSV = """
    parent_subject,topic_name,description,trending,education_level
    Mathematics,Algebra,Core algebra foundations,1,Secondary
    Computer Science,Machine Learning,Introductory model training concepts,0,University
    """

    private static let headerAliases: [String: TopicImportField] = [
        "parentsubject": .parentSubject,
        "subject": .parentSubject,
        "subjectname": .parentSubject,
        "name": .parentSubject,
        "topicname": .topicName,
        "topic": .topicName,
        "category": .topicName,
        "description": .description,
        "topicdescription": .description,
        "trending": .trending,
        "trend": .trending,
        "score": .trending,
        "educationlevel": .educationLevel,
        "level": .educationLevel
    ]

    static func analyze(
        fileURL: URL,
        existingTopics: [Topic],
        classifyEducationLevel: (String) -> String
    ) throws -> TopicImportAnalysis {
        let data = try Data(contentsOf: fileURL)
        let rawContents =
            String(data: data, encoding: .utf8) ??
            String(data: data, encoding: .utf16) ??
            String(decoding: data, as: UTF8.self)

        var rows = parseCSVRows(from: rawContents)
        let fileSizeLabel = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)

        guard rows.isEmpty == false else {
            return TopicImportAnalysis(
                fileURL: fileURL,
                fileSizeLabel: fileSizeLabel,
                headers: [],
                records: [],
                reportEntries: [
                    TopicImportReportEntry(
                        rowLabel: "Header",
                        field: "file",
                        detectedValue: "EMPTY",
                        message: "The selected CSV file is empty.",
                        severity: .blocking
                    )
                ]
            )
        }

        let headerRow = rows.removeFirst().map(cleanValue)
        var resolvedIndexes: [TopicImportField: Int] = [:]
        var reportEntries: [TopicImportReportEntry] = []

        for (index, header) in headerRow.enumerated() {
            let normalized = normalizedHeader(header)
            guard let field = headerAliases[normalized] else { continue }

            if resolvedIndexes[field] != nil {
                reportEntries.append(
                    TopicImportReportEntry(
                        rowLabel: "Header",
                        field: field.label,
                        detectedValue: header,
                        message: "This column is mapped more than once. Keep only one header for this field.",
                        severity: .blocking
                    )
                )
            } else {
                resolvedIndexes[field] = index
            }
        }

        for field in [TopicImportField.parentSubject, .topicName] where resolvedIndexes[field] == nil {
            reportEntries.append(
                TopicImportReportEntry(
                    rowLabel: "Header",
                    field: field.label,
                    detectedValue: "MISSING",
                    message: "Required column is missing from the CSV header.",
                    severity: .blocking
                )
            )
        }

        let existingSignatures = Set(existingTopics.map {
            signature(parentSubject: $0.name, topicName: $0.category)
        })

        var seenImportSignatures: [String: Int] = [:]
        var records: [TopicImportRecord] = []

        for (index, row) in rows.enumerated() {
            let rowNumber = index + 2
            let normalizedRow = row.map(cleanValue)

            if normalizedRow.allSatisfy({ $0.isEmpty }) {
                continue
            }

            func value(for field: TopicImportField) -> String {
                guard let columnIndex = resolvedIndexes[field], columnIndex < normalizedRow.count else {
                    return ""
                }

                return normalizedRow[columnIndex]
            }

            let parentSubject = value(for: .parentSubject)
            let topicName = value(for: .topicName)
            let description = value(for: .description)
            let rawTrending = value(for: .trending)
            let rawEducationLevel = value(for: .educationLevel)

            var rowEntries: [TopicImportReportEntry] = []
            var trendingValue = 0

            if parentSubject.isEmpty {
                rowEntries.append(
                    TopicImportReportEntry(
                        rowLabel: "#\(rowNumber)",
                        field: TopicImportField.parentSubject.label,
                        detectedValue: "EMPTY",
                        message: "Parent subject is required.",
                        severity: .blocking
                    )
                )
            }

            if topicName.isEmpty {
                rowEntries.append(
                    TopicImportReportEntry(
                        rowLabel: "#\(rowNumber)",
                        field: TopicImportField.topicName.label,
                        detectedValue: "EMPTY",
                        message: "Topic name is required.",
                        severity: .blocking
                    )
                )
            }

            if rawTrending.isEmpty == false {
                if let parsedTrending = Int(rawTrending) {
                    trendingValue = parsedTrending
                } else {
                    rowEntries.append(
                        TopicImportReportEntry(
                            rowLabel: "#\(rowNumber)",
                            field: TopicImportField.trending.label,
                            detectedValue: rawTrending,
                            message: "Trending must be an integer value.",
                            severity: .blocking
                        )
                    )
                }
            }

            if parentSubject.isEmpty == false && topicName.isEmpty == false {
                let rowSignature = signature(parentSubject: parentSubject, topicName: topicName)

                if existingSignatures.contains(rowSignature) {
                    rowEntries.append(
                        TopicImportReportEntry(
                            rowLabel: "#\(rowNumber)",
                            field: "topic",
                            detectedValue: topicName,
                            message: "This topic already exists in the live library for the same parent subject.",
                            severity: .blocking
                        )
                    )
                }

                if let firstSeenRow = seenImportSignatures[rowSignature] {
                    rowEntries.append(
                        TopicImportReportEntry(
                            rowLabel: "#\(rowNumber)",
                            field: "topic",
                            detectedValue: topicName,
                            message: "Duplicate row in this import file. First detected on row \(firstSeenRow).",
                            severity: .blocking
                        )
                    )
                } else {
                    seenImportSignatures[rowSignature] = rowNumber
                }
            }

            let resolvedEducationLevel = rawEducationLevel.isEmpty ? classifyEducationLevel(topicName) : rawEducationLevel

            let record = TopicImportRecord(
                id: "row-\(rowNumber)",
                rowNumber: rowNumber,
                parentSubject: parentSubject,
                topicName: topicName,
                description: description,
                trending: trendingValue,
                educationLevel: resolvedEducationLevel,
                educationLevelWasAutoAssigned: rawEducationLevel.isEmpty && topicName.isEmpty == false,
                issues: rowEntries,
                draft: Topic(
                    id: UUID().uuidString,
                    name: parentSubject,
                    category: topicName,
                    description: description.isEmpty ? nil : description,
                    iconURL: nil,
                    educationLevel: resolvedEducationLevel.isEmpty ? nil : resolvedEducationLevel,
                    trending: trendingValue
                )
            )

            records.append(record)
            reportEntries.append(contentsOf: rowEntries)
        }

        if records.isEmpty {
            reportEntries.append(
                TopicImportReportEntry(
                    rowLabel: "Rows",
                    field: "data",
                    detectedValue: "NONE",
                    message: "No importable rows were found after reading the CSV file.",
                    severity: .blocking
                )
            )
        }

        return TopicImportAnalysis(
            fileURL: fileURL,
            fileSizeLabel: fileSizeLabel,
            headers: headerRow,
            records: records,
            reportEntries: reportEntries
        )
    }

    private static func cleanValue(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\u{FEFF}") {
            value.removeFirst()
        }
        return value
    }

    private static func normalizedHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private static func signature(parentSubject: String, topicName: String) -> String {
        "\(parentSubject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\(topicName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private static func parseCSVRows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]

            if insideQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
            } else {
                switch character {
                case "\"":
                    insideQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                case "\r":
                    break
                default:
                    currentField.append(character)
                }
            }

            index = text.index(after: index)
        }

        if currentField.isEmpty == false || currentRow.isEmpty == false {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}

private struct TopicImportCard<Content: View>: View {
    let title: String
    var trailingTitle: String?
    var trailingAction: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(TopicImportPalette.ink)

                Spacer(minLength: 0)

                if let trailingTitle {
                    if let trailingAction {
                        Button(trailingTitle, action: trailingAction)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(TopicImportPalette.primary)
                    } else {
                        Text(trailingTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(TopicImportPalette.subtleInk)
                    }
                }
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TopicImportPalette.border, lineWidth: 1)
        )
    }
}

private struct TopicImportMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TopicImportPalette.primary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TopicImportPalette.ink)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(TopicImportPalette.subtleInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(TopicImportPalette.surfaceSecondary)
        )
    }
}

private struct TopicImportTag: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct TopicImportStepItem: View {
    let title: String
    let index: Int
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isActive || isCompleted ? TopicImportPalette.primary : TopicImportPalette.surfaceSecondary)

                Text(isCompleted ? "✓" : "\(index)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive || isCompleted ? .white : TopicImportPalette.subtleInk)
            }
            .frame(width: 28, height: 28)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(isActive ? TopicImportPalette.primary : TopicImportPalette.subtleInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? TopicImportPalette.primary.opacity(0.08) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isActive ? TopicImportPalette.primary.opacity(0.22) : TopicImportPalette.border, lineWidth: 1)
        )
    }
}

private struct TopicImportTableHeader: View {
    let title: String
    let width: CGFloat?

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(TopicImportPalette.subtleInk)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
    }
}

private struct TopicImportReportRow: View {
    let entry: TopicImportReportEntry

    var body: some View {
        HStack(spacing: 0) {
            reportValue(entry.rowLabel, width: 80, tint: TopicImportPalette.ink)
            reportValue(entry.field, width: 120, tint: TopicImportPalette.primary)
            reportValue(entry.detectedValue, width: 180, tint: entry.severity.tint)
            reportValue(entry.message, width: nil, tint: TopicImportPalette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(entry.severity.tint.opacity(0.04))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func reportValue(_ text: String, width: CGFloat?, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
    }
}

private struct TopicImportPreviewRow: View {
    let record: TopicImportRecord

    var body: some View {
        HStack(spacing: 0) {
            previewValue("#\(record.rowNumber)", width: 72, tint: TopicImportPalette.subtleInk)
            previewValue(record.topicName, width: 220, tint: TopicImportPalette.ink)
            previewValue(record.parentSubject, width: 180, tint: TopicImportPalette.subtleInk)
            previewValue(record.educationLevel, width: 130, tint: record.educationLevelWasAutoAssigned ? TopicImportPalette.primary : TopicImportPalette.ink)
            previewValue("\(record.trending)", width: 80, tint: TopicImportPalette.ink)

            HStack(spacing: 8) {
                TopicImportTag(title: record.statusTitle, tint: record.statusTint)

                if record.description.isEmpty == false {
                    Text(record.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(TopicImportPalette.subtleInk)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func previewValue(_ text: String, width: CGFloat?, tint: Color) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
    }
}

private struct TopicImportFooterCard: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TopicImportPalette.subtleInk)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(TopicImportPalette.subtleInk)

            Text(message)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(TopicImportPalette.subtleInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TopicImportPalette.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

private struct TopicImportInlineBanner: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TopicImportPalette.ink)

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(TopicImportPalette.subtleInk)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct TopicImportPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TopicImportPalette.primary.opacity(configuration.isPressed ? 0.84 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct TopicImportSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(TopicImportPalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TopicImportPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct TopicImportGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(TopicImportPalette.subtleInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TopicImportPalette.surfaceSecondary.opacity(configuration.isPressed ? 0.8 : 1))
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

private enum TopicImportPalette {
    static let primary = Color(red: 0.18, green: 0.40, blue: 0.93)
    static let ink = Color(red: 0.11, green: 0.14, blue: 0.22)
    static let subtleInk = Color(red: 0.43, green: 0.47, blue: 0.57)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
    static let surfaceSecondary = Color(red: 0.96, green: 0.97, blue: 0.995)
    static let success = Color(red: 0.17, green: 0.64, blue: 0.45)
    static let warning = Color(red: 0.89, green: 0.20, blue: 0.28)
}

#Preview {
    UploadFromCSVView()
}

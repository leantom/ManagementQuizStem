import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImportQuestionsFromJSONView: View {
    private static let allSubjects = "All Subjects"
    private static let anyDifficulty = "Any Difficulty"
    private static let pageSize = 25

    @StateObject private var viewModel = QuestionsViewModel()
    @State private var searchText = ""
    @State private var selectedSubject = allSubjects
    @State private var selectedDifficulty = anyDifficulty
    @State private var currentPage = 0
    @State private var showingImportSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            libraryPanel
            detailPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.loadLibrary()
        }
        .onChange(of: searchText) { _, _ in
            currentPage = 0
        }
        .onChange(of: selectedSubject) { _, _ in
            currentPage = 0
        }
        .onChange(of: selectedDifficulty) { _, _ in
            currentPage = 0
        }
        .sheet(isPresented: $showingImportSheet) {
            QuestionsImportPreviewSheet(viewModel: viewModel) {
                showingImportSheet = false
                viewModel.uploadQuestions()
            }
        }
        .confirmationDialog(
            "Delete question?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Question", role: .destructive) {
                viewModel.deleteSelectedQuestion()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the selected question from the root questions collection.")
        }
    }

    private var filteredQuestions: [Question] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return viewModel.libraryQuestions.filter { question in
            let matchesSubject: Bool
            if selectedSubject == Self.allSubjects {
                matchesSubject = true
            } else {
                matchesSubject = viewModel.subjectName(for: question.topicID)
                    .caseInsensitiveCompare(selectedSubject) == .orderedSame
            }

            let matchesDifficulty: Bool
            if selectedDifficulty == Self.anyDifficulty {
                matchesDifficulty = true
            } else {
                matchesDifficulty = question.difficulty.caseInsensitiveCompare(selectedDifficulty) == .orderedSame
            }

            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    question.questionText.localizedCaseInsensitiveContains(query) ||
                    viewModel.subjectName(for: question.topicID).localizedCaseInsensitiveContains(query) ||
                    viewModel.topicName(for: question.topicID).localizedCaseInsensitiveContains(query) ||
                    (question.id?.localizedCaseInsensitiveContains(query) ?? false)
            }

            return matchesSubject && matchesDifficulty && matchesSearch
        }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(max(filteredQuestions.count, 1)) / Double(Self.pageSize))))
    }

    private var visiblePage: Int {
        min(currentPage, max(totalPages - 1, 0))
    }

    private var pagedQuestions: [Question] {
        guard filteredQuestions.isEmpty == false else { return [] }

        let startIndex = visiblePage * Self.pageSize
        let endIndex = min(startIndex + Self.pageSize, filteredQuestions.count)
        return Array(filteredQuestions[startIndex..<endIndex])
    }

    private var showingRangeLabel: String {
        guard filteredQuestions.isEmpty == false else {
            return "Showing 0 of 0"
        }

        let start = visiblePage * Self.pageSize + 1
        let end = min((visiblePage + 1) * Self.pageSize, filteredQuestions.count)
        return "Showing \(start)-\(end) of \(filteredQuestions.count)"
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            metricStrip
            filterRow
            questionsTable

            if let successMessage = viewModel.successMessage {
                QuestionsInlineBanner(
                    title: "Updated",
                    message: successMessage,
                    tint: QuestionsPalette.success
                )
            }

            if let errorMessage = viewModel.errorMessage {
                QuestionsInlineBanner(
                    title: "Attention",
                    message: errorMessage,
                    tint: QuestionsPalette.warning
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LIBRARY  >  QUESTIONS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(QuestionsPalette.subtleInk)

                    Text("Questions Library")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.ink)

                    Text("Manage adaptive STEM brain-training items with import, ELO, and skill metadata controls.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.subtleInk)
                }

                Spacer(minLength: 18)

                HStack(spacing: 12) {
                    Button {
                        chooseImportFile()
                    } label: {
                        Label("Import JSON", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(QuestionsSecondaryButtonStyle())

                    Button {
                        exportQuestions()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(QuestionsSecondaryButtonStyle())

                    Button {
                        viewModel.startCreatingNewQuestion()
                    } label: {
                        Label("New Question", systemImage: "plus")
                    }
                    .buttonStyle(QuestionsPrimaryButtonStyle())
                }
            }
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 12) {
            QuestionsMetricChip(
                title: "Validated",
                value: "\(viewModel.libraryQuestions.count)",
                caption: "items loaded"
            )

            QuestionsMetricChip(
                title: "Subjects",
                value: "\(viewModel.subjectOptions.count)",
                caption: "coverage areas"
            )

            QuestionsMetricChip(
                title: "Filtered",
                value: "\(filteredQuestions.count)",
                caption: "current results"
            )
        }
    }

    private var filterRow: some View {
        HStack(spacing: 12) {
            QuestionsFilterMenu(
                title: "Filter By",
                selection: $selectedSubject,
                options: [Self.allSubjects] + viewModel.subjectOptions
            )

            QuestionsFilterMenu(
                title: "Difficulty",
                selection: $selectedDifficulty,
                options: [Self.anyDifficulty] + viewModel.difficultyOptions
            )

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(QuestionsPalette.subtleInk)

                TextField("Search question text, subject, topic, or ID...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(QuestionsPalette.border, lineWidth: 1)
            )
        }
    }

    private var questionsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                QuestionsTableHeader(title: "Question Text", width: 280, alignment: .leading)
                QuestionsTableHeader(title: "Subject", width: 132, alignment: .leading)
                QuestionsTableHeader(title: "Topic", width: 148, alignment: .leading)
                QuestionsTableHeader(title: "Difficulty", width: 112, alignment: .center)
                QuestionsTableHeader(title: "Answers", width: 82, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(QuestionsPalette.surfaceSecondary)

            if viewModel.isLoadingLibrary {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Loading question library...")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.subtleInk)
                    Spacer()
                }
                .frame(minHeight: 540)
            } else if filteredQuestions.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(QuestionsPalette.primary)

                    Text("No questions match the current filters.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.ink)

                    Text("Adjust the subject or difficulty menus, or import a fresh question bank.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.subtleInk)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 540)
                .padding(.horizontal, 24)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(pagedQuestions.enumerated()), id: \.offset) { _, question in
                            QuestionsLibraryRow(
                                questionText: question.questionText,
                                subject: viewModel.subjectName(for: question.topicID),
                                topic: viewModel.topicName(for: question.topicID),
                                difficulty: question.difficulty,
                                answerCount: question.options.count,
                                isSelected: viewModel.selectedQuestionID == question.id
                            ) {
                                viewModel.selectQuestion(question)
                            }
                        }
                    }
                }
                .frame(minHeight: 540)
            }

            HStack {
                Text(showingRangeLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuestionsPalette.subtleInk)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button {
                        currentPage = max(visiblePage - 1, 0)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(QuestionsPagerButtonStyle())
                    .disabled(visiblePage == 0)

                    Text("Page \(visiblePage + 1) / \(totalPages)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.ink)
                        .frame(minWidth: 74)

                    Button {
                        currentPage = min(visiblePage + 1, totalPages - 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(QuestionsPagerButtonStyle())
                    .disabled(visiblePage >= totalPages - 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(QuestionsPalette.border, lineWidth: 1)
        )
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("QUESTION PREVIEW")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(QuestionsPalette.subtleInk)

                Spacer(minLength: 0)

                Button {
                    viewModel.discardDraftChanges()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(QuestionsIconButtonStyle())
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    previewSummaryCard
                    detailFieldsCard
                    brainTrainingCard
                    apiMetadataCard
                    optionsCard
                    validationCard
                    actionCard
                }
                .padding(.bottom, 2)
            }
        }
        .frame(width: 380, alignment: .topLeading)
    }

    private var previewSummaryCard: some View {
        QuestionsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    QuestionsPreviewChip(
                        title: viewModel.isCreatingNewQuestion ? "DRAFT" : "LIVE",
                        tint: viewModel.isCreatingNewQuestion ? QuestionsPalette.warning : QuestionsPalette.primary
                    )

                    Spacer(minLength: 0)

                    Text(viewModel.draftReference)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.primary)
                        .lineLimit(1)
                }

                Text(viewModel.draftQuestionText.isEmpty ? "Question prompt will appear here." : viewModel.draftQuestionText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(QuestionsPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    QuestionsDetailStat(
                        title: "Subject",
                        value: viewModel.draftTopic?.name ?? "Pending"
                    )

                    QuestionsDetailStat(
                        title: "Topic",
                        value: viewModel.draftTopic?.category ?? "Pending"
                    )
                }

                HStack(spacing: 10) {
                    QuestionsDetailStat(
                        title: "Difficulty",
                        value: viewModel.draftDifficulty.isEmpty ? "Medium" : viewModel.draftDifficulty
                    )

                    QuestionsDetailStat(
                        title: "ELO",
                        value: viewModel.draftEloRating.isEmpty ? "1200" : viewModel.draftEloRating
                    )
                }

                HStack(spacing: 10) {
                    QuestionsDetailStat(
                        title: "Skills",
                        value: viewModel.draftCognitiveSkillsText.isEmpty ? "logic" : viewModel.draftCognitiveSkillsText
                    )

                    QuestionsDetailStat(
                        title: "Domain",
                        value: viewModel.draftScientificDomain.isEmpty ? "Logic" : viewModel.draftScientificDomain
                    )
                }

                HStack(spacing: 10) {
                    QuestionsDetailStat(
                        title: "Source",
                        value: viewModel.draftSource.isEmpty ? "Manual" : viewModel.draftSource
                    )

                    QuestionsDetailStat(
                        title: "Answers",
                        value: "\(viewModel.draftOptions.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count)"
                    )
                }
            }
        }
    }

    private var detailFieldsCard: some View {
        QuestionsCard {
            VStack(alignment: .leading, spacing: 14) {
                QuestionsEditorSection(title: "Question Text") {
                    TextEditor(text: $viewModel.draftQuestionText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.success)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestionsPalette.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(QuestionsPalette.border, lineWidth: 1)
                        )
                }

                QuestionsEditorSection(title: "Topic") {
                    Picker("", selection: $viewModel.draftTopicID) {
                        ForEach(viewModel.topics) { topic in
                            Text("\(topic.name)  /  \(topic.category)")
                                .foregroundStyle(QuestionsPalette.success)
                                .tag(topic.id)
                        }
                    }
                    .foregroundStyle(QuestionsPalette.success)
                    .pickerStyle(.menu)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(QuestionsPalette.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(QuestionsPalette.border, lineWidth: 1)
                    )
                }

                HStack(spacing: 12) {
                    QuestionsEditorSection(title: "Difficulty") {
                        Picker("", selection: $viewModel.draftDifficulty) {
                            ForEach(viewModel.difficultyOptions, id: \.self) { level in
                                Text(level)
                                    .foregroundStyle(QuestionsPalette.success)
                                    .tag(level)
                                    
                            }
                        }
                        .foregroundStyle(QuestionsPalette.success)
                        .pickerStyle(.menu)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestionsPalette.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(QuestionsPalette.border, lineWidth: 1)
                        )
                    }

                    QuestionsEditorSection(title: "Correct Answer") {
                        TextField("Type the exact option text", text: $viewModel.draftCorrectAnswer)
                            .textFieldStyle(.plain)
                            .foregroundStyle(QuestionsPalette.success)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(QuestionsPalette.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(QuestionsPalette.border, lineWidth: 1)
                            )
                    }
                }

                QuestionsEditorSection(title: "Explanation") {
                    TextEditor(text: $viewModel.draftExplanation)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.success)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 110)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestionsPalette.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(QuestionsPalette.border, lineWidth: 1)
                        )
                }

                QuestionsEditorSection(title: "Real World Context") {
                    TextEditor(text: $viewModel.draftRealWorldContext)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.success)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestionsPalette.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(QuestionsPalette.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var brainTrainingCard: some View {
        QuestionsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("BRAIN TRAINING METADATA")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(QuestionsPalette.subtleInk)

                HStack(spacing: 12) {
                    QuestionsEditorSection(title: "Cognitive Skills") {
                        TextField("logic, estimation, data_literacy", text: $viewModel.draftCognitiveSkillsText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(QuestionsPalette.success)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(QuestionsPalette.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(QuestionsPalette.border, lineWidth: 1)
                            )
                    }

                    QuestionsEditorSection(title: "ELO") {
                        TextField("1200", text: $viewModel.draftEloRating)
                            .textFieldStyle(.plain)
                            .foregroundStyle(QuestionsPalette.success)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(width: 86)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(QuestionsPalette.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(QuestionsPalette.border, lineWidth: 1)
                            )
                    }
                }

                QuestionsEditorSection(title: "Socratic Hints") {
                    TextEditor(text: $viewModel.draftHintsText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.success)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestionsPalette.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(QuestionsPalette.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var apiMetadataCard: some View {
        QuestionsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("API AND ADULT LEARNING")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(QuestionsPalette.subtleInk)

                    Spacer(minLength: 0)

                    Toggle("Verified", isOn: $viewModel.draftIsVerified)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.ink)
                }

                HStack(spacing: 12) {
                    QuestionsEditorSection(title: "Source") {
                        TextField("opentdb", text: $viewModel.draftSource)
                            .textFieldStyle(.plain)
                            .foregroundStyle(QuestionsPalette.success)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(QuestionsPalette.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(QuestionsPalette.border, lineWidth: 1)
                            )
                    }

                    QuestionsEditorSection(title: "External ID") {
                        TextField("api-question-id", text: $viewModel.draftExternalID)
                            .textFieldStyle(.plain)
                            .foregroundStyle(QuestionsPalette.success)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(QuestionsPalette.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(QuestionsPalette.border, lineWidth: 1)
                            )
                    }
                }

                QuestionsEditorSection(title: "Scientific Domain") {
                    Picker("", selection: $viewModel.draftScientificDomain) {
                        ForEach(viewModel.scientificDomainOptions, id: \.self) { domain in
                            Text(domain)
                                .foregroundStyle(QuestionsPalette.success)
                                .tag(domain)
                        }
                    }
                    .foregroundStyle(QuestionsPalette.success)
                    .pickerStyle(.menu)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(QuestionsPalette.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(QuestionsPalette.border, lineWidth: 1)
                    )
                }

                QuestionsEditorSection(title: "Did You Know") {
                    TextEditor(text: $viewModel.draftDidYouKnow)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.success)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestionsPalette.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(QuestionsPalette.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var optionsCard: some View {
        QuestionsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ANSWER SET")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(QuestionsPalette.subtleInk)

                    Spacer(minLength: 0)

                    Button {
                        viewModel.draftOptions.append("")
                    } label: {
                        Label("Add Option", systemImage: "plus")
                    }
                    .buttonStyle(QuestionsGhostButtonStyle())
                }

                ForEach(viewModel.draftOptions.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(QuestionsPalette.primary)
                            .frame(width: 20, alignment: .center)

                        TextField(
                            "Option \(index + 1)",
                            text: Binding(
                                get: { viewModel.draftOptions[index] },
                                set: { viewModel.draftOptions[index] = $0 }
                            )
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.success)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestionsPalette.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(QuestionsPalette.border, lineWidth: 1)
                        )

                        if viewModel.draftOptions.count > 2 {
                            Button {
                                viewModel.draftOptions.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(QuestionsPalette.warning)
                        }
                    }
                }
            }
        }
    }

    private var validationCard: some View {
        QuestionsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("VALIDATION STATUS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(QuestionsPalette.subtleInk)

                if viewModel.draftWarnings.isEmpty {
                    Label("Question is ready to save.", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.success)
                } else {
                    ForEach(viewModel.draftWarnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(QuestionsPalette.warning)
                                .padding(.top, 2)

                            Text(warning)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(QuestionsPalette.ink)
                        }
                    }
                }
            }
        }
    }

    private var actionCard: some View {
        QuestionsCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    viewModel.saveDraftQuestion()
                } label: {
                    Label(
                        viewModel.isCreatingNewQuestion ? "Create Question" : "Save Changes",
                        systemImage: "square.and.arrow.down.fill"
                    )
                }
                .buttonStyle(QuestionsPrimaryButtonStyle())
                .disabled(viewModel.isSavingDraft || viewModel.topics.isEmpty)

                Button {
                    viewModel.discardDraftChanges()
                } label: {
                    Label("Discard Changes", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(QuestionsSecondaryButtonStyle())

                if viewModel.selectedQuestion != nil {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Question", systemImage: "trash")
                    }
                    .buttonStyle(QuestionsDestructiveButtonStyle())
                    .disabled(viewModel.isDeletingQuestion)
                }
            }
        }
    }

    private func chooseImportFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a question JSON file"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            viewModel.importQuestionsFromJSON(url: url)

            if viewModel.listQuestions.isEmpty == false {
                showingImportSheet = true
            }
        }
    }

    private func exportQuestions() {
        guard filteredQuestions.isEmpty == false else {
            viewModel.errorMessage = "There are no questions to export for the current filters."
            return
        }

        do {
            let data = try viewModel.exportData(for: filteredQuestions)
            let savePanel = NSSavePanel()
            savePanel.title = "Export Questions"
            savePanel.nameFieldStringValue = "questions-export.json"
            savePanel.allowedContentTypes = [.json]

            if savePanel.runModal() == .OK, let url = savePanel.url {
                try data.write(to: url)
                viewModel.successMessage = "Exported \(filteredQuestions.count) questions."
            }
        } catch {
            viewModel.errorMessage = "Failed to export questions: \(error.localizedDescription)"
        }
    }
}

private struct QuestionsImportPreviewSheet: View {
    @ObservedObject var viewModel: QuestionsViewModel

    let onUpload: () -> Void

    private var resolvedRowCount: Int {
        viewModel.listQuestions.filter { question in
            guard let topic = question.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
                  topic.isEmpty == false else {
                return false
            }

            return viewModel.filterTopicsByCategory(by: topic) != nil
        }
        .count
    }

    private var unresolvedTopics: [String] {
        let importedTopics = viewModel.listQuestions.compactMap { $0.topic?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(
            Set(importedTopics.filter { topic in
                viewModel.filterTopicsByCategory(by: topic) == nil
            })
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Import Preview")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.ink)

                    Text("Review the incoming question file before it is written to Firestore.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestionsPalette.subtleInk)
                }

                Spacer(minLength: 16)
                HStack(spacing:10) {
                    Button {
                        
                    } label: {
                        Label("Cancel", systemImage: "x.circle")
                    }
                    .buttonStyle(QuestionsPrimaryButtonStyle())
                    .disabled(viewModel.listQuestions.isEmpty || unresolvedTopics.isEmpty == false)
                    Button {
                        onUpload()
                    } label: {
                        Label("Upload Questions", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(QuestionsPrimaryButtonStyle())
                    .disabled(viewModel.listQuestions.isEmpty || unresolvedTopics.isEmpty == false)
                }
                
            }

            HStack(spacing: 12) {
                QuestionsMetricChip(
                    title: "Import Rows",
                    value: "\(viewModel.listQuestions.count)",
                    caption: "questions loaded"
                )

                QuestionsMetricChip(
                    title: "Mapped Topics",
                    value: "\(resolvedRowCount)",
                    caption: "resolved rows"
                )

                QuestionsMetricChip(
                    title: "Unmapped",
                    value: "\(unresolvedTopics.count)",
                    caption: "topic labels"
                )
            }

            if unresolvedTopics.isEmpty == false {
                QuestionsInlineBanner(
                    title: "Topic Mapping Required",
                    message: "These topic labels do not exist in Firestore: \(unresolvedTopics.joined(separator: ", "))",
                    tint: QuestionsPalette.warning
                )
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(viewModel.listQuestions) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(question.questionText)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(QuestionsPalette.ink)
                                    .lineLimit(2)

                                Spacer(minLength: 10)

                                QuestionsPreviewChip(
                                    title: question.difficulty.uppercased(),
                                    tint: QuestionsPalette.badgeColor(for: question.difficulty)
                                )
                            }

                            HStack(spacing: 12) {
                                Text("Topic: \(question.topic ?? "Missing")")
                                Text("Options: \(question.options.count)")
                                Text("Answer: \(question.correctAnswer)")
                            }
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(QuestionsPalette.subtleInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider()
                            .overlay(QuestionsPalette.border)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(QuestionsPalette.border, lineWidth: 1)
            )
        }
        .padding(24)
        .frame(width: 920, height: 700)
        .background(QuestionsPalette.canvas)
    }
}

private struct QuestionsMetricChip: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(QuestionsPalette.subtleInk)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(QuestionsPalette.ink)

            Text(caption)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(QuestionsPalette.subtleInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(QuestionsPalette.border, lineWidth: 1)
        )
    }
}

private struct QuestionsFilterMenu: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(QuestionsPalette.subtleInk)

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minWidth: 160, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(QuestionsPalette.border, lineWidth: 1)
            )
        }
    }
}

private struct QuestionsTableHeader: View {
    let title: String
    let width: CGFloat
    let alignment: Alignment

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(QuestionsPalette.subtleInk)
            .frame(width: width, alignment: alignment)
    }
}

private struct QuestionsLibraryRow: View {
    let questionText: String
    let subject: String
    let topic: String
    let difficulty: String
    let answerCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isSelected ? QuestionsPalette.primary : QuestionsPalette.border)
                        .frame(width: 8, height: 8)

                    Text(questionText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestionsPalette.ink)
                        .lineLimit(1)
                }
                .frame(width: 280, alignment: .leading)

                Text(subject)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuestionsPalette.ink)
                    .frame(width: 132, alignment: .leading)

                Text(topic)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(QuestionsPalette.subtleInk)
                    .frame(width: 148, alignment: .leading)

                Text(difficulty.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(QuestionsPalette.badgeColor(for: difficulty))
                    .frame(width: 112, alignment: .center)

                Text("\(answerCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(QuestionsPalette.ink)
                    .frame(width: 82, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? QuestionsPalette.primary.opacity(0.08)
                    : Color.white
            )
        }
        .buttonStyle(.plain)

        Divider()
            .overlay(QuestionsPalette.border)
    }
}

private struct QuestionsInlineBanner: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(QuestionsPalette.ink)

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(QuestionsPalette.subtleInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct QuestionsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(QuestionsPalette.border, lineWidth: 1)
        )
    }
}

private struct QuestionsPreviewChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct QuestionsDetailStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(QuestionsPalette.subtleInk)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(QuestionsPalette.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(QuestionsPalette.surfaceSecondary)
        )
    }
}

private struct QuestionsEditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(QuestionsPalette.subtleInk)

            content
        }
    }
}

private struct QuestionsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(QuestionsPalette.primary.opacity(configuration.isPressed ? 0.84 : 1))
            )
    }
}

private struct QuestionsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(QuestionsPalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.9 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(QuestionsPalette.border, lineWidth: 1)
            )
    }
}

private struct QuestionsGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(QuestionsPalette.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(QuestionsPalette.primary.opacity(configuration.isPressed ? 0.08 : 0.12))
            )
    }
}

private struct QuestionsDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(QuestionsPalette.warning)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(QuestionsPalette.warning.opacity(configuration.isPressed ? 0.08 : 0.12))
            )
    }
}

private struct QuestionsPagerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(QuestionsPalette.ink)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.9 : 1))
            )
            .overlay(
                Circle()
                    .stroke(QuestionsPalette.border, lineWidth: 1)
            )
    }
}

private struct QuestionsIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(QuestionsPalette.ink)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(QuestionsPalette.surfaceSecondary.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .overlay(
                Circle()
                    .stroke(QuestionsPalette.border, lineWidth: 1)
            )
    }
}

private enum QuestionsPalette {
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.995)
    static let primary = Color(red: 0.12, green: 0.38, blue: 0.92)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.42, green: 0.46, blue: 0.56)
    static let border = Color(red: 0.86, green: 0.89, blue: 0.94)
    static let surfaceSecondary = Color(red: 0.95, green: 0.96, blue: 0.99)
    static let success = Color(red: 0.18, green: 0.64, blue: 0.38)
    static let warning = Color(red: 0.84, green: 0.36, blue: 0.34)
    static let easy = Color(red: 0.21, green: 0.49, blue: 0.94)
    static let medium = Color(red: 0.87, green: 0.58, blue: 0.19)
    static let hard = Color(red: 0.87, green: 0.28, blue: 0.34)

    static func badgeColor(for difficulty: String) -> Color {
        switch difficulty.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "easy", "beginner":
            return easy
        case "hard", "advanced":
            return hard
        default:
            return medium
        }
    }
}

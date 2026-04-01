import AppKit
import SwiftUI

struct AdminCreateChallengeView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @State private var selectedFilter: ChallengeBoardFilter = .all
    @State private var searchText = ""
    @State private var isPresentingComposer = false
    @State private var composerStartsWithImport = false
    @State private var composerSessionID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            if let successMessage = viewModel.successMessage {
                ChallengeInlineBanner(
                    title: "Challenge update",
                    message: successMessage,
                    tint: ChallengeScreenPalette.success
                )
            }

            if let errorMessage = viewModel.errorMessage {
                ChallengeInlineBanner(
                    title: "Sync warning",
                    message: errorMessage,
                    tint: ChallengeScreenPalette.danger
                )
            }

            HStack(alignment: .top, spacing: 22) {
                leftRail
                    .frame(width: 260)

                contentBoard
            }

            scheduleNote
        }
        .task {
            viewModel.loadChallengeLibrary()
        }
        .sheet(isPresented: $isPresentingComposer) {
            ChallengeComposerSheet(
                challengesViewModel: viewModel,
                startWithImport: composerStartsWithImport
            ) {
                isPresentingComposer = false
            }
            .id(composerSessionID)
            .frame(minWidth: 1020, minHeight: 760)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scheduled Challenges")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.ink)

                Text("Manage curated question sets for scheduled STEM competitive events. Challenges utilize specialized rewarding logic and fixed-time windows.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    openComposer(importingPackage: true)
                } label: {
                    Label("Import Challenge Package", systemImage: "doc.badge.plus")
                }
                .buttonStyle(ChallengeSecondaryButtonStyle())

                Button {
                    openComposer(importingPackage: false)
                } label: {
                    Label("Create New Challenge", systemImage: "plus")
                }
                .buttonStyle(ChallengePrimaryButtonStyle())
            }
        }
    }

    private var leftRail: some View {
        VStack(spacing: 18) {
            ChallengeMetricCard(
                eyebrow: "ACTIVE NOW",
                value: "\(activeChallenges.count)",
                detail: activeChallenges.isEmpty
                    ? "No live challenges right now."
                    : "\(scheduledChallenges.count) additional windows queued next.",
                tint: ChallengeScreenPalette.primary
            )

            ChallengeUpcomingCard(items: upcomingDeadlines)

            ChallengeHealthCard(
                totalChallenges: viewModel.allChallenges.count,
                activeChallenges: activeChallenges.count,
                draftChallenges: draftChallenges.count
            )
        }
    }

    private var contentBoard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ForEach(ChallengeBoardFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedFilter == filter ? .white : ChallengeScreenPalette.subtleInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedFilter == filter ? ChallengeScreenPalette.primary : Color.white)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        selectedFilter == filter
                                            ? ChallengeScreenPalette.primary
                                            : ChallengeScreenPalette.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(ChallengeScreenPalette.subtleInk)

                    TextField("Filter results", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .rounded))

                    Text("\(filteredChallenges.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ChallengeScreenPalette.primary.opacity(0.12))
                        )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ChallengeScreenPalette.border, lineWidth: 1)
                )
                .frame(maxWidth: 260)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 244, maximum: 320), spacing: 18)],
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(filteredChallenges) { challenge in
                    ChallengeBoardCard(challenge: challenge)
                }

                ChallengeCreateTile {
                    openComposer(importingPackage: false)
                }
            }

            if filteredChallenges.isEmpty {
                ChallengeEmptyState(searchText: searchText, selectedFilter: selectedFilter)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var scheduleNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ChallengeScreenPalette.primary)

            VStack(alignment: .leading, spacing: 5) {
                Text("Precision Event Scheduling")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.ink)

                Text("All scheduled challenges unlock automatically using their configured start date. Validate reward packages and imported question sets before publishing to keep launch windows stable.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
        )
    }

    private var sortedChallenges: [Challenge] {
        viewModel.allChallenges.sorted { lhs, rhs in
            let lhsStatus = challengeStatus(for: lhs)
            let rhsStatus = challengeStatus(for: rhs)

            if lhsStatus.sortPriority != rhsStatus.sortPriority {
                return lhsStatus.sortPriority < rhsStatus.sortPriority
            }

            switch lhsStatus {
            case .active:
                return lhs.endDate < rhs.endDate
            case .scheduled:
                return lhs.startDate < rhs.startDate
            case .draft:
                return lhs.updatedAt > rhs.updatedAt
            case .completed:
                return lhs.endDate > rhs.endDate
            }
        }
    }

    private var filteredChallenges: [Challenge] {
        let baseChallenges: [Challenge]

        switch selectedFilter {
        case .all:
            baseChallenges = sortedChallenges
        case .active:
            baseChallenges = activeChallenges
        case .scheduled:
            baseChallenges = scheduledChallenges
        case .draft:
            baseChallenges = draftChallenges
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return baseChallenges }

        return baseChallenges.filter { challenge in
            challenge.title.localizedCaseInsensitiveContains(query) ||
            challenge.description.localizedCaseInsensitiveContains(query) ||
            challenge.type.localizedCaseInsensitiveContains(query) ||
            challenge.difficultyLevel.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    private var activeChallenges: [Challenge] {
        sortedChallenges.filter { challengeStatus(for: $0) == .active }
    }

    private var scheduledChallenges: [Challenge] {
        sortedChallenges.filter { challengeStatus(for: $0) == .scheduled }
    }

    private var draftChallenges: [Challenge] {
        sortedChallenges.filter { challengeStatus(for: $0) == .draft }
    }

    private var upcomingDeadlines: [ChallengeDeadlineItem] {
        sortedChallenges
            .filter { status in
                let challengeState = challengeStatus(for: status)
                return challengeState == .active || challengeState == .scheduled
            }
            .sorted { lhs, rhs in
                deadlineDate(for: lhs) < deadlineDate(for: rhs)
            }
            .prefix(3)
            .map { challenge in
                let status = challengeStatus(for: challenge)
                return ChallengeDeadlineItem(
                    title: challenge.title,
                    detail: status == .scheduled
                        ? "Starts \(relativeDateLabel(for: challenge.startDate))"
                        : "Ends \(relativeDateLabel(for: challenge.endDate))",
                    tint: status == .scheduled
                        ? ChallengeScreenPalette.primary
                        : ChallengeScreenPalette.danger
                )
            }
    }

    private func openComposer(importingPackage: Bool) {
        composerStartsWithImport = importingPackage
        composerSessionID = UUID()
        isPresentingComposer = true
    }

    private func challengeStatus(for challenge: Challenge, now: Date = .now) -> ChallengeLifecycleStatus {
        if challenge.isActive == false {
            return .draft
        }

        if challenge.endDate < now {
            return .completed
        }

        if challenge.startDate > now {
            return .scheduled
        }

        return .active
    }

    private func deadlineDate(for challenge: Challenge) -> Date {
        switch challengeStatus(for: challenge) {
        case .scheduled:
            return challenge.startDate
        case .active, .draft, .completed:
            return challenge.endDate
        }
    }

    private func relativeDateLabel(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct ChallengeComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var challengesViewModel: ChallengesViewModel
    @StateObject private var topicsViewModel = TopicsViewModel()
    @StateObject private var questionsViewModel = QuestionsViewModel()

    let startWithImport: Bool
    let onCreated: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var type = "weekly"
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedTopics: [Topic] = []
    @State private var difficultyLevel: DifficultyLevel = .intermediate
    @State private var rewardType = "points"
    @State private var rewardValueText = ""
    @State private var remainTime: Int?
    @State private var importedTemplate: ChallengeImport?
    @State private var importWasTriggered = false
    @State private var isPublishing = false

    private let topicColumns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            composerHeader

            Divider()
                .overlay(ChallengeScreenPalette.border)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 22) {
                    if let errorMessage = questionsViewModel.errorMessage {
                        ChallengeInlineBanner(
                            title: "Import issue",
                            message: errorMessage,
                            tint: ChallengeScreenPalette.danger
                        )
                    }

                    if let successMessage = questionsViewModel.successMessage {
                        ChallengeInlineBanner(
                            title: "Question package",
                            message: successMessage,
                            tint: ChallengeScreenPalette.success
                        )
                    }

                    if let successMessage = challengesViewModel.successMessage, isPublishing == false {
                        ChallengeInlineBanner(
                            title: "Challenge created",
                            message: successMessage,
                            tint: ChallengeScreenPalette.success
                        )
                    }

                    overviewCards
                    packageSection
                    detailsSection
                    topicSection
                    rewardSection
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(ChallengeScreenPalette.canvas)
        .task {
            await topicsViewModel.fetchAllTopicsASync()
            questionsViewModel.topics = topicsViewModel.topics

            if startWithImport && importWasTriggered == false {
                importWasTriggered = true
                importChallengePackage()
            }
        }
    }

    private var composerHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(importedTemplate == nil ? "Create Challenge" : "Publish Imported Challenge")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.ink)

                Text("Review schedule, difficulty, question pool, and reward routing before opening the window to players.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(ChallengeSecondaryButtonStyle())

                Button {
                    publishChallenge()
                } label: {
                    if isPublishing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .frame(width: 100)
                    } else {
                        Label("Publish Challenge", systemImage: "sparkles")
                    }
                }
                .buttonStyle(ChallengePrimaryButtonStyle())
                .disabled(isPublishing)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }

    private var overviewCards: some View {
        HStack(spacing: 16) {
            ChallengeOverviewCard(
                title: "Question Pool",
                value: "\(questionCount)",
                detail: questionSourceSummary,
                tint: ChallengeScreenPalette.primary
            )

            ChallengeOverviewCard(
                title: "Window",
                value: windowSummary,
                detail: startDate.formatted(date: .abbreviated, time: .shortened),
                tint: ChallengeScreenPalette.warning
            )

            ChallengeOverviewCard(
                title: "Rewards",
                value: rewardSummary,
                detail: importedTemplate == nil ? "Manual reward profile" : "Imported reward profile",
                tint: ChallengeScreenPalette.success
            )
        }
    }

    private var packageSection: some View {
        ChallengeSectionCard(title: "Challenge Package") {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(importedTemplate == nil ? "No package loaded" : "Challenge package ready")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.ink)

                    Text(importedTemplate == nil
                        ? "Import a JSON package to preload metadata, question content, and reward mapping."
                        : "Imported \(questionsViewModel.listQuestions.count) questions from the selected package.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.subtleInk)
                }

                Spacer(minLength: 0)

                Button {
                    importChallengePackage()
                } label: {
                    Label(importedTemplate == nil ? "Load Package" : "Replace Package", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(ChallengeSecondaryButtonStyle())
            }
        }
    }

    private var detailsSection: some View {
        ChallengeSectionCard(title: "Challenge Details") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.subtleInk)

                    ChallengeTextField("Relativity Theory Sprint", text: $title)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.subtleInk)

                    TextEditor(text: $description)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
                        )
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cadence")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk)

                        Picker("Cadence", selection: $type) {
                            Text("Daily").tag("daily")
                            Text("Weekly").tag("weekly")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk)

                        Picker("Difficulty", selection: $difficultyLevel) {
                            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Date")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk)

                        DatePicker(
                            "",
                            selection: $startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Date")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk)

                        DatePicker(
                            "",
                            selection: $endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }
                }
            }
        }
    }

    private var topicSection: some View {
        ChallengeSectionCard(title: "Question Sourcing") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(importedTemplate == nil ? "Live library question pool" : "Imported question package")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.ink)

                        Text(importedTemplate == nil
                            ? "Select one or more topics, then assemble a challenge-ready question pool from the existing library."
                            : "Imported packages already include question content. You can still add topic filters for reference.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk)
                    }

                    Spacer(minLength: 0)

                    Button {
                        assembleQuestionPool()
                    } label: {
                        Label("Assemble Question Pool", systemImage: "shuffle")
                    }
                    .buttonStyle(ChallengeSecondaryButtonStyle())
                    .disabled(selectedTopics.isEmpty && importedTemplate == nil)
                }

                LazyVGrid(columns: topicColumns, alignment: .leading, spacing: 10) {
                    ForEach(topicsViewModel.topics, id: \.id) { topic in
                        let isSelected = selectedTopics.contains(where: { $0.id == topic.id })

                        Button {
                            toggleTopic(topic)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(topic.category)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))

                                Text(topic.name)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.84) : ChallengeScreenPalette.subtleInk)
                            }
                            .foregroundStyle(isSelected ? .white : ChallengeScreenPalette.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? ChallengeScreenPalette.primary : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isSelected ? ChallengeScreenPalette.primary : ChallengeScreenPalette.border,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    ChallengeFactPill(
                        label: "Selected Topics",
                        value: "\(selectedTopics.count)",
                        tint: ChallengeScreenPalette.primary
                    )

                    ChallengeFactPill(
                        label: "Library Questions",
                        value: "\(questionsViewModel.questions.count)",
                        tint: ChallengeScreenPalette.warning
                    )

                    ChallengeFactPill(
                        label: "Imported Questions",
                        value: "\(questionsViewModel.listQuestions.count)",
                        tint: ChallengeScreenPalette.success
                    )
                }
            }
        }
    }

    private var rewardSection: some View {
        ChallengeSectionCard(title: "Rewards") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reward Type")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk)

                        Picker("Reward Type", selection: $rewardType) {
                            Text("Points").tag("points")
                            Text("Badge").tag("badge")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reward Value")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk)

                        ChallengeTextField("500", text: $rewardValueText)
                    }
                }

                Text("If a package is imported, leaving the manual reward blank keeps the packaged reward blueprint.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
            }
        }
    }

    private var questionCount: Int {
        if questionsViewModel.listQuestions.isEmpty == false {
            return questionsViewModel.listQuestions.count
        }

        return questionsViewModel.questions.count
    }

    private var questionSourceSummary: String {
        if questionsViewModel.listQuestions.isEmpty == false {
            return "JSON package ready for upload"
        }

        if questionsViewModel.questions.isEmpty == false {
            return "Live library selection prepared"
        }

        return "No question source selected yet"
    }

    private var rewardSummary: String {
        if let value = Int(rewardValueText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 {
            return "\(rewardType.capitalized) \(value)"
        }

        if let rewards = importedTemplate?.rewards, let firstReward = rewards.first {
            return "\(firstReward.type.capitalized) \(firstReward.value)"
        }

        return "Optional"
    }

    private var windowSummary: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(endDate.timeIntervalSince(startDate), 0)) ?? "0h"
    }

    private func toggleTopic(_ topic: Topic) {
        if let existingIndex = selectedTopics.firstIndex(where: { $0.id == topic.id }) {
            selectedTopics.remove(at: existingIndex)
        } else {
            selectedTopics.append(topic)
        }
    }

    private func assembleQuestionPool() {
        guard selectedTopics.isEmpty == false else {
            questionsViewModel.errorMessage = "Select at least one topic before assembling a question pool."
            return
        }

        questionsViewModel.errorMessage = nil
        questionsViewModel.successMessage = nil

        Task {
            await questionsViewModel.fetchQuestions(
                forTopicIDs: selectedTopics.map(\.id),
                level: difficultyLevel.rawValue
            )
        }
    }

    private func importChallengePackage() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a Challenge Package"
        openPanel.allowedFileTypes = ["json"]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url,
               let challengePackage = questionsViewModel.importChallengesFromJSON(url: url) {
                applyImportedChallenge(challengePackage)
            }
        }
    }

    private func applyImportedChallenge(_ challengePackage: ChallengeImport) {
        importedTemplate = challengePackage
        title = challengePackage.title
        description = challengePackage.description
        type = challengePackage.type
        difficultyLevel = challengePackage.difficultyLevel
        remainTime = challengePackage.remainTime
        startDate = convertToDate(from: challengePackage.startDate) ?? .now
        endDate = convertToDate(from: challengePackage.endDate) ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

        if let firstReward = challengePackage.rewards?.first {
            rewardType = firstReward.type
            rewardValueText = "\(firstReward.value)"
        }
    }

    private func publishChallenge() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTitle.isEmpty == false else {
            challengesViewModel.errorMessage = "Challenge title is required."
            return
        }

        guard trimmedDescription.isEmpty == false else {
            challengesViewModel.errorMessage = "Challenge description is required."
            return
        }

        guard endDate > startDate else {
            challengesViewModel.errorMessage = "End date must be later than the start date."
            return
        }

        isPublishing = true
        challengesViewModel.errorMessage = nil

        if questionsViewModel.listQuestions.isEmpty == false {
            questionsViewModel.uploadQuestionsForChallenges { result in
                switch result {
                case .success(let questionIDs):
                    finalizeChallengeCreation(with: questionIDs)
                case .failure(let error):
                    DispatchQueue.main.async {
                        isPublishing = false
                        challengesViewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            return
        }

        finalizeChallengeCreation(with: questionsViewModel.questions.compactMap(\.id))
    }

    private func finalizeChallengeCreation(with questionIDs: [String]) {
        DispatchQueue.main.async {
            guard questionIDs.isEmpty == false else {
                isPublishing = false
                challengesViewModel.errorMessage = "Add at least one question before publishing a challenge."
                return
            }

            let challenge = Challenge(
                id: nil,
                type: type,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                remainTime: remainTime,
                endDate: endDate,
                difficultyLevel: difficultyLevel,
                questions: questionIDs,
                rewards: composedRewards(),
                isActive: true,
                createdAt: .now,
                updatedAt: .now
            )

            challengesViewModel.createChallenge(challenge) {
                isPublishing = false
                onCreated()
                dismiss()
            }
        }
    }

    private func composedRewards() -> [Reward]? {
        if let rewardValue = Int(rewardValueText.trimmingCharacters(in: .whitespacesAndNewlines)), rewardValue > 0 {
            return [
                Reward(
                    type: rewardType,
                    value: rewardValue,
                    description: importedTemplate?.rewards?.first?.description
                )
            ]
        }

        return importedTemplate?.rewards
    }
}

private struct ChallengeBoardCard: View {
    let challenge: Challenge

    private var status: ChallengeLifecycleStatus {
        if challenge.isActive == false {
            return .draft
        }

        if challenge.endDate < .now {
            return .completed
        }

        if challenge.startDate > .now {
            return .scheduled
        }

        return .active
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ChallengeArtwork(status: status, difficulty: challenge.difficultyLevel)
                    .frame(height: 118)

                VStack(alignment: .leading, spacing: 10) {
                    ChallengeStatusBadge(status: status)

                    HStack(spacing: 8) {
                        ChallengeMicroPill(text: challenge.difficultyLevel.rawValue, tint: .white.opacity(0.18))
                        ChallengeMicroPill(text: challenge.type.uppercased(), tint: .white.opacity(0.18))
                    }
                }
                .padding(14)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text(challengeMetadataLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.subtleInk)

                    Spacer(minLength: 0)

                    Text("\(challenge.questions.count) Questions")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.primary)
                }

                Text(challenge.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.ink)
                    .lineLimit(2)

                Text(challenge.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challengeTimingLabelTitle)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.subtleInk.opacity(0.82))

                        Text(challengeTimingLabelValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ChallengeScreenPalette.ink)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ChallengeScreenPalette.surfaceSecondary)

                        Image(systemName: status.actionSymbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ChallengeScreenPalette.primary)
                    }
                    .frame(width: 36, height: 36)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 220, alignment: .top)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 10)
    }

    private var challengeMetadataLabel: String {
        if let firstReward = challenge.rewards?.first {
            return "\(firstReward.type.capitalized) \(firstReward.value)"
        }

        return "Standard Rewarding"
    }

    private var challengeTimingLabelTitle: String {
        switch status {
        case .scheduled:
            return "STARTS"
        case .active:
            return "ENDS"
        case .draft:
            return "UPDATED"
        case .completed:
            return "COMPLETED"
        }
    }

    private var challengeTimingLabelValue: String {
        switch status {
        case .scheduled:
            return challenge.startDate.formatted(date: .abbreviated, time: .omitted)
        case .active:
            return challenge.endDate.formatted(date: .abbreviated, time: .omitted)
        case .draft:
            return challenge.updatedAt.formatted(date: .abbreviated, time: .omitted)
        case .completed:
            return challenge.endDate.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

private struct ChallengeCreateTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ChallengeScreenPalette.primary.opacity(0.12))

                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ChallengeScreenPalette.primary)
                }
                .frame(width: 54, height: 54)

                VStack(spacing: 6) {
                    Text("New Challenge")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.ink)

                    Text("Start from a template or build a fresh ruleset for the next event window.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ChallengeScreenPalette.subtleInk)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ChallengeScreenPalette.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])
                    )
                    .foregroundStyle(ChallengeScreenPalette.border)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ChallengeMetricCard: View {
    let eyebrow: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.ink)

            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)

                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 16)
        }
    }
}

private struct ChallengeUpcomingCard: View {
    let items: [ChallengeDeadlineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Deadlines")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.ink)

            if items.isEmpty {
                Text("No scheduled or active challenge windows are waiting on deadlines.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Capsule(style: .continuous)
                                .fill(item.tint)
                                .frame(width: 3, height: 36)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(ChallengeScreenPalette.ink)
                                    .lineLimit(2)

                                Text(item.detail)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ChallengeHealthCard: View {
    let totalChallenges: Int
    let activeChallenges: Int
    let draftChallenges: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Technical Health")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(statusCopy)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            HStack(spacing: 8) {
                Circle()
                    .fill(ChallengeScreenPalette.success)
                    .frame(width: 8, height: 8)

                Text("99.9% uptime")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.19, blue: 0.30),
                            Color(red: 0.10, green: 0.13, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var statusCopy: String {
        if totalChallenges == 0 {
            return "Challenge services are ready. Publish the first scheduled window to start monitoring live load."
        }

        if draftChallenges > 0 {
            return "\(draftChallenges) draft packages need review. \(activeChallenges) challenge windows are currently live."
        }

        return "All challenge services are operating at peak precision across \(totalChallenges) configured windows."
    }
}

private struct ChallengeInlineBanner: View {
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
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.ink)

                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ChallengeScreenPalette.subtleInk)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ChallengeSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.ink)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ChallengeOverviewCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.ink)

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.subtleInk)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ChallengeFactPill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.subtleInk)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(ChallengeScreenPalette.surfaceSecondary)
        )
    }
}

private struct ChallengeStatusBadge: View {
    let status: ChallengeLifecycleStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(status.tint)
            )
    }
}

private struct ChallengeMicroPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
            )
    }
}

private struct ChallengeArtwork: View {
    let status: ChallengeLifecycleStatus
    let difficulty: DifficultyLevel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 140, height: 140)
                .offset(x: 70, y: -36)
                .blur(radius: 2)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 94, height: 94)
                .offset(x: -60, y: 28)
                .blur(radius: 8)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                .padding(12)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22
            )
        )
    }

    private var gradientColors: [Color] {
        switch (status, difficulty) {
        case (.active, .advanced):
            return [Color(red: 0.04, green: 0.17, blue: 0.20), Color(red: 0.08, green: 0.42, blue: 0.52)]
        case (.active, _):
            return [Color(red: 0.06, green: 0.21, blue: 0.37), Color(red: 0.13, green: 0.50, blue: 0.84)]
        case (.scheduled, .advanced):
            return [Color(red: 0.62, green: 0.32, blue: 0.12), Color(red: 0.95, green: 0.69, blue: 0.22)]
        case (.scheduled, _):
            return [Color(red: 0.33, green: 0.33, blue: 0.67), Color(red: 0.73, green: 0.53, blue: 0.83)]
        case (.draft, _):
            return [Color(red: 0.68, green: 0.70, blue: 0.76), Color(red: 0.84, green: 0.86, blue: 0.90)]
        case (.completed, _):
            return [Color(red: 0.29, green: 0.36, blue: 0.40), Color(red: 0.49, green: 0.56, blue: 0.61)]
        }
    }
}

private struct ChallengeEmptyState: View {
    let searchText: String
    let selectedFilter: ChallengeBoardFilter

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ChallengeScreenPalette.primary)

            Text("No challenges match this view")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.ink)

            Text(description)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ChallengeScreenPalette.subtleInk)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ChallengeScreenPalette.border, lineWidth: 1)
        )
    }

    private var description: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "Clear the current search text or switch filters to see more challenge windows."
        }

        return "The \(selectedFilter.label.lowercased()) view is empty right now."
    }
}

private struct ChallengeTextField: View {
    let title: String
    @Binding var text: String

    init(_ title: String, text: Binding<String>) {
        self.title = title
        _text = text
    }

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ChallengeScreenPalette.border, lineWidth: 1)
            )
    }
}

private struct ChallengePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ChallengeScreenPalette.primary.opacity(configuration.isPressed ? 0.84 : 1))
            )
    }
}

private struct ChallengeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(ChallengeScreenPalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ChallengeScreenPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private enum ChallengeBoardFilter: CaseIterable {
    case all
    case active
    case scheduled
    case draft

    var label: String {
        switch self {
        case .all:
            return "All Challenges"
        case .active:
            return "Active"
        case .scheduled:
            return "Scheduled"
        case .draft:
            return "Draft"
        }
    }
}

private enum ChallengeLifecycleStatus {
    case active
    case scheduled
    case draft
    case completed

    var label: String {
        switch self {
        case .active:
            return "ACTIVE"
        case .scheduled:
            return "SCHEDULED"
        case .draft:
            return "DRAFT"
        case .completed:
            return "COMPLETED"
        }
    }

    var tint: Color {
        switch self {
        case .active:
            return ChallengeScreenPalette.success
        case .scheduled:
            return ChallengeScreenPalette.primary
        case .draft:
            return Color(red: 0.55, green: 0.60, blue: 0.68)
        case .completed:
            return Color(red: 0.38, green: 0.45, blue: 0.50)
        }
    }

    var sortPriority: Int {
        switch self {
        case .active:
            return 0
        case .scheduled:
            return 1
        case .draft:
            return 2
        case .completed:
            return 3
        }
    }

    var actionSymbol: String {
        switch self {
        case .active:
            return "bolt.fill"
        case .scheduled:
            return "calendar"
        case .draft:
            return "square.and.pencil"
        case .completed:
            return "checkmark"
        }
    }
}

private struct ChallengeDeadlineItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let tint: Color
}

private enum ChallengeScreenPalette {
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.995)
    static let surfaceSecondary = Color(red: 0.95, green: 0.96, blue: 0.99)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.36, green: 0.40, blue: 0.50)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
    static let primary = Color(red: 0.16, green: 0.39, blue: 0.93)
    static let success = Color(red: 0.20, green: 0.59, blue: 0.43)
    static let warning = Color(red: 0.84, green: 0.44, blue: 0.12)
    static let danger = Color(red: 0.84, green: 0.24, blue: 0.30)
}

private func convertToDate(from isoString: String) -> Date? {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return dateFormatter.date(from: isoString)
}

#Preview {
    AdminCreateChallengeView()
}

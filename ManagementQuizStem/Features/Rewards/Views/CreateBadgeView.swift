import SwiftUI

struct CreateBadgeView: View {
    @Binding private var searchText: String
    @StateObject private var viewModel = BadgesViewModel()
    @State private var selectedPage = 1
    @State private var editorContext: BadgeEditorContext?

    private let cardsPerPage = 6
    private let catalogTarget = 168

    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            feedbackBanners
            overviewCards
            catalogSection
            paginationBar
        }
        .task {
            viewModel.fetchBadges()
        }
        .sheet(item: $editorContext) { context in
            BadgeEditorSheet(
                context: context,
                origin: context.badge.map { badgeOrigin(for: $0) } ?? .custom
            ) { badge in
                if context.badge == nil {
                    viewModel.createBadge(badge)
                } else {
                    viewModel.updateBadge(badge)
                }
                editorContext = nil
            }
        }
        .onChange(of: searchText) { _ in
            selectedPage = 1
        }
        .onChange(of: filteredBadges.count) { _ in
            selectedPage = min(max(1, selectedPage), totalPages)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Badge Catalog")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(BadgeCatalogPalette.ink)

                    Text("Production")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(BadgeCatalogPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BadgeCatalogPalette.primary.opacity(0.12))
                        )
                }

                Text("Manage the visual recognition system. Configure automated seeding or architect custom milestones for learners.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(BadgeCatalogPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    viewModel.clearMessages()
                    viewModel.uploadBadges()
                } label: {
                    Label("Seed Predefined Badges", systemImage: "sparkles")
                }
                .buttonStyle(BadgeCatalogSecondaryButtonStyle())

                Button {
                    viewModel.clearMessages()
                    editorContext = BadgeEditorContext(badge: nil)
                } label: {
                    Label("Create Custom Badge", systemImage: "plus")
                }
                .buttonStyle(BadgeCatalogPrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var feedbackBanners: some View {
        if let successMessage = viewModel.successMessage {
            BadgeInlineBanner(
                title: "Catalog update ready",
                message: successMessage,
                tint: BadgeCatalogPalette.success
            )
        }

        if let errorMessage = viewModel.errorMessage {
            BadgeInlineBanner(
                title: "Rewards sync warning",
                message: errorMessage,
                tint: BadgeCatalogPalette.danger
            )
        }
    }

    private var overviewCards: some View {
        HStack(alignment: .top, spacing: 18) {
            BadgeSummaryPanel {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CATALOG MATURITY")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(BadgeCatalogPalette.subtleInk)

                        Text(maturityLabel)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(BadgeCatalogPalette.ink)

                        Text(capacityLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(BadgeCatalogPalette.subtleInk)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(BadgeCatalogPalette.primary.opacity(0.12))

                        Image(systemName: "rosette")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(BadgeCatalogPalette.primary)
                    }
                    .frame(width: 56, height: 56)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Capsule(style: .continuous)
                        .fill(BadgeCatalogPalette.primary.opacity(0.10))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(BadgeCatalogPalette.primary)
                                .frame(maxWidth: .infinity, maxHeight: 8, alignment: .leading)
                                .mask(alignment: .leading) {
                                    GeometryReader { geometry in
                                        Capsule(style: .continuous)
                                            .frame(width: geometry.size.width * maturityProgress)
                                    }
                                }
                        }

                    HStack {
                        Text(capacityFootnote)
                        Spacer(minLength: 0)
                        Text(coverageLabel)
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(BadgeCatalogPalette.primary)
                }
            }
            .frame(maxWidth: .infinity)

            BadgeSummaryPanel(fill: BadgeCatalogPalette.sidebar, showsBorder: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("CUSTOM CREATIONS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.74))

                    Text("\(customBadgeCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: -8) {
                        ForEach(customPreviewBadges.indices, id: \.self) { index in
                            BadgeMonogram(
                                label: customPreviewBadges[index].catalogMonogram,
                                tint: BadgeCatalogPalette.previewTints[index % BadgeCatalogPalette.previewTints.count]
                            )
                        }
                    }

                    Text(customBadgeFootnote)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 280)
        }
    }

    @ViewBuilder
    private var catalogSection: some View {
        if filteredBadges.isEmpty {
            BadgeEmptyState(searchText: searchText)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3),
                spacing: 18
            ) {
                ForEach(currentPageBadges, id: \.id) { badge in
                    BadgeView(
                        badge: badge,
                        origin: badgeOrigin(for: badge)
                    ) {
                        viewModel.clearMessages()
                        editorContext = BadgeEditorContext(badge: badge)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var paginationBar: some View {
        if filteredBadges.isEmpty == false && totalPages > 1 {
            HStack(spacing: 10) {
                Button {
                    selectedPage = max(1, selectedPage - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(BadgePaginationArrowButtonStyle())
                .disabled(selectedPage == 1)

                ForEach(paginationItems) { item in
                    switch item.kind {
                    case .page(let page):
                        Button("\(page)") {
                            selectedPage = page
                        }
                        .buttonStyle(BadgePaginationNumberButtonStyle(isSelected: selectedPage == page))
                    case .ellipsis:
                        Text("...")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(BadgeCatalogPalette.subtleInk)
                            .frame(width: 28)
                    }
                }

                Button {
                    selectedPage = min(totalPages, selectedPage + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(BadgePaginationArrowButtonStyle())
                .disabled(selectedPage == totalPages)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
    }

    private var maturityProgress: CGFloat {
        CGFloat(min(maturityPercentage / 100.0, 1))
    }

    private var maturityPercentage: Double {
        guard catalogTarget > 0 else { return 0 }
        return min((Double(viewModel.badges.count) / Double(catalogTarget)) * 100, 100)
    }

    private var maturityLabel: String {
        String(format: "%.1f%%", maturityPercentage)
    }

    private var capacityLabel: String {
        if viewModel.badges.count >= catalogTarget {
            return "Catalog target reached with \(viewModel.badges.count) live badges"
        }

        return "\(viewModel.badges.count) of \(catalogTarget) target badges currently live"
    }

    private var capacityFootnote: String {
        "Current Capacity: \(viewModel.badges.count)/\(catalogTarget) Badges"
    }

    private var coverageLabel: String {
        if viewModel.badges.count >= catalogTarget {
            return "Target reached across core achievement tracks"
        }

        return coverageSummary
    }

    private var coverageSummary: String {
        let labels = Dictionary(grouping: viewModel.badges) { badge in
            badge.criteria.topic.catalogToken
        }
        .filter { topic, _ in
            BadgeGenericTopic.allCases.contains(where: { $0.matches(topic) }) == false
        }
        .sorted { $0.value.count > $1.value.count }
        .map(\.key)

        switch labels.prefix(2).count {
        case 2:
            return "Deepest coverage in \(labels[0]) & \(labels[1])"
        case 1:
            return "Deepest coverage in \(labels[0])"
        default:
            return "Cross-discipline milestones seeded"
        }
    }

    private var customBadgeCount: Int {
        viewModel.badges.filter { badgeOrigin(for: $0) == .custom }.count
    }

    private var customPreviewBadges: [Badge] {
        let custom = viewModel.badges.filter { badgeOrigin(for: $0) == .custom }
        let previewSource = custom.isEmpty ? viewModel.badges : custom
        return Array(previewSource.prefix(3))
    }

    private var customBadgeFootnote: String {
        if customBadgeCount == 0 {
            return "No custom badges are live yet. Create one to add bespoke learner milestones."
        }

        return "\(customBadgeCount) custom badge\(customBadgeCount == 1 ? "" : "s") currently in the live catalog."
    }

    private var filteredBadges: [Badge] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return viewModel.badges }

        return viewModel.badges.filter { badge in
            [
                badge.catalogTitle,
                badge.catalogDescription,
                badge.criteria.action.catalogToken,
                badge.criteria.topic.catalogToken
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    private var currentPageBadges: [Badge] {
        let startIndex = max(0, (selectedPage - 1) * cardsPerPage)
        return Array(filteredBadges.dropFirst(startIndex).prefix(cardsPerPage))
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredBadges.count) / Double(cardsPerPage))))
    }

    private var paginationItems: [BadgePaginationItem] {
        let pages = [1, selectedPage - 1, selectedPage, selectedPage + 1, totalPages]
            .filter { $0 >= 1 && $0 <= totalPages }
            .sorted()

        var deduplicatedPages: [Int] = []
        for page in pages where deduplicatedPages.last != page {
            deduplicatedPages.append(page)
        }

        guard totalPages > 5 else {
            return (1...totalPages).map { BadgePaginationItem(kind: .page($0)) }
        }

        var items: [BadgePaginationItem] = []
        for page in deduplicatedPages {
            if let previousPage = items.last?.pageNumber, page - previousPage > 1 {
                items.append(BadgePaginationItem(kind: .ellipsis))
            }

            items.append(BadgePaginationItem(kind: .page(page)))
        }

        return items
    }

    private func badgeOrigin(for badge: Badge) -> BadgeOrigin {
        guard let badgeID = badge.id else { return .custom }
        return viewModel.predefinedBadgeIDs.contains(badgeID) ? .predefined : .custom
    }
}

private struct BadgeEditorContext: Identifiable {
    let id = UUID()
    let badge: Badge?

    var title: String {
        badge == nil ? "Create Custom Badge" : "Edit Badge Rules"
    }

    var submitLabel: String {
        badge == nil ? "Create Badge" : "Save Changes"
    }
}

private struct BadgeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let context: BadgeEditorContext
    let origin: BadgeOrigin
    let onSubmit: (Badge) -> Void

    @State private var draft: BadgeDraft

    init(
        context: BadgeEditorContext,
        origin: BadgeOrigin,
        onSubmit: @escaping (Badge) -> Void
    ) {
        self.context = context
        self.origin = origin
        self.onSubmit = onSubmit
        _draft = State(initialValue: BadgeDraft(badge: context.badge))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(BadgeCatalogPalette.ink)

                    Text("Configure the badge copy, criteria, and optional timing rules before publishing the catalog entry.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BadgeCatalogPalette.subtleInk)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(BadgeCatalogSecondaryButtonStyle())

                    Button(context.submitLabel) {
                        onSubmit(draft.makeBadge(from: context.badge))
                    }
                    .buttonStyle(BadgeCatalogPrimaryButtonStyle())
                    .disabled(draft.isValid == false)
                }
            }

            HStack(alignment: .top, spacing: 22) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 18) {
                        BadgeEditorSection(title: "Basic Information") {
                            VStack(spacing: 14) {
                                BadgeTextField(title: "Badge Title", text: $draft.title, prompt: "Physics Pioneer")
                                BadgeTextField(title: "Description", text: $draft.description, prompt: "Complete 10 perfect answers in a single session.")
                                BadgeTextField(title: "Icon or Emoji", text: $draft.icon, prompt: "sparkles")
                            }
                        }

                        BadgeEditorSection(title: "Core Criteria") {
                            VStack(spacing: 14) {
                                BadgeTextField(title: "Action", text: $draft.action, prompt: "complete_question")
                                BadgeTextField(title: "Topic", text: $draft.topic, prompt: "physics")

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Accuracy Threshold")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(BadgeCatalogPalette.ink)
                                        Spacer(minLength: 0)
                                        Text("\(Int(draft.accuracy.rounded()))%")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(BadgeCatalogPalette.primary)
                                    }

                                    Slider(value: $draft.accuracy, in: 0...100, step: 1)
                                }

                                Stepper(value: $draft.questionCount, in: 0...500, step: 1) {
                                    BadgeStepperLabel(
                                        title: "Question Goal",
                                        value: draft.questionCount == 0 ? "No minimum" : "\(draft.questionCount) questions"
                                    )
                                }
                            }
                        }

                        BadgeEditorSection(title: "Optional Rules") {
                            VStack(spacing: 16) {
                                Toggle(isOn: $draft.usesTimeLimit) {
                                    BadgeToggleLabel(
                                        title: "Time Limit",
                                        message: "Require the learner to finish within a fixed number of seconds."
                                    )
                                }
                                .toggleStyle(.switch)

                                if draft.usesTimeLimit {
                                    Stepper(value: $draft.timeLimit, in: 30...3600, step: 30) {
                                        BadgeStepperLabel(
                                            title: "Allowed Time",
                                            value: "\(draft.timeLimit) seconds"
                                        )
                                    }
                                }

                                Toggle(isOn: $draft.usesTimeWindow) {
                                    BadgeToggleLabel(
                                        title: "Time Window",
                                        message: "Restrict badge unlocks to a scheduled start and end time."
                                    )
                                }
                                .toggleStyle(.switch)

                                if draft.usesTimeWindow {
                                    HStack(spacing: 14) {
                                        BadgeTextField(title: "Start Time", text: $draft.windowStart, prompt: "22:00")
                                        BadgeTextField(title: "End Time", text: $draft.windowEnd, prompt: "06:00")
                                    }
                                }

                                Toggle(isOn: $draft.usesStreak) {
                                    BadgeToggleLabel(
                                        title: "Streak Requirement",
                                        message: "Require consecutive qualifying days or attempts."
                                    )
                                }
                                .toggleStyle(.switch)

                                if draft.usesStreak {
                                    Stepper(value: $draft.streak, in: 1...90, step: 1) {
                                        BadgeStepperLabel(
                                            title: "Required Streak",
                                            value: "\(draft.streak) consecutive completions"
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                VStack(spacing: 18) {
                    BadgeView(
                        badge: draft.previewBadge(existingBadge: context.badge),
                        origin: origin
                    )

                    BadgeEditorSection(title: "Rule Summary") {
                        VStack(alignment: .leading, spacing: 12) {
                            BadgeRuleSummaryRow(label: "Action", value: draft.action.catalogToken)
                            BadgeRuleSummaryRow(label: "Topic", value: draft.topic.catalogToken)
                            BadgeRuleSummaryRow(label: "Accuracy", value: draft.accuracy == 0 ? "Optional" : "\(Int(draft.accuracy.rounded()))%")
                            BadgeRuleSummaryRow(label: "Question Goal", value: draft.questionCount == 0 ? "Optional" : "\(draft.questionCount)")
                            BadgeRuleSummaryRow(label: "Time Limit", value: draft.usesTimeLimit ? "\(draft.timeLimit) seconds" : "Disabled")
                            BadgeRuleSummaryRow(label: "Window", value: draft.usesTimeWindow ? "\(draft.windowStart) - \(draft.windowEnd)" : "Disabled")
                            BadgeRuleSummaryRow(label: "Streak", value: draft.usesStreak ? "\(draft.streak) days" : "Disabled")
                        }
                    }
                }
                .frame(width: 330)
            }
        }
        .padding(24)
        .frame(width: 980, height: 720)
        .background(BadgeCatalogPalette.canvas)
    }
}

private struct BadgeDraft {
    var title: String
    var description: String
    var icon: String
    var action: String
    var topic: String
    var accuracy: Double
    var questionCount: Int
    var usesTimeLimit: Bool
    var timeLimit: Int
    var usesTimeWindow: Bool
    var windowStart: String
    var windowEnd: String
    var usesStreak: Bool
    var streak: Int

    init(badge: Badge?) {
        title = badge?.catalogTitle ?? ""
        description = badge?.catalogDescription ?? ""
        icon = badge?.icon ?? ""
        action = badge?.criteria.action ?? "complete_question"
        topic = badge?.criteria.topic ?? "physics"
        accuracy = badge?.criteria.normalizedAccuracyPercent ?? 80
        questionCount = badge?.criteria.question ?? 0
        usesTimeLimit = badge?.criteria.timeLimit != nil
        timeLimit = badge?.criteria.timeLimit ?? 180
        usesTimeWindow = badge?.criteria.timeWindow != nil
        windowStart = badge?.criteria.timeWindow?.startTime ?? "22:00"
        windowEnd = badge?.criteria.timeWindow?.endTime ?? "06:00"
        usesStreak = badge?.criteria.streak != nil
        streak = badge?.criteria.streak ?? 7
    }

    var isValid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func previewBadge(existingBadge: Badge?) -> Badge {
        makeBadge(from: existingBadge, updatingTimestamp: false)
    }

    func makeBadge(from badge: Badge?, updatingTimestamp: Bool = true) -> Badge {
        let createdAt = badge?.createdAt ?? .now
        let updatedAt = badge == nil ? nil : (updatingTimestamp ? .now : badge?.updatedAt)

        return Badge(
            id: badge?.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon.trimmingCharacters(in: .whitespacesAndNewlines),
            criteria: BadgeCriteria(
                action: action.normalizedToken,
                topic: topic.normalizedToken,
                accuracy: accuracy,
                question: questionCount,
                timeLimit: usesTimeLimit ? timeLimit : nil,
                timeWindow: usesTimeWindow ? TimeWindow(
                    startTime: windowStart.trimmingCharacters(in: .whitespacesAndNewlines),
                    endTime: windowEnd.trimmingCharacters(in: .whitespacesAndNewlines)
                ) : nil,
                streak: usesStreak ? streak : nil
            ),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct BadgeSummaryPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content
    let fill: Color
    let showsBorder: Bool

    init(
        fill: Color = .white,
        showsBorder: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.fill = fill
        self.showsBorder = showsBorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(showsBorder ? BadgeCatalogPalette.border : .clear, lineWidth: 1)
        )
    }
}

private struct BadgeInlineBanner: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(BadgeCatalogPalette.ink)

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(BadgeCatalogPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct BadgeMonogram: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(tint)
            )
            .overlay(
                Circle()
                    .stroke(BadgeCatalogPalette.sidebar, lineWidth: 2)
            )
    }
}

private struct BadgeEmptyState: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(BadgeCatalogPalette.primary)

            Text("No badges match this search")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.ink)

            Text("Try a different keyword than \"\(searchText)\" or create a custom badge to expand the catalog.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.subtleInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BadgeCatalogPalette.border, lineWidth: 1)
        )
    }
}

private struct BadgeEditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(BadgeCatalogPalette.subtleInk)

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BadgeCatalogPalette.border, lineWidth: 1)
        )
    }
}

private struct BadgeTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.ink)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BadgeCatalogPalette.canvas)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BadgeCatalogPalette.border, lineWidth: 1)
                )
        }
    }
}

private struct BadgeStepperLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.ink)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.primary)
        }
    }
}

private struct BadgeToggleLabel: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.ink)

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.subtleInk)
        }
    }
}

private struct BadgeRuleSummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.subtleInk)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BadgeCatalogPalette.ink)
        }
    }
}

private struct BadgePaginationItem: Identifiable {
    enum Kind {
        case page(Int)
        case ellipsis
    }

    let id = UUID()
    let kind: Kind

    var pageNumber: Int? {
        guard case .page(let page) = kind else { return nil }
        return page
    }
}

private enum BadgeGenericTopic: CaseIterable {
    case any
    case beginner
    case intermediate
    case advanced
    case allLevels
    case difficult

    func matches(_ value: String) -> Bool {
        switch self {
        case .any:
            return value == "Any"
        case .beginner:
            return value == "Beginner"
        case .intermediate:
            return value == "Intermediate"
        case .advanced:
            return value == "Advanced"
        case .allLevels:
            return value == "All Levels"
        case .difficult:
            return value == "Difficult"
        }
    }
}

private struct BadgeCatalogPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BadgeCatalogPalette.primary.opacity(configuration.isPressed ? 0.84 : 1))
            )
    }
}

private struct BadgeCatalogSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(BadgeCatalogPalette.subtleInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(BadgeCatalogPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private struct BadgePaginationArrowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(BadgeCatalogPalette.ink)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(.white)
            )
            .overlay(
                Circle()
                    .stroke(BadgeCatalogPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private struct BadgePaginationNumberButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isSelected ? .white : BadgeCatalogPalette.ink)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? BadgeCatalogPalette.primary : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? .clear : BadgeCatalogPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}

private enum BadgeCatalogPalette {
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.995)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.35, green: 0.39, blue: 0.49)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
    static let primary = Color(red: 0.16, green: 0.39, blue: 0.93)
    static let success = Color(red: 0.20, green: 0.59, blue: 0.43)
    static let danger = Color(red: 0.84, green: 0.24, blue: 0.30)
    static let sidebar = Color(red: 0.19, green: 0.22, blue: 0.32)
    static let previewTints: [Color] = [
        Color(red: 0.16, green: 0.39, blue: 0.93),
        Color(red: 0.84, green: 0.24, blue: 0.30),
        Color(red: 0.21, green: 0.72, blue: 0.52)
    ]
}

extension String {
    var normalizedToken: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }

    var catalogToken: String {
        let cleaned = trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")

        guard cleaned.isEmpty == false else { return "Untitled" }
        return cleaned.capitalized
    }
}

#Preview {
    CreateBadgeView(searchText: .constant(""))
}

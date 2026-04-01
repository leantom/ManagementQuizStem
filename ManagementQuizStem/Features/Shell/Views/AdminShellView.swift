import SwiftUI

struct AdminShellView: View {
    @EnvironmentObject private var authSession: AuthSessionController

    @State private var selectedSection: AdminShellSection = .dashboard
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            VStack(spacing: 0) {
                topBar
                Divider()
                    .overlay(AdminShellPalette.border.opacity(0.75))

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AdminShellPalette.canvas)
        }
        .background(AdminShellPalette.canvas)
        .frame(minWidth: 1280, minHeight: 820)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.17, green: 0.46, blue: 0.98), Color(red: 0.08, green: 0.27, blue: 0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MQ Stem Admin")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Precision CMS")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdminShellPalette.sidebarSubtle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(AdminShellSectionGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(AdminShellPalette.sidebarMuted)
                                .padding(.horizontal, 20)

                            VStack(spacing: 4) {
                                ForEach(group.sections, id: \.self) { section in
                                    AdminSidebarItem(
                                        section: section,
                                        isSelected: selectedSection == section
                                    ) {
                                        selectedSection = section
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))

                        Text(adminInitials)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authSession.currentUserEmail ?? "Admin user")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(authSession.environmentLabel.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(AdminShellPalette.sidebarMuted)
                    }
                }

                Button {
                    authSession.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(20)
        }
        .frame(width: 252, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(AdminShellPalette.sidebar)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Quick search data...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AdminShellPalette.border, lineWidth: 1)
            )

            Spacer(minLength: 0)

            Label(
                "Environment: \(authSession.environmentLabel.uppercased())",
                systemImage: "bolt.horizontal.circle.fill"
            )
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(authSession.environmentTint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(authSession.environmentTint.opacity(0.12))
            )

            HStack(spacing: 8) {
                AdminTopBarIcon(systemName: "bell.fill")
                AdminTopBarIcon(systemName: "gearshape.fill")
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(AdminShellPalette.canvas)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .dashboard:
            AdminDashboardView { section in
                selectedSection = section
            }
        default:
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    shellSectionHeader(for: selectedSection)
                    pageView(for: selectedSection)
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private func pageView(for section: AdminShellSection) -> some View {
        switch section {
        case .dashboard:
            EmptyView()
        case .subjects:
            CreateNewSubjectView()
        case .topics:
            EditTopicView()
        case .questions:
            ImportQuestionsFromJSONView()
        case .topicImports:
            UploadFromCSVView()
        case .challenges:
            AdminCreateChallengeView()
        case .rewards:
            CreateBadgeView()
        case .adminTools:
            DeleteQuestionsByTopicView()
        }
    }

    private func shellSectionHeader(for section: AdminShellSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AdminShellPalette.ink)

            Text(section.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AdminShellPalette.subtleInk)
        }
    }

    private var adminInitials: String {
        let components = (authSession.currentUserEmail ?? "admin")
            .split(separator: "@")
            .first?
            .split(separator: ".")
            .prefix(2) ?? []

        let initials = components.compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "AD" : initials.uppercased()
    }
}

private struct AdminSidebarItem: View {
    let section: AdminShellSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)

                Text(section.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .white : AdminShellPalette.sidebarSubtle)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.10) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.08) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}

private struct AdminTopBarIcon: View {
    let systemName: String

    var body: some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AdminShellPalette.ink)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white)
                )
                .overlay(
                    Circle()
                        .stroke(AdminShellPalette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

enum AdminShellSectionGroup: CaseIterable {
    case dashboard
    case contentLibrary
    case imports
    case challenges
    case rewards
    case adminTools

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .contentLibrary:
            return "Content Library"
        case .imports:
            return "Imports"
        case .challenges:
            return "Challenges"
        case .rewards:
            return "Rewards"
        case .adminTools:
            return "Admin Tools"
        }
    }

    var sections: [AdminShellSection] {
        switch self {
        case .dashboard:
            return [.dashboard]
        case .contentLibrary:
            return [.subjects, .topics, .questions]
        case .imports:
            return [.topicImports]
        case .challenges:
            return [.challenges]
        case .rewards:
            return [.rewards]
        case .adminTools:
            return [.adminTools]
        }
    }
}

enum AdminShellSection: Hashable {
    case dashboard
    case subjects
    case topics
    case questions
    case topicImports
    case challenges
    case rewards
    case adminTools

    var label: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .subjects:
            return "Subjects"
        case .topics:
            return "Topics"
        case .questions:
            return "Questions"
        case .topicImports:
            return "Topic CSV"
        case .challenges:
            return "Challenges"
        case .rewards:
            return "Badges"
        case .adminTools:
            return "Admin Tools"
        }
    }

    var title: String {
        switch self {
        case .dashboard:
            return "Main Dashboard"
        case .subjects:
            return "Subjects Library"
        case .topics:
            return "Topics Library"
        case .questions:
            return "Questions Workspace"
        case .topicImports:
            return "Topic CSV Import"
        case .challenges:
            return "Challenges Manager"
        case .rewards:
            return "Badge Catalog"
        case .adminTools:
            return "Admin Tools"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return "Real-time system health and content metrics."
        case .subjects:
            return "Create and maintain subject metadata for the content catalog."
        case .topics:
            return "Manage topic taxonomy, icons, and education levels."
        case .questions:
            return "Import and review question content for the quiz library."
        case .topicImports:
            return "Bulk import topics and normalize education-level metadata."
        case .challenges:
            return "Configure challenge payloads and active windows."
        case .rewards:
            return "Preview and seed the admin rewards catalog."
        case .adminTools:
            return "High-risk maintenance tools for question cleanup and operations."
        }
    }

    var icon: String {
        switch self {
        case .dashboard:
            return "square.grid.2x2.fill"
        case .subjects:
            return "books.vertical.fill"
        case .topics:
            return "square.stack.3d.up.fill"
        case .questions:
            return "questionmark.bubble.fill"
        case .topicImports:
            return "arrow.down.doc.fill"
        case .challenges:
            return "flag.2.crossed.fill"
        case .rewards:
            return "rosette"
        case .adminTools:
            return "wrench.and.screwdriver.fill"
        }
    }
}

private enum AdminShellPalette {
    static let sidebar = Color(red: 0.06, green: 0.09, blue: 0.16)
    static let sidebarSubtle = Color(red: 0.77, green: 0.82, blue: 0.92)
    static let sidebarMuted = Color(red: 0.47, green: 0.53, blue: 0.67)
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.995)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.35, green: 0.39, blue: 0.49)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
}

#Preview {
    AdminShellView()
        .environmentObject(AuthSessionController())
}

import AppKit
import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var authSession: AuthSessionController
    @StateObject private var viewModel = AdminDashboardViewModel()
    @State private var exportMessage: String?

    let onSelectSection: (AdminShellSection) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                header
                metricCards
                contentGrid
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            viewModel.load()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Main Dashboard")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardPalette.ink)

                Text("Real-time system health and content metrics.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardPalette.subtleInk)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    exportSnapshotToPasteboard()
                } label: {
                    Label("Export Logs", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(DashboardSecondaryButtonStyle())

                Button {
                    viewModel.load(force: true)
                } label: {
                    Label("Re-Sync Node", systemImage: "arrow.clockwise")
                }
                .buttonStyle(DashboardPrimaryButtonStyle())
            }
        }
    }

    private var metricCards: some View {
        HStack(alignment: .top, spacing: 18) {
            DashboardEnvironmentCard(
                environmentLabel: authSession.environmentLabel,
                projectID: authSession.firebaseProjectID,
                databaseID: authSession.environmentDatabaseID,
                tint: authSession.environmentTint
            )

            DashboardMetricCard(
                title: "Subjects",
                value: "\(viewModel.snapshot.subjectCount)",
                detail: "catalog total",
                tint: DashboardPalette.primary
            )

            DashboardMetricCard(
                title: "Topics",
                value: "\(viewModel.snapshot.topicCount)",
                detail: "synced library",
                tint: DashboardPalette.primary
            )

            DashboardMetricCard(
                title: "Questions",
                value: formattedCount(viewModel.snapshot.questionCount),
                detail: "ready for delivery",
                tint: DashboardPalette.primary
            )

            DashboardMetricCard(
                title: "Challenges",
                value: "\(viewModel.snapshot.currentChallengeCount)",
                detail: "active now",
                tint: DashboardPalette.danger
            )
        }
    }

    private var contentGrid: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 18) {
                DashboardPanel(title: "Activity Feed", trailingLabel: "VIEW ALL LOGS") {
                    VStack(spacing: 0) {
                        ForEach(activityItems) { item in
                            DashboardActivityRow(item: item)
                        }
                    }
                }

                if let exportMessage {
                    DashboardInlineBanner(
                        title: "Export ready",
                        message: exportMessage,
                        tint: DashboardPalette.primary
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    DashboardInlineBanner(
                        title: "Sync warning",
                        message: errorMessage,
                        tint: DashboardPalette.warning
                    )
                }
            }

            VStack(spacing: 18) {
                DashboardPanel(title: "Quick Actions") {
                    VStack(spacing: 12) {
                        DashboardQuickActionButton(
                            title: "Upload Topics",
                            icon: "doc.badge.plus",
                            tint: DashboardPalette.primary
                        ) {
                            onSelectSection(.topicImports)
                        }

                        DashboardQuickActionButton(
                            title: "Import Questions",
                            icon: "square.and.arrow.down.on.square",
                            tint: DashboardPalette.primary
                        ) {
                            onSelectSection(.questions)
                        }

                        DashboardQuickActionButton(
                            title: "Create Challenge",
                            icon: "bolt.fill",
                            tint: DashboardPalette.primary
                        ) {
                            onSelectSection(.challenges)
                        }
                    }
                }
                .frame(width: 310)

                DashboardPanel(title: "System Load") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Optimal Performance")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DashboardPalette.ink)

                        DashboardSystemLoadChart(values: [0.24, 0.33, 0.28, 0.46, 0.74, 0.58, 0.38, 0.29, 0.17])

                        HStack(spacing: 10) {
                            Label("Catalog stable", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(DashboardPalette.success)

                            Text(lastSyncedLabel)
                                .foregroundStyle(DashboardPalette.subtleInk)
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }
                .frame(width: 310)
            }
        }
    }

    private var activityItems: [DashboardActivityItem] {
        let challengeTitle = viewModel.snapshot.featuredChallenges.first?.title ?? "No active challenge"

        return [
            DashboardActivityItem(
                icon: "bolt.horizontal.circle.fill",
                title: "Environment Connected",
                message: "\(authSession.environmentLabel) is live on \(authSession.environmentDatabaseID).",
                stamp: "LIVE",
                tint: authSession.environmentTint
            ),
            DashboardActivityItem(
                icon: "books.vertical.fill",
                title: "Catalog Index Refreshed",
                message: "\(viewModel.snapshot.subjectCount) subjects and \(viewModel.snapshot.topicCount) topics are available to editors.",
                stamp: "SYNCED",
                tint: DashboardPalette.primary
            ),
            DashboardActivityItem(
                icon: "questionmark.bubble.fill",
                title: "Question Library Ready",
                message: "\(formattedCount(viewModel.snapshot.questionCount)) questions are available for import and challenge assembly.",
                stamp: "READY",
                tint: DashboardPalette.primary
            ),
            DashboardActivityItem(
                icon: "flag.2.crossed.fill",
                title: "Challenge Window Loaded",
                message: "\(viewModel.snapshot.currentChallengeCount) active challenges. Focus item: \(challengeTitle).",
                stamp: "ACTIVE",
                tint: DashboardPalette.danger
            ),
            DashboardActivityItem(
                icon: "rosette",
                title: "Rewards Catalog Online",
                message: "\(viewModel.snapshot.badgeCount) badge definitions are currently available to the admin app.",
                stamp: "READY",
                tint: DashboardPalette.success
            )
        ]
    }

    private var lastSyncedLabel: String {
        "Last sync \(viewModel.snapshot.lastSyncedAt.formatted(date: .omitted, time: .shortened))"
    }

    private func formattedCount(_ value: Int) -> String {
        if value >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = value >= 10_000 ? 1 : 0

            let shortValue = Double(value) / 1000.0
            return "\(formatter.string(from: NSNumber(value: shortValue)) ?? "\(shortValue)")k"
        }

        return "\(value)"
    }

    private func exportSnapshotToPasteboard() {
        let summary = """
        Environment: \(authSession.environmentLabel)
        Firebase Project: \(authSession.firebaseProjectID)
        Firestore Database: \(authSession.environmentDatabaseID)
        Subjects: \(viewModel.snapshot.subjectCount)
        Topics: \(viewModel.snapshot.topicCount)
        Questions: \(viewModel.snapshot.questionCount)
        Active Challenges: \(viewModel.snapshot.currentChallengeCount)
        Badges: \(viewModel.snapshot.badgeCount)
        Last Sync: \(viewModel.snapshot.lastSyncedAt.formatted(date: .abbreviated, time: .standard))
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)
        exportMessage = "Dashboard snapshot copied to the macOS pasteboard."
    }
}

private struct DashboardEnvironmentCard: View {
    let environmentLabel: String
    let projectID: String
    let databaseID: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Environment Status")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.black)

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(environmentLabel)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DashboardPalette.ink)

                    Text("Project: \(projectID)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DashboardPalette.subtleInk)
                }
            }

            Text("Database: \(databaseID)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardPalette.subtleInk)

            VStack(alignment: .leading, spacing: 6) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: 120, height: 6)
                    }

                Text("99.9% uptime")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: 280, minHeight: 148, alignment: .topLeading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DashboardPalette.border, lineWidth: 1)
        )
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.black)

            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardPalette.ink)

            Text(detail)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DashboardPalette.border, lineWidth: 1)
        )
    }
}

private struct DashboardPanel<Content: View>: View {
    let title: String
    var trailingLabel: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black)

                Spacer(minLength: 0)

                if let trailingLabel {
                    Text(trailingLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(DashboardPalette.primary)
                }
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DashboardPalette.border, lineWidth: 1)
        )
    }
}

private struct DashboardActivityItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let stamp: String
    let tint: Color
}

private struct DashboardActivityRow: View {
    let item: DashboardActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(item.tint)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DashboardPalette.ink)

                Text(item.message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(item.stamp)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(DashboardPalette.border.opacity(0.65))
        }
    }
}

private struct DashboardQuickActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardSystemLoadChart: View {
    let values: [CGFloat]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index == values.indices.dropLast(3).last ? DashboardPalette.primary : DashboardPalette.primary.opacity(0.28))
                    .frame(width: 18, height: max(24, value * 110))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .bottomLeading)
    }
}

private struct DashboardInlineBanner: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardPalette.ink)

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct DashboardPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DashboardPalette.primary.opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

private struct DashboardSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardPalette.subtleInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DashboardPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private enum DashboardPalette {
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.995)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.35, green: 0.39, blue: 0.49)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
    static let primary = Color(red: 0.16, green: 0.39, blue: 0.93)
    static let success = Color(red: 0.20, green: 0.59, blue: 0.43)
    static let warning = Color(red: 0.84, green: 0.44, blue: 0.12)
    static let danger = Color(red: 0.84, green: 0.24, blue: 0.30)
}

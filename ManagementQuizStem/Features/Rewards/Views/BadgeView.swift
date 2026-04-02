import SwiftUI

enum BadgeOrigin {
    case predefined
    case custom

    var label: String {
        switch self {
        case .predefined:
            return "Predefined"
        case .custom:
            return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .predefined:
            return "checkmark.seal"
        case .custom:
            return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .predefined:
            return BadgeCardPalette.subtleInk
        case .custom:
            return BadgeCardPalette.danger
        }
    }
}

struct BadgeView: View {
    let badge: Badge
    let origin: BadgeOrigin
    var onEdit: (() -> Void)? = nil

    private var presentation: BadgeCardPresentation {
        BadgeCardPresentation(badge: badge, origin: origin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                badgeMark

                Spacer(minLength: 0)

                Text(presentation.rarity.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.rarity.foreground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(presentation.rarity.background)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(badge.catalogTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BadgeCardPalette.ink)
                    .lineLimit(2)

                Text(badge.catalogDescription)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BadgeCardPalette.subtleInk)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 10) {
                Label(origin.label, systemImage: origin.systemImage)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(origin.tint)

                Spacer(minLength: 0)

                if let onEdit {
                    Button("Edit Rules", action: onEdit)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(BadgeCardPalette.primary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 244, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BadgeCardPalette.border, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(presentation.tint.opacity(0.07))
                .frame(width: 118, height: 88)
                .blur(radius: 0.2)
                .offset(x: 16, y: -10)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var badgeMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(presentation.tint.opacity(0.12))

            if let icon = presentation.textIcon {
                Text(icon)
                    .font(.system(size: 26))
            } else {
                Image(systemName: presentation.symbolName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(presentation.tint)
            }
        }
        .frame(width: 60, height: 60)
    }
}

struct BadgeCardPresentation {
    struct RarityStyle {
        let label: String
        let background: Color
        let foreground: Color
    }

    let tint: Color
    let rarity: RarityStyle
    let symbolName: String
    let textIcon: String?

    init(badge: Badge, origin: BadgeOrigin) {
        let normalizedTitle = badge.catalogTitle.lowercased()
        let normalizedTopic = badge.criteria.topic.normalizedToken
        let accuracy = badge.criteria.normalizedAccuracyPercent

        if badge.icon.isLikelyEmojiIcon {
            textIcon = badge.icon
        } else {
            textIcon = nil
        }

        if normalizedTitle.contains("physics") || normalizedTopic == "physics" {
            tint = BadgeCardPalette.primary
            symbolName = "atom"
        } else if normalizedTitle.contains("quantum") || normalizedTitle.contains("chemistry") || normalizedTopic == "chemistry" {
            tint = BadgeCardPalette.danger
            symbolName = "diamond.fill"
        } else if normalizedTitle.contains("cell") || normalizedTitle.contains("biology") || normalizedTopic == "biology" {
            tint = BadgeCardPalette.success
            symbolName = "circle.hexagongrid.fill"
        } else if normalizedTitle.contains("mentor") {
            tint = BadgeCardPalette.rose
            symbolName = "shield.fill"
        } else if normalizedTitle.contains("algorithm") || normalizedTitle.contains("code") || normalizedTopic == "computer_science" {
            tint = BadgeCardPalette.primary
            symbolName = "chevron.left.forwardslash.chevron.right"
        } else if normalizedTitle.contains("trailblazer") {
            tint = BadgeCardPalette.warning
            symbolName = "rocket.fill"
        } else if normalizedTitle.contains("night") {
            tint = BadgeCardPalette.indigo
            symbolName = "moon.stars.fill"
        } else if normalizedTitle.contains("bird") {
            tint = BadgeCardPalette.warning
            symbolName = "sunrise.fill"
        } else if normalizedTitle.contains("focus") || normalizedTitle.contains("precision") || normalizedTitle.contains("limit") {
            tint = BadgeCardPalette.primary
            symbolName = "scope"
        } else if normalizedTitle.contains("explorer") {
            tint = BadgeCardPalette.primary
            symbolName = "map.fill"
        } else if normalizedTitle.contains("success") {
            tint = BadgeCardPalette.success
            symbolName = "trophy.fill"
        } else if normalizedTitle.contains("master") {
            tint = BadgeCardPalette.warning
            symbolName = "crown.fill"
        } else if normalizedTitle.contains("challenger") {
            tint = BadgeCardPalette.primary
            symbolName = "bolt.fill"
        } else {
            tint = origin == .custom ? BadgeCardPalette.danger : BadgeCardPalette.primary
            symbolName = origin == .custom ? "wand.and.stars.inverse" : "rosette"
        }

        if accuracy >= 95 || badge.criteria.question >= 100 {
            rarity = RarityStyle(
                label: "LEGENDARY",
                background: BadgeCardPalette.danger.opacity(0.14),
                foreground: BadgeCardPalette.danger
            )
        } else if badge.criteria.timeLimit != nil || badge.criteria.timeWindow != nil || badge.criteria.streak != nil {
            rarity = RarityStyle(
                label: "SPECIAL",
                background: BadgeCardPalette.indigo.opacity(0.14),
                foreground: BadgeCardPalette.indigo
            )
        } else if badge.criteria.question >= 50 {
            rarity = RarityStyle(
                label: "RARE",
                background: BadgeCardPalette.primary.opacity(0.12),
                foreground: BadgeCardPalette.primary
            )
        } else if accuracy >= 80 {
            rarity = RarityStyle(
                label: "UNCOMMON",
                background: BadgeCardPalette.subtleInk.opacity(0.12),
                foreground: BadgeCardPalette.subtleInk
            )
        } else {
            rarity = RarityStyle(
                label: "COMMON",
                background: BadgeCardPalette.border.opacity(0.8),
                foreground: BadgeCardPalette.subtleInk
            )
        }
    }
}

extension Badge {
    var catalogTitle: String {
        title.trimmingOuterEmoji()
    }

    var catalogDescription: String {
        description.trimmingOuterEmoji()
    }

    var catalogMonogram: String {
        let letters = catalogTitle
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()

        return letters.isEmpty ? "BD" : letters.uppercased()
    }
}

extension BadgeCriteria {
    var normalizedAccuracyPercent: Double {
        accuracy <= 1 ? accuracy * 100 : accuracy
    }
}

private enum BadgeCardPalette {
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.35, green: 0.39, blue: 0.49)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
    static let primary = Color(red: 0.16, green: 0.39, blue: 0.93)
    static let success = Color(red: 0.20, green: 0.59, blue: 0.43)
    static let warning = Color(red: 0.88, green: 0.54, blue: 0.12)
    static let danger = Color(red: 0.84, green: 0.24, blue: 0.30)
    static let rose = Color(red: 0.73, green: 0.20, blue: 0.33)
    static let indigo = Color(red: 0.36, green: 0.47, blue: 0.93)
}

private extension String {
    func trimmingOuterEmoji() -> String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)

        while let first = value.first, first.isWhitespace || first.isEmojiLike {
            value.removeFirst()
        }

        while let last = value.last, last.isWhitespace || last.isEmojiLike {
            value.removeLast()
        }

        return value.isEmpty ? self : value
    }

    var isLikelyEmojiIcon: Bool {
        count <= 3 && isEmpty == false && allSatisfy(\.isEmojiLike)
    }
}

private extension Character {
    var isEmojiLike: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
    }
}

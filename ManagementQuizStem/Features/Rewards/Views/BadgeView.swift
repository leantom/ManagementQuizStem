import SwiftUI

struct BadgeView: View {
    let badge: Badge

    var body: some View {
        VStack(alignment: .center) {
            if badge.icon.isEmpty == false {
                Text(badge.title)
                    .font(.headline)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 64, height: 64)
                    .overlay(Text("No Icon"))
            }

            Text(badge.title)
                .font(.headline)
                .padding(.top, 8)
                .multilineTextAlignment(.center)

            Text(badge.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            HStack {
                Text("Criteria: ")
                    .font(.caption)
                Text("\(badge.criteria.action.capitalized) in \(badge.criteria.topic.capitalized) with \(Int(badge.criteria.accuracy * 100))% accuracy.")
                    .font(.caption2)
            }
            .padding(.top, 8)
            .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 5)
        .frame(width: 200)
    }
}

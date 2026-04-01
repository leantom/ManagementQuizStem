//
//  Badge.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 22/11/24.
//


import SwiftUI
import FirebaseFirestore

struct Badge: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var icon: String
    var criteria: BadgeCriteria
    var createdAt: Date
    var updatedAt: Date?
}

struct BadgeCriteria: Codable, Hashable {
    var action: String
    var topic: String
    var accuracy: Double
    var question: Int
    var timeLimit: Int? // Time in seconds (optional)
    var timeWindow: TimeWindow? // Specific time frames (optional)
    var streak: Int? // Number of consecutive days or actions (optional)
}


struct TimeWindow: Codable, Hashable {
    var startTime: String // Format "HH:mm" (24-hour)
    var endTime: String // Format "HH:mm" (24-hour)
}

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

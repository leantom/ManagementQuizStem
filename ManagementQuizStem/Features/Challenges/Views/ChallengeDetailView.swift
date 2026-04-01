//
//  ChallengeDetailView.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 20/11/24.
//
import SwiftUI

struct ChallengeDetailView: View {
    let challenge: Challenge
    

    var body: some View {
        VStack(alignment: .leading) {
            Text(challenge.title)
                .font(.largeTitle)
                .padding(.bottom, 8)

            Text(challenge.description)
                .font(.body)
                .padding(.bottom, 8)

            if let rewards = challenge.rewards {
                Text("Rewards: \(rewards)")
                    .font(.subheadline)
                    .padding(.bottom, 8)
            }

            Text("Available until: \(formattedDate(challenge.endDate))")
                .font(.footnote)
                .padding(.bottom, 16)

            Button(action: startChallenge) {
                Text("Start Challenge")
            }
            .padding()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func startChallenge() {
       
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

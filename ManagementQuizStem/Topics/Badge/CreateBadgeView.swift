//
//  CreateBadgeView.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 22/11/24.
//

import SwiftUI

struct CreateBadgeView: View {
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var icon: String = ""
    @State private var action: String = "topic_accuracy"
    @State private var topic: String = "math"
    @State private var accuracy: Double = 0.9
    @State private var createdAt: Date = Date()
    
    @State private var badgePreview: Badge? = nil
    @ObservedObject var viewModel = BadgesViewModel()
    var body: some View {
        VStack(alignment: .leading) {
            Text("Create a New Badge")
                .font(.title)
                .padding(.bottom)

            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Badge Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Badge Icon")) {
                    TextField("Icon Name (e.g., 'accuracy_master.png')", text: $icon)
                }

                Section(header: Text("Criteria")) {
                    TextField("Action", text: $action)
                    TextField("Topic", text: $topic)
                    Slider(value: $accuracy, in: 0.0...1.0, step: 0.01) {
                        Text("Accuracy")
                    }
                    Text("Accuracy: \(Int(accuracy * 100))%")
                }
                
                Section(header: Text("Metadata")) {
                    DatePicker("Created At", selection: $createdAt, displayedComponents: .date)
                }
                
                Button("Preview Badge") {
                    badgePreview = Badge(
                        id: UUID().uuidString,
                        title: title,
                        description: description,
                        icon: icon,
                        criteria: BadgeCriteria(action: action, topic: topic, accuracy: accuracy, question: 0),
                        createdAt: createdAt,
                        updatedAt: nil
                    )
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical)
                
                
                Button("Create Badge") {
                    viewModel.uploadBadges()
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical)
                if let message = viewModel.successMessage {
                    Text(message)
                        .foregroundStyle(.green)
                }
                
                if let message = viewModel.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                }
                
            }
            
            if let badge = badgePreview {
                Divider()
                    .padding(.vertical)
                
                Text("Badge Preview")
                    .font(.headline)
                
                BadgeView(badge: badge)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .frame(width: 400, height: 600)
    }
}

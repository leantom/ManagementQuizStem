//
//  CreateNewSubjectView.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 19/3/25.
//

import SwiftUI

struct EditSubjectView: View {
    @StateObject private var viewModel = TopicsViewModel()
    @State private var category: String = ""
    @State private var name: String = ""
    @State private var description: String = ""
    @State  var trending: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Subject")
                .font(.title)
                .padding(.top, 20)
            
            TextField("Enter name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("Enter description", text: $description)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("Trending", text: $trending)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Create Subject") {
                createSubject()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .frame(width: 400, height: 300)
        .padding()
    }
    
    private func createSubject() {
        // Validate input fields
        guard !category.isEmpty, !name.isEmpty, !description.isEmpty else {
            viewModel.errorMessage = "Please fill in all fields."
            return
        }
        
        // Prepare data; the uploadTopic function auto-generates an id
        let topicData: [String: String] = [
            FirestoreField.Topic.category: category,
            FirestoreField.Topic.name: name,
            FirestoreField.Topic.description: description
        ]
        
        viewModel.uploadTopic(topicData: topicData)
    }
}

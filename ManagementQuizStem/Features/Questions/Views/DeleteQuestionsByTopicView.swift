//
//  DeleteQuestionsByTopicView.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 19/3/25.
//


import SwiftUI

struct DeleteQuestionsByTopicView: View {
    @StateObject private var viewModel = QuestionsViewModel()
    @State private var topicID: String = ""
    @State private var isDeleting = false
    @State private var listQuestions: [Question] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Questions by Topic ID")
                .font(.title)
                .padding(.top, 20)
            
            // Input field for topic ID
            HStack {
                TextField("Enter Topic ID", text: $topicID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Fetch Questions") {
                    fetchQuestions()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            
            // Displaying fetched questions
            if listQuestions.count > 0 {
                List(listQuestions, id: \ .id) { question in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Question: \(question.questionText)")
                            .font(.headline)
                        Text("Answer: \(question.correctAnswer)")
                            .font(.subheadline)
                            .foregroundStyle(.black)
                        Text("Topic: \(question.topicID)")
                            .font(.subheadline)
                            .foregroundStyle(.black)
                    }
                    .padding(.vertical, 5)
                }
                .frame(height: 300)
            }
            
            // Delete button
            Button("Delete Questions") {
                deleteQuestions()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .disabled(isDeleting || listQuestions.isEmpty)
            
            // Success or error messages
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .frame(width: 400)
        .padding()
    }
    
    private func fetchQuestions() {
        viewModel.fetchQuestionsByTopic(topicID: topicID) { questions in
            listQuestions = questions
        }
    }
    
    private func deleteQuestions() {
        isDeleting = true
        viewModel.deleteQuestionsByTopic(topicID: topicID) {
            isDeleting = false
            listQuestions.removeAll()
        }
    }
}

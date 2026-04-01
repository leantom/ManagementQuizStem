//
//  ImportQuestionsView.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 15/11/24.
//

import SwiftUI

struct ImportQuestionsFromJSONView: View {
    @StateObject private var viewModel = QuestionsViewModel()
    @State private var isFileImporterPresented = false
    @State var listQuestions: [QuestionImport] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Import Questions from JSON")
                .font(.title)
                .padding(.top, 20)
            
            // Button to select JSON file
            HStack {
                Button("Select JSON File") {
                    chooseIconImage()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
                .frame(width: 120)
                // Displaying questions in a list
                if listQuestions.count > 0 {
                    List(listQuestions, id: \.id) { question in
                        VStack(alignment: .leading, spacing: 5) {
                            
                            Text("Question: \(question.questionText)")
                                .font(.headline)
                                .padding()
                            Text("Answer: \(question.correctAnswer)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Topic: \(question.topic)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                        }
                        .padding(.vertical, 5)
                    }
                    .frame(width: 500, height: 500)
                }
               
            }
            
            Button("Upload Questions") {
                viewModel.uploadQuestions()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .frame(width: 120)
            
            
            
            // Success or error message
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .frame(width: 400, height: 200)
        .padding()
        .onAppear {
            viewModel.fetchAllTopics()
        }
    }
    
    private func chooseIconImage() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose an Json File"
        openPanel.allowedFileTypes = ["json"]
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK {
                if let url = openPanel.url {
                    viewModel.importQuestionsFromJSON(url: url)
                    
                    listQuestions = viewModel.listQuestions
                }
            }
        }
        
//        if openPanel.runModal() == .OK, let selectedFileURL = openPanel.url {
//            viewModel.uploadIconImage(topic: topic, imageURL: selectedFileURL)
//        }
    }
}


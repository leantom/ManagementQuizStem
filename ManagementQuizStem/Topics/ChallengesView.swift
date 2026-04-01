//
//  ChallengesView.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 20/11/24.
//


import SwiftUI

struct AdminCreateChallengeView: View {
    @StateObject var viewModel = ChallengesViewModel()
    @StateObject var topicsViewModel = TopicsViewModel()
    @StateObject var questionsViewModel = QuestionsViewModel()
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var type: String = "daily"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var questionsInput: String = "" // Comma-separated question IDs
    @State private var rewards: String = ""
    @State  var selectedTopics: [Topic] = []
    @State var topics: [Topic] = [] // Store all topics for the Picker
    @State private var difficultyLevel: DifficultyLevel = .beginner // Default value
    @State var challenge: ChallengeImport?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Create a New Challenge")
                .font(.title)
                .padding(.bottom)

            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            TextField("Title", text: $title)
            TextField("Description", text: $description)

            Picker("Type", selection: $type) {
                Text("Daily").tag("daily")
                Text("Weekly").tag("weekly")
            }
            .pickerStyle(SegmentedPickerStyle())

            Picker("Difficulty Level", selection: $difficultyLevel) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical)
            
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("End Date", selection: $endDate, displayedComponents: .date)

            Text("Select Topics")
                    .font(.headline)
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(topics, id: \.id) { topic in
                        let isSelected = selectedTopics.contains(where: { $0.id == topic.id })
                        Text(topic.category)
                            .foregroundColor(.white)
                            .padding(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? Color.blue.opacity(0.7) : .gray)
                            .cornerRadius(8)
                            .onTapGesture {
                                if isSelected {
                                    // Deselect the topic
                                    selectedTopics.removeAll { $0.id == topic.id }
                                } else {
                                    // Select the topic
                                    selectedTopics.append(topic)
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 300)

            Button(action: chooseIconImage) {
                Text("Load Questions")
            }
            .padding(.vertical)
            
            if let err = questionsViewModel.errorMessage {
                Text("Questions is importing: \(err)")
                    .foregroundStyle(.red)
            }
            
            if let successMessage = questionsViewModel.successMessage {
                Text("Questions is importing: \(successMessage)")
                    .foregroundStyle(.green)
            }
            
            
            TextField("Rewards", text: $rewards)

            Button(action: createChallenge) {
                Text("Create Challenge")
            }
            .padding(.top)

           
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            Task {
               await topicsViewModel.fetchAllTopicsASync()
                self.topics = topicsViewModel.topics
                questionsViewModel.topics = topics
            }
            
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
                    questionsViewModel.questionIDsImport.removeAll()
                    self.challenge = questionsViewModel.importChallengesFromJSON(url: url)
                    
                    guard let challenges = self.challenge else {
                        return
                    }
                    
                    self.title = challenges.title
                    self.description = challenges.description
                    self.type = challenges.type
                    self.rewards = (challenges.rewards?.compactMap({$0.type}).joined(separator: " "))!
                    self.endDate =  convertToDate(from: challenges.endDate) ?? Date()
                    self.startDate = convertToDate(from: challenges.startDate) ?? Date()
                }
            }
        }
        
    }
    
    func loadQuestions() {
        Task {
            let topicIDs = selectedTopics.compactMap { $0.id }
            await questionsViewModel.fetchQuestions(forTopicIDs: topicIDs, level: difficultyLevel.rawValue)
        }
    }

    func createChallenge() {
        
        questionsViewModel.uploadQuestionsForChallenges()
        let now = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Collect question IDs from fetched questions
            let questionIDs = questionsViewModel.questionIDsImport

            guard !questionIDs.isEmpty else {
                viewModel.errorMessage = "No questions found for the selected topics."
                return
            }
            
            guard let challenges = self.challenge else {
                return
            }
            
            let challenge = Challenge(
                id: nil,
                type: type,
                title: title,
                description: description,
                startDate: startDate,
                remainTime: challenges.remainTime,
                endDate: endDate,
                difficultyLevel: difficultyLevel,
                questions: questionIDs,
                rewards: challenges.rewards,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )

            viewModel.createChallenge(challenge)
        }
       
    }
}


func convertToDate(from isoString: String) -> Date? {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return dateFormatter.date(from: isoString)
}

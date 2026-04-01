import SwiftUI

struct CreateNewSubjectView: View {
    @StateObject private var viewModel = SubjectsViewModel()
    @StateObject private var viewTopicModel = TopicsViewModel()
    
    @State private var selectedSubjectName: String = ""
    @State private var selectedSubject: Subject?
    
    @State private var listTopic: [Topic] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create New Subject")
                    .font(.title)
                    .padding(.top, 20)
                
                Picker("Select Subject", selection: $selectedSubjectName) {
                    ForEach(viewModel.subjects.map(\..name), id: \.self) { topicName in
                        Text(topicName).tag(topicName)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedSubjectName) { newSubject in
                    if let subject = viewModel.subjects.first(where: { $0.name == newSubject }) {
                        viewModel.name = subject.name
                        viewModel.shortName = subject.short_name
                        viewModel.description = subject.description
                        listTopic = viewTopicModel.topics.filter({ topic in
                            return topic.name == subject.name
                        })
                        viewModel.checkSubjectExists(name: subject.name)
                        selectedSubject = subject
                    }
                }

                TextField("Enter Name", text: $viewModel.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                TextField("Enter Short Name", text: $viewModel.shortName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                TextField("Enter Description", text: $viewModel.description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack {
                    TextField("Icon URL", text: $viewModel.iconURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Choose Icon") {
                        chooseIconImage()
                    }
                    
                    if let imageSelected = viewModel.selectedImage {
                        Image(nsImage: imageSelected)
                            .resizable()
                            .frame(width: 400, height: 400)
                            .clipped()
                    }
                    
                    
                }
                .padding(.horizontal)
                
                Button( viewModel.isExist ? "Update Subject" : "Create Subject") {
                    if viewModel.isExist ,
                       var selected = self.selectedSubject{
                        // let filter topicID =
                        
                        viewModel.updateSubject(selected, listTopicID: listTopic)
                        return
                    }
                    viewModel.createSubject()
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
                HStack {
                    VStack {
                        Text("Toptic: ")
                        List(viewModel.subjects) { subject in
                            HStack {
                                AsyncImage(url: URL(string: subject.icon_url ?? "")) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading) {
                                    Text(subject.name).font(.headline)
                                    Text(subject.description).font(.subheadline)
                                }
                                Spacer()
                                Text("\(subject.trending)").bold().foregroundColor(.blue)
                            }
                        }
                        .frame(width: 300, height: 250)
                    }
                    VStack {
                        Text("Toptic: ")
                        List(listTopic) { topic in
                            HStack {
                                AsyncImage(url: URL(string: topic.iconURL ?? "")) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading) {
                                    Text(topic.name).font(.headline)
                                    Text(topic.description ?? "").font(.subheadline)
                                }
                                Spacer()
                                Text("\(topic.trending)").bold().foregroundColor(.blue)
                            }
                        }
                        .frame(width: 300, height: 250)
                    }
                    
                }
                
                
                
            }
            .frame(width: 600)
            .padding()
        }
        .onAppear {
            viewTopicModel.fetchAllTopics()
            viewModel.fetchAllSubjects()
//            if viewModel.subjects.isEmpty {
//                if let jsonData = subjectsData.data(using: .utf8) {
//                    do {
//                        viewModel.subjects = try JSONDecoder().decode([Subject].self, from: jsonData)
//                    } catch {
//                        print("Failed to load static subjects: \(error)")
//                    }
//                }
//            }
        }
    }
    
    
    private func chooseIconImage() {
            let openPanel = NSOpenPanel()
            openPanel.title = "Choose an Icon Image"
            openPanel.allowedFileTypes = ["jpg", "jpeg", "png"]
            openPanel.allowsMultipleSelection = false
            
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    if let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            viewModel.selectedImage = image
                            viewModel.iconURL = url.absoluteString
                        }
                    }
                }
            }
        }
}
// Static subjects JSON data
let subjectsData = """
[
{
    "name": "Math",
    "short_name": "Math",
    "description": "Study of numbers, quantities, structures, and space.",
    "trending": 95,
    "icon_url": "example.com/math.png"
},
{
    "name": "Physics",
    "short_name": "Physics",
    "description": "Study of matter, energy, motion, and forces.",
    "trending": 90,
    "icon_url": "example.com/physics.png"
},
{
    "name": "Chemistry",
    "short_name": "Chem",
    "description": "Study of substances, their interactions, and properties.",
    "trending": 85,
    "icon_url": "example.com/chemistry.png"
},
{
    "name": "Biology",
    "short_name": "Bio",
    "description": "Study of life and living organisms.",
    "trending": 88,
    "icon_url": "example.com/biology.png"
},
{
    "name": "Computer Science",
    "short_name": "CS",
    "description": "Study of computation, algorithms, and data processing.",
    "trending": 98,
    "icon_url": "example.com/computerscience.png"
},
{
    "name": "Engineering",
    "short_name": "Eng",
    "description": "Application of science and technology to design and build structures, machines, and systems.",
    "trending": 92,
    "icon_url": "example.com/engineering.png"
},
{
    "name": "Earth Science",
    "short_name": "EarthSci",
    "description": "Study of the Earth, including geology, meteorology, and oceanography.",
    "trending": 80,
    "icon_url": "example.com/earthscience.png"
},
{
    "name": "Technology & Innovation",
    "short_name": "Tech",
    "description": "Study of emerging technologies, innovation, and digital advancements.",
    "trending": 96,
    "icon_url": "example.com/technology.png"
},
{
    "name": "AWS Certified Developer - Associate",
    "short_name": "AWS",
    "description": "The AWS Certified Developer – Associate exam",
    "trending": 96,
    "icon_url": "example.com/technology.png"
}
]
"""

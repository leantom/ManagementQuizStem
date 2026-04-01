import SwiftUI

struct EditTopicView: View {
    @ObservedObject var viewModel: TopicsViewModel = TopicsViewModel()
    @State var topic: Topic?
//
    @State  var name: String = ""
    @State  var id: String = ""
    @State  var selectedCategory: String = ""
    @State  var trending: String = ""
    @State  var description: String = ""
    @State  var iconURL: String =  ""
    @State  var isImagePickerPresented = false
    @State private var imageSelected: NSImage? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Topic")
                .font(.title)
                .padding(.top, 20)
            
            TextField("Name : ", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("Id", text: $id)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            // Picker for selecting a category
            Picker("Subject", selection: $selectedCategory) {
                ForEach(viewModel.topics.sorted { $0.name < $1.name }, id: \.id) { topic in
                    Text("\(topic.name) - \(topic.category)").tag(topic.id)
                    }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedCategory) { newValue in
                print(newValue)
                if let firstItem = viewModel.filterTopicsId(by: newValue) {
                    name = firstItem.category
                    description = firstItem.description ?? ""
                    topic = firstItem
                    id = firstItem.id
                    
                    trending = String(firstItem.trending ?? 0)
                }
            }
                    
            
            TextField("Description", text: $description)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Trending", text: $trending)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            HStack {
                TextField("Icon URL", text: $iconURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Choose Icon") {
                    chooseIconImage()
                }
                
                if let imageSelected = imageSelected {
                    Image(nsImage: imageSelected)
                        .resizable()
                        .frame(width: 400, height: 400)
                        .clipped()
                }
                
                
            }
            .padding(.horizontal)
            HStack {
                Button("Save Changes") {
                    guard let topic = self.topic else { return }
                    
                    let updatedTopic = Topic( id: topic.id,
                        name: name,
                        category: selectedCategory,
                        description: description,
                                              trending: Int(trending) ?? 0
                    )
                    if let _iconURL = imageSelected  {
                        viewModel.uploadIconImage(topic: updatedTopic, image: _iconURL)
                    } else {
                        viewModel.updateTopic(topic: updatedTopic)
                    }
                    
                }
                .padding()
                .buttonStyle(PrimaryButtonStyle())
                
                
                Button("Remove Topic") {
                    guard let topic = self.topic else { return }
                    
                    viewModel.removeTopic(by: topic.id)
                    
                }
                .padding()
                .buttonStyle(PrimaryButtonStyle())
            }
           
            
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .frame(width: 400, height: 400)
        .padding()
        .onAppear {
            viewModel.fetchAllTopics() // Fetch topics when the view appears
        }
    }
    
    private func chooseIconImage() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose an Icon Image"
        openPanel.allowedFileTypes = ["jpg", "jpeg", "png"]
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK {
                if let url = openPanel.url {
                    imageSelected = NSImage(contentsOf: url)
                }
            }
        }
        
//        if openPanel.runModal() == .OK, let selectedFileURL = openPanel.url {
//            viewModel.uploadIconImage(topic: topic, imageURL: selectedFileURL)
//        }
    }
}


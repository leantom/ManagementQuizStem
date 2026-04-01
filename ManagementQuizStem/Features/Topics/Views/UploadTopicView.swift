import SwiftUI
import AppKit

struct UploadFromCSVView: View {
    @StateObject private var viewModel = TopicsViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Upload Topics from CSV")
                .font(.title)
                .padding(.top, 20)
            
            Button("Select CSV File") {
                selectCSVFile()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            
            Button("Update Education Level") {
                viewModel.updateEducationLevelAll()
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
        .frame(width: 400, height: 200)
        .padding()
        .onAppear {
            Task {
                viewModel.fetchAllTopics()
            }
        }
    }
    
    private func selectCSVFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a CSV File"
        openPanel.allowedFileTypes = ["csv"]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            viewModel.uploadTopicsFromCSV(url: url)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

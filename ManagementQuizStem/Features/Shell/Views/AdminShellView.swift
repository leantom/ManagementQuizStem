import SwiftUI

struct AdminShellView: View {
    @EnvironmentObject private var authSession: AuthSessionController
    @State private var selectedSection: SidebarSection? = .uploadFromCSV
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSection) {
                Section(header: Text("Manage Topics")) {
                    NavigationLink(value: SidebarSection.uploadFromCSV) {
                        Label("Upload from CSV", systemImage: "doc.text")
                    }
                    NavigationLink(value: SidebarSection.deleteQuestionByTopicID) {
                        Label("Delete Questions by Topic ID", systemImage: "doc.text")
                    }
                    NavigationLink(value: SidebarSection.editTopics) {
                        Label("Edit Topics", systemImage: "pencil")
                    }
                    NavigationLink(value: SidebarSection.viewTopics) {
                        Label("Import Questions from Topics", systemImage: "book.fill")
                    }
                    NavigationLink(value: SidebarSection.uploadChallenge) {
                        Label("Upload challenges", systemImage: "book.fill")
                    }
                    NavigationLink(value: SidebarSection.createBagde) {
                        Label("Create Badge", systemImage: "book.fill")
                    }
                    NavigationLink(value: SidebarSection.createSubject) {
                        Label("Create subject", systemImage: "book.fill")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
        } detail: {
            // Main Content Area
            switch selectedSection {
            case .uploadFromCSV:
                UploadFromCSVView()
            case .editTopics:
                EditTopicView()
            case .viewTopics:
                ImportQuestionsFromJSONView()
            case .uploadChallenge:
                AdminCreateChallengeView()
            case .createBagde:
                CreateBadgeView()
            case .createSubject:
                CreateNewSubjectView()
            case .deleteQuestionByTopicID:
                DeleteQuestionsByTopicView()
            default:
                Text("Select an option from the sidebar")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Text(authSession.currentUserEmail ?? "Admin")
                    .foregroundColor(.secondary)

                Button("Sign Out") {
                    authSession.signOut()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    AdminShellView()
        .environmentObject(AuthSessionController())
}

// Define Sidebar Sections
enum SidebarSection: Hashable {
    case uploadFromCSV
    case editTopics
    case viewTopics
    case uploadChallenge
    case createBagde
    case createSubject
    case deleteQuestionByTopicID
}

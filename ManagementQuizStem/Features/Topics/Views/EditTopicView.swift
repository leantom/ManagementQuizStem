import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditTopicView: View {
    private static let allParentSubjects = "All Subjects"
    private static let anyEducationLevel = "Any Level"

    @StateObject private var viewModel = TopicsViewModel()
    @State private var searchText = ""
    @State private var selectedParentSubject = allParentSubjects
    @State private var selectedEducationLevel = anyEducationLevel
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            libraryPanel
            editorPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.loadLibrary()
        }
        .confirmationDialog(
            "Delete topic?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Topic", role: .destructive) {
                viewModel.deleteSelectedTopic()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the topic document from Firestore. Related questions are not deleted automatically.")
        }
    }

    private var filteredTopics: [Topic] {
        viewModel.filteredTopics(
            matching: searchText,
            parentSubject: selectedParentSubject == Self.allParentSubjects ? nil : selectedParentSubject,
            educationLevel: selectedEducationLevel == Self.anyEducationLevel ? nil : selectedEducationLevel
        )
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Library Queue")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(TopicsPalette.ink)

                    Text("Review topic naming, subject mapping, and icon coverage before publishing changes.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(TopicsPalette.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Button {
                    viewModel.startCreatingNewTopic()
                } label: {
                    Label("Add Topic", systemImage: "plus")
                }
                .buttonStyle(TopicsPrimaryButtonStyle())
            }

            HStack(spacing: 12) {
                TopicsMetricChip(
                    title: "Topics",
                    value: "\(viewModel.topics.count)",
                    icon: "square.stack.3d.up.fill"
                )

                TopicsMetricChip(
                    title: "Trending",
                    value: "\(viewModel.trendingTopicCount)",
                    icon: "arrow.up.right"
                )

                TopicsMetricChip(
                    title: "Subjects",
                    value: "\(viewModel.parentSubjectOptions.count)",
                    icon: "books.vertical.fill"
                )
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.black)

                TextField("Search topics, parent subjects, descriptions, or IDs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TopicsPalette.border, lineWidth: 1)
            )

            HStack(spacing: 12) {
                TopicsFilterField(
                    title: "Parent Subject",
                    selection: $selectedParentSubject,
                    options: [Self.allParentSubjects] + viewModel.parentSubjectOptions
                )

                TopicsFilterField(
                    title: "Education Level",
                    selection: $selectedEducationLevel,
                    options: [Self.anyEducationLevel] + viewModel.educationLevelOptions
                )
            }

            topicsTable

            if let message = viewModel.successMessage {
                TopicsInlineBanner(
                    title: "Saved",
                    message: message,
                    tint: TopicsPalette.success
                )
            }

            if let message = viewModel.errorMessage {
                TopicsInlineBanner(
                    title: "Attention",
                    message: message,
                    tint: TopicsPalette.warning
                )
            }
        }
        .frame(maxWidth: 650, alignment: .topLeading)
    }

    private var topicsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TopicsTableHeader(title: "Topic", width: 236, alignment: .leading)
                TopicsTableHeader(title: "Parent Subject", width: 172, alignment: .leading)
                TopicsTableHeader(title: "Level", width: 118, alignment: .leading)
                TopicsTableHeader(title: "Trend", width: 72, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(TopicsPalette.surfaceSecondary)

            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Spacer()
                }
                .frame(minHeight: 520)
            } else if filteredTopics.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(TopicsPalette.primary)

                    Text("No topics match the current filters.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(TopicsPalette.ink)

                    Text("Adjust the search query or filter menus, or create a new topic record.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(TopicsPalette.subtleInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 520)
                .padding(30)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(filteredTopics) { topic in
                            TopicLibraryRow(
                                topic: topic,
                                isSelected: viewModel.selectedTopicID == topic.id
                            ) {
                                viewModel.selectTopic(topic)
                            }
                        }
                    }
                }
                .frame(minHeight: 520)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(TopicsPalette.border, lineWidth: 1)
        )
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.isCreatingNew ? "Create Topic" : "Topic Detail")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(TopicsPalette.ink)

                    Text("Record ID: \(viewModel.selectedTopicReference)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(TopicsPalette.primary)
                }

                Spacer(minLength: 12)

                Button {
                    viewModel.startCreatingNewTopic()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TopicsPalette.subtleInk)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(TopicsPalette.surfaceSecondary)
                        )
                }
                .buttonStyle(.plain)
            }

            TopicsEditorCard {
                HStack(spacing: 14) {
                    TopicGraphicPreview(
                        iconURL: viewModel.iconURL,
                        selectedImage: viewModel.selectedImage,
                        size: 72
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Selection")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(TopicsPalette.primary)

                        Text(viewModel.category.isEmpty ? "New Topic Draft" : viewModel.category)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(TopicsPalette.ink)

                        Text(viewModel.name.isEmpty ? "Parent subject pending" : viewModel.name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(TopicsPalette.subtleInk)
                    }

                    Spacer(minLength: 0)
                }
            }

            if let warning = viewModel.draftWarnings.first {
                TopicsInlineBanner(
                    title: "Validation Incomplete",
                    message: warning,
                    tint: TopicsPalette.warning
                )
            }

            TopicsEditorField(title: "Topic Name", text: $viewModel.category)
            TopicsEditorField(title: "Parent Subject", text: $viewModel.name)

            VStack(alignment: .leading, spacing: 8) {
                Text("Education Level")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black)

                Picker("", selection: $viewModel.educationLevel) {
                    Text("Select Level").tag("")

                    ForEach(viewModel.educationLevelOptions, id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TopicsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TopicsPalette.border, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Topic Description")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black)

                TextEditor(text: $viewModel.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(TopicsPalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(TopicsPalette.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(TopicsPalette.border, lineWidth: 1)
                    )
            }

            TopicsEditorCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trending Status")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(.black)

                            Text(viewModel.trending > 0 ? "Topic is surfaced in boosted listings." : "Topic is not currently promoted.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(TopicsPalette.subtleInk)
                        }

                        Spacer(minLength: 16)

                        Toggle("", isOn: trendingBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Stepper(value: $viewModel.trending, in: 0...100, step: 5) {
                        HStack {
                            Text("Trending Score")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(TopicsPalette.ink)

                            Spacer(minLength: 12)

                            Text("\(viewModel.trending)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(TopicsPalette.primary)
                        }
                    }
                    .disabled(viewModel.trending == 0)
                }
            }

            TopicsEditorCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Material Icon")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.black)

                    HStack(spacing: 14) {
                        TopicGraphicPreview(
                            iconURL: viewModel.iconURL,
                            selectedImage: viewModel.selectedImage,
                            size: 92
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.selectedImage == nil && viewModel.iconURL.isEmpty ? "No icon assigned yet." : "Topic icon ready for upload.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(TopicsPalette.subtleInk)

                            Button("Choose Graphic") {
                                chooseIconImage()
                            }
                            .buttonStyle(TopicsSecondaryButtonStyle())
                        }

                        Spacer(minLength: 0)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Discard") {
                    viewModel.discardDraftChanges()
                }
                .buttonStyle(TopicsSecondaryButtonStyle())

                Button {
                    viewModel.saveTopic()
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }

                        Text(viewModel.isCreatingNew ? "Create Topic" : "Save Changes")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TopicsPrimaryButtonStyle())
                .disabled(viewModel.isSaving)
            }

            if viewModel.isCreatingNew == false {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete Topic")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(TopicsPalette.danger)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: 430, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(TopicsPalette.border, lineWidth: 1)
        )
    }

    private var trendingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.trending > 0 },
            set: { isEnabled in
                if isEnabled {
                    viewModel.trending = max(viewModel.trending, 50)
                } else {
                    viewModel.trending = 0
                }
            }
        )
    }

    private func chooseIconImage() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a topic icon"
        openPanel.allowedContentTypes = [.jpeg, .png]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == .OK,
               let url = openPanel.url,
               let image = NSImage(contentsOf: url) {
                DispatchQueue.main.async {
                    viewModel.selectedImage = image
                }
            }
        }
    }
}

private struct TopicLibraryRow: View {
    let topic: Topic
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? TopicsPalette.primary : .clear)
                    .frame(width: 3, height: 74)

                HStack(spacing: 0) {
                    TopicGraphicPreview(iconURL: topic.iconURL ?? "", selectedImage: nil, size: 42)
                        .frame(width: 74)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(topic.category)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(TopicsPalette.ink)
                            .lineLimit(1)

                        Text(topic.description?.isEmpty == false ? topic.description ?? "" : topic.id)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .lineLimit(2)
                    }
                    .frame(width: 236, alignment: .leading)

                    Text(topic.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TopicsPalette.subtleInk)
                        .lineLimit(2)
                        .frame(width: 172, alignment: .leading)

                    Text(topic.educationLevel ?? "Unassigned")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle((topic.educationLevel ?? "").isEmpty ? TopicsPalette.warning : TopicsPalette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(TopicsPalette.surfaceSecondary)
                        )
                        .frame(width: 118, alignment: .leading)

                    Image(systemName: (topic.trending ?? 0) > 0 ? "arrow.up.right" : "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle((topic.trending ?? 0) > 0 ? TopicsPalette.primary : TopicsPalette.subtleInk.opacity(0.7))
                        .frame(width: 72)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .background(isSelected ? TopicsPalette.primary.opacity(0.04) : Color.white)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(TopicsPalette.border.opacity(0.7))
        }
    }
}

private struct TopicGraphicPreview: View {
    let iconURL: String
    let selectedImage: NSImage?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TopicsPalette.surfaceSecondary)
                .frame(width: size, height: size)

            if let selectedImage {
                Image(nsImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
                    .frame(width: size, height: size)
            } else if let url = URL(string: iconURL), iconURL.isEmpty == false {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.16)
                } placeholder: {
                    placeholder
                }
                .frame(width: size, height: size)
            } else {
                placeholder
                    .frame(width: size, height: size)
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: max(18, size * 0.26), weight: .bold))
            .foregroundStyle(TopicsPalette.primary)
    }
}

private struct TopicsEditorField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.black)

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(.black)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TopicsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TopicsPalette.border, lineWidth: 1)
                )
        }
    }
}

private struct TopicsFilterField: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.black)

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TopicsPalette.border, lineWidth: 1)
            )
        }
    }
}

private struct TopicsTableHeader: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .center

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.black)
            .frame(width: width, alignment: alignment)
    }
}

private struct TopicsEditorCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(TopicsPalette.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(TopicsPalette.border, lineWidth: 1)
            )
    }
}

private struct TopicsMetricChip: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TopicsPalette.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(TopicsPalette.ink)

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(TopicsPalette.subtleInk)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TopicsPalette.border, lineWidth: 1)
        )
    }
}

private struct TopicsInlineBanner: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TopicsPalette.ink)

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(TopicsPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct TopicsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TopicsPalette.primary.opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

private struct TopicsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(TopicsPalette.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(TopicsPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private enum TopicsPalette {
    static let primary = Color(red: 0.16, green: 0.39, blue: 0.93)
    static let success = Color(red: 0.20, green: 0.59, blue: 0.43)
    static let warning = Color(red: 0.86, green: 0.34, blue: 0.34)
    static let danger = Color(red: 0.82, green: 0.20, blue: 0.28)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.35, green: 0.39, blue: 0.49)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
    static let surfaceSecondary = Color(red: 0.96, green: 0.97, blue: 0.995)
}

#Preview {
    EditTopicView()
}

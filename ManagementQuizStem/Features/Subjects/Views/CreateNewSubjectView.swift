import SwiftUI
import UniformTypeIdentifiers

struct CreateNewSubjectView: View {
    @StateObject private var viewModel = SubjectsViewModel()
    @State private var searchText = ""
    @State private var topicSearchText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            libraryPanel
            editorPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.loadLibrary()
        }
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Subjects Library")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(SubjectsPalette.ink)

                    Text("Manage core educational entities and their curriculum structure.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(SubjectsPalette.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Button {
                    viewModel.startCreatingNewSubject()
                } label: {
                    Label("Add New Subject", systemImage: "plus")
                }
                .buttonStyle(SubjectsPrimaryButtonStyle())
            }

            HStack(spacing: 12) {
                Label("\(viewModel.subjects.count) subjects", systemImage: "books.vertical.fill")
                Label("\(viewModel.topics.count) linked topics", systemImage: "square.stack.3d.up.fill")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(SubjectsPalette.subtleInk)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.black)

                TextField("Search subjects, categories, or IDs...", text: $searchText)
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
                    .stroke(SubjectsPalette.border, lineWidth: 1)
            )

            subjectsTable

            if let message = viewModel.successMessage {
                SubjectsInlineBanner(
                    title: "Saved",
                    message: message,
                    tint: SubjectsPalette.success
                )
            }

            if let message = viewModel.errorMessage {
                SubjectsInlineBanner(
                    title: "Attention",
                    message: message,
                    tint: SubjectsPalette.warning
                )
            }
        }
        .frame(maxWidth: 560, alignment: .topLeading)
    }

    private var subjectsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SubjectsTableHeader(title: "Icon", width: 74)
                SubjectsTableHeader(title: "Name", width: 160, alignment: .leading)
                SubjectsTableHeader(title: "Topic Count", width: 96, alignment: .leading)
                SubjectsTableHeader(title: "Category Mapping", width: 126, alignment: .leading)
                SubjectsTableHeader(title: "Last Updated", width: 96, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SubjectsPalette.surfaceSecondary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(viewModel.filteredSubjects(matching: searchText)) { subject in
                        SubjectLibraryRow(
                            subject: subject,
                            reference: viewModel.subjectReference(for: subject),
                            categoryMapping: viewModel.categoryMapping(for: subject),
                            topicCount: viewModel.topicCount(for: subject),
                            lastUpdatedLabel: viewModel.lastUpdatedLabel(for: subject),
                            isSelected: viewModel.selectedSubjectID == subject.id
                        ) {
                            viewModel.selectSubject(subject)
                        }
                    }
                }
            }
            .frame(minHeight: 500)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SubjectsPalette.border, lineWidth: 1)
        )
    }

    private var filteredTopicOptions: [Topic] {
        let sortedTopics = viewModel.topics.sorted { lhs, rhs in
            let titleComparison = lhs.category.localizedCaseInsensitiveCompare(rhs.category)
            if titleComparison == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return titleComparison == .orderedAscending
        }

        let query = topicSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return sortedTopics }

        return sortedTopics.filter { topic in
            topic.category.localizedCaseInsensitiveContains(query) ||
            topic.name.localizedCaseInsensitiveContains(query) ||
            (topic.description?.localizedCaseInsensitiveContains(query) ?? false) ||
            (topic.educationLevel?.localizedCaseInsensitiveContains(query) ?? false) ||
            topic.id.localizedCaseInsensitiveContains(query)
        }
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.isCreatingNew ? "Create Subject" : "Edit Subject")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(SubjectsPalette.ink)

                    Text("System reference: \(viewModel.selectedSubjectReference)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(SubjectsPalette.primary)
                }

                Spacer(minLength: 12)

                Button {
                    viewModel.startCreatingNewSubject()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SubjectsPalette.subtleInk)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(SubjectsPalette.surfaceSecondary)
                        )
                }
                .buttonStyle(.plain)
            }

            SubjectsEditorCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Subject Icon")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.black)

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(SubjectsPalette.surfaceSecondary)

                            if let selectedImage = viewModel.selectedImage {
                                Image(nsImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(14)
                            } else if let url = URL(string: viewModel.iconURL), viewModel.iconURL.isEmpty == false {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .padding(14)
                                } placeholder: {
                                    Image(systemName: viewModel.selectedCategoryIcon)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(SubjectsPalette.primary)
                                }
                            } else {
                                Image(systemName: viewModel.selectedCategoryIcon)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(SubjectsPalette.primary)
                            }
                        }
                        .frame(width: 96, height: 96)

                        Button("Change Graphic") {
                            chooseIconImage()
                        }
                        .buttonStyle(SubjectsSecondaryButtonStyle())
                    }
                }
            }

            SubjectsEditorField(title: "Display Name", text: $viewModel.name)

            SubjectsReadOnlyField(title: "Slug", value: viewModel.subjectSlug)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Subject Color")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: viewModel.colorHex) ?? SubjectsPalette.surfaceSecondary)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(SubjectsPalette.border, lineWidth: 1)
                        )

                    TextField("FFFFFF", text: $viewModel.colorHex)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .foregroundStyle(.black)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SubjectsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SubjectsPalette.border, lineWidth: 1)
                )

                Text("Enter a 6-character hex value like FFFFFF.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(SubjectsPalette.subtleInk)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Category Mapping")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black)

                Picker("", selection: $viewModel.selectedCategoryMapping) {
                    ForEach(viewModel.categoryMappings, id: \.self) { mapping in
                        Text(mapping).tag(mapping)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SubjectsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SubjectsPalette.border, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Linked Topics")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.black)

                    Spacer()

                    Text("\(viewModel.selectedTopicCount) selected")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.selectedTopicCount == 0 ? SubjectsPalette.warning : SubjectsPalette.primary)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(SubjectsPalette.subtleInk)

                    TextField("Search topics by title, subject, or level...", text: $topicSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SubjectsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SubjectsPalette.border, lineWidth: 1)
                )

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if filteredTopicOptions.isEmpty {
                            Text(viewModel.topics.isEmpty ? "No topics available yet." : "No topics match the current search.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(SubjectsPalette.subtleInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredTopicOptions) { topic in
                                SubjectsTopicSelectionRow(
                                    topic: topic,
                                    isSelected: viewModel.isTopicSelected(topic)
                                ) {
                                    viewModel.toggleTopicSelection(topic)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(minHeight: 170, maxHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SubjectsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SubjectsPalette.border, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Curriculum Level")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black)

                HStack(spacing: 10) {
                    ForEach(viewModel.curriculumLevels, id: \.self) { level in
                        Button {
                            viewModel.selectedCurriculumLevel = level.rawValue
                        } label: {
                            Text(level.rawValue.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(viewModel.selectedCurriculumLevel == level.rawValue ? .white : SubjectsPalette.subtleInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(viewModel.selectedCurriculumLevel == level.rawValue ? SubjectsPalette.primary : SubjectsPalette.surfaceSecondary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Subject Description")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black)

                TextEditor(text: $viewModel.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(SubjectsPalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 118)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(SubjectsPalette.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SubjectsPalette.border, lineWidth: 1)
                    )
            }

            HStack(spacing: 14) {
                SubjectsStatCard(title: "Total Qs", value: formattedCount(viewModel.totalQuestionCount))
                SubjectsStatCard(title: "Passing Rate", value: String(format: "%.1f%%", viewModel.selectedPassingRate))
            }

            Button {
                viewModel.saveSubject()
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    Text(viewModel.isCreatingNew ? "Create Subject" : "Save Changes")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SubjectsPrimaryButtonStyle())
            .disabled(viewModel.isSaving)

            Button {
                viewModel.archiveSelectedSubject()
            } label: {
                Text("Archive Subject")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(SubjectsPalette.danger)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: 430, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SubjectsPalette.border, lineWidth: 1)
        )
    }

    private func formattedCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func chooseIconImage() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a subject icon"
        openPanel.allowedContentTypes = [.jpeg, .png]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url, let image = NSImage(contentsOf: url) {
                DispatchQueue.main.async {
                    viewModel.selectedImage = image
                    viewModel.iconURL = url.absoluteString
                }
            }
        }
    }
}

private struct SubjectsTopicSelectionRow: View {
    let topic: Topic
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? SubjectsPalette.primary : SubjectsPalette.subtleInk.opacity(0.7))

                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.category)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(SubjectsPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(topic.name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(SubjectsPalette.subtleInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let educationLevel = topic.educationLevel, educationLevel.isEmpty == false {
                    Text(educationLevel.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(SubjectsPalette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? SubjectsPalette.primary.opacity(0.35) : SubjectsPalette.border.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SubjectLibraryRow: View {
    let subject: Subject
    let reference: String
    let categoryMapping: String
    let topicCount: Int
    let lastUpdatedLabel: String
    let isSelected: Bool
    let action: () -> Void

    private var subjectAccentColor: Color {
        Color(hex: subject.color_hex ?? "#000000") ?? SubjectsPalette.primary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? SubjectsPalette.primary : .clear)
                    .frame(width: 3, height: 72)

                HStack(spacing: 0) {
                    iconCell
                        .frame(width: 74)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(subject.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(SubjectsPalette.ink)

                        Text(reference)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    }
                    .frame(width: 160, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(topicCount)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(SubjectsPalette.primary)
                        Text("Topics")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(SubjectsPalette.primary)
                    }
                    .frame(width: 96, alignment: .leading)

                    Text(categoryMapping)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SubjectsPalette.subtleInk)
                        .frame(width: 126, alignment: .leading)

                    Text(lastUpdatedLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 96, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .background(isSelected ? SubjectsPalette.primary.opacity(0.04) : Color.white)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(SubjectsPalette.border.opacity(0.7))
        }
    }

    private var iconCell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(subjectAccentColor.opacity(0.14))
                .frame(width: 42, height: 42)

            if let url = URL(string: subject.icon_url), subject.icon_url.isEmpty == false {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } placeholder: {
                    Image(systemName: SubjectCategoryMapping.mapping(for: subject.name).icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(subjectAccentColor)
                }
                .frame(width: 42, height: 42)
            } else {
                Image(systemName: SubjectCategoryMapping.mapping(for: subject.name).icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(subjectAccentColor)
            }
        }
    }
}

private struct SubjectsEditorField: View {
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
                        .fill(SubjectsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SubjectsPalette.border, lineWidth: 1)
                )
        }
    }
}

private struct SubjectsReadOnlyField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.black)

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(SubjectsPalette.subtleInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SubjectsPalette.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SubjectsPalette.border, lineWidth: 1)
                )
        }
    }
}

private struct SubjectsTableHeader: View {
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

private struct SubjectsEditorCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SubjectsPalette.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SubjectsPalette.border, lineWidth: 1)
            )
    }
}

private struct SubjectsStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.black)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(SubjectsPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SubjectsPalette.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SubjectsPalette.border, lineWidth: 1)
        )
    }
}

private struct SubjectsInlineBanner: View {
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
                    .foregroundStyle(SubjectsPalette.ink)

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SubjectsPalette.subtleInk)
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

private struct SubjectsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SubjectsPalette.primary.opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

private struct SubjectsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(SubjectsPalette.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SubjectsPalette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        guard sanitized.count == 6,
              let value = Int(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

private enum SubjectsPalette {
    static let primary = Color(red: 0.16, green: 0.39, blue: 0.93)
    static let success = Color(red: 0.20, green: 0.59, blue: 0.43)
    static let warning = Color(red: 0.84, green: 0.44, blue: 0.12)
    static let danger = Color(red: 0.82, green: 0.20, blue: 0.28)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let subtleInk = Color(red: 0.35, green: 0.39, blue: 0.49)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.93)
    static let surfaceSecondary = Color(red: 0.96, green: 0.97, blue: 0.995)
}

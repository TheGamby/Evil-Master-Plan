import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\IdeaInboxItem.createdAt, order: .reverse)]) private var inboxItems: [IdeaInboxItem]
    @State private var draftTitle = ""
    @State private var draftBody = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PanelCard(title: "Quick Capture", subtitle: "Fast input first. Structure can happen later.") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Idea title", text: $draftTitle)
                            .textFieldStyle(.roundedBorder)

                        TextField("Context, fragment, or next thought", text: $draftBody, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)

                        Button(action: addInboxItem) {
                            Label("Send to Inbox", systemImage: "tray.and.arrow.down.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                PanelCard(title: "Inbox Queue", subtitle: "Promote an item when it deserves a real project.") {
                    if inboxItems.isEmpty {
                        EmptyStateView(
                            title: "Inbox Is Clear",
                            message: "Drop rough ideas here before they disappear.",
                            systemImage: "tray"
                        )
                    } else {
                        ForEach(inboxItems) { item in
                            InboxCard(item: item, promoteAction: {
                                promote(item)
                            }, archiveAction: {
                                item.state = .archived
                                item.touch()
                            })
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Inbox")
    }

    private func addInboxItem() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return
        }

        modelContext.insert(IdeaInboxItem(title: title, body: draftBody))
        draftTitle = ""
        draftBody = ""
        try? modelContext.save()
    }

    private func promote(_ item: IdeaInboxItem) {
        let project = Project.starter(title: item.title)
        project.summary = item.body.isEmpty ? project.summary : item.body
        project.tags = ["inbox"]
        item.linkedProject = project
        item.state = .converted
        item.touch()
        modelContext.insert(project)
        try? modelContext.save()
    }
}

private struct InboxCard: View {
    let item: IdeaInboxItem
    let promoteAction: () -> Void
    let archiveAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                    if !item.body.isEmpty {
                        Text(item.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(item.state.title)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack {
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let linkedProject = item.linkedProject {
                    TagChip(title: linkedProject.title)
                }
            }

            HStack {
                Button("Promote to Project", action: promoteAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(item.state != .open)
                Button("Archive", action: archiveAction)
                    .buttonStyle(.bordered)
                    .disabled(item.state == .archived)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        InboxView()
    }
    .modelContainer(PreviewContainer.shared)
}

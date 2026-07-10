import SwiftUI

// MARK: - SidebarView

/// The primary navigation sidebar for the application.
///
/// Displays:
/// - Search bar
/// - Quick actions (Favorites, Recents, Archive)
/// - Notebook tree (folders, sections)
/// - Smart collections
public struct SidebarView: View {

    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator

    @State private var searchText: String = ""
    @State private var selectedSection: SidebarSection = .all

    private let notebookManager = NotebookManager.shared

    public init() {}

    public var body: some View {
        List(selection: $selectedSection) {
            // Search
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search notebooks...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            // Quick Access
            Section("Quick Access") {
                Label("All Notebooks", systemImage: "book.closed")
                    .tag(SidebarSection.all)

                Label("Favorites", systemImage: "star")
                    .tag(SidebarSection.favorites)

                Label("Recent", systemImage: "clock")
                    .tag(SidebarSection.recent)

                Label("Archive", systemImage: "archivebox")
                    .tag(SidebarSection.archive)
            }

            // Notebooks
            Section("Notebooks") {
                let notebooks = filteredNotebooks()
                if notebooks.isEmpty {
                    Text("No notebooks yet")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                ForEach(notebooks) { notebook in
                    NotebookRow(notebook: notebook)
                        .onTapGesture {
                            if let firstPage = notebook.pages.first {
                                coordinator.navigateToCanvas(
                                    notebookID: notebook.id,
                                    pageID: firstPage.id
                                )
                            }
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {}
                            Button("Duplicate", systemImage: "plus.square") {}
                            Button("Move to Archive", systemImage: "archivebox") {
                                notebookManager.archiveNotebook(notebook.id)
                            }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) {}
                        }
                }
            }

            // Smart Collections (placeholder)
            Section("Smart Collections") {
                Label("Recently Modified", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Label("With Handwriting", systemImage: "pencil.tip")
                    .foregroundStyle(.secondary)
                Label("Tagged: Important", systemImage: "tag")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Inscribe")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewNotebook) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Actions

    private func createNewNotebook() {
        let notebook = notebookManager.createNotebook(
            title: "New Notebook",
            template: .blank
        )
        // Create first page
        let page = PageModel(
            backgroundType: .grid,
            pageSize: .infinite
        )
        notebook.pages.append(page)
    }

    private func filteredNotebooks() -> [NotebookModel] {
        let notebooks = notebookManager.fetchNotebooks()
        if searchText.isEmpty {
            return notebooks
        }
        return notebooks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - SidebarSection

enum SidebarSection: Hashable {
    case all
    case favorites
    case recent
    case archive
}

// MARK: - NotebookRow

struct NotebookRow: View {
    let notebook: NotebookModel

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(notebook.title)
                    .lineLimit(1)
                Text("\(notebook.pages.count) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: notebook.isFavorite ? "book.fill" : "book.closed")
                .foregroundStyle(colorForLabel(notebook.colorLabel))
        }
    }

    private func colorForLabel(_ label: String?) -> Color {
        guard let label = label else { return .accentColor }
        switch label {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .accentColor
        }
    }
}

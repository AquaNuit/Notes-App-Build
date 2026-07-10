import SwiftUI

// MARK: - NotebookGalleryView

/// A gallery-style grid view for browsing notebooks.
///
/// Displays notebooks as cards in a responsive grid with:
/// - Thumbnail previews
/// - Title and metadata
/// - Color labels
/// - Context menus for quick actions
public struct NotebookGalleryView: View {

    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator

    @State private var notebooks: [NotebookModel] = []
    @State private var isCreatingNotebook: Bool = false
    @State private var sortOrder: NotebookSortOrder = .dateModified

    private let notebookManager = NotebookManager.shared

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    // Create button
                    Button(action: { isCreatingNotebook = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("New Notebook")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3/4, contentMode: .fit)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Notebook cards
                    ForEach(sortedNotebooks()) { notebook in
                        NotebookCard(notebook: notebook)
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
                                Button(notebook.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                       systemImage: notebook.isFavorite ? "star.slash" : "star") {
                                    notebookManager.toggleFavorite(notebook.id)
                                    refreshNotebooks()
                                }
                                Button("Duplicate", systemImage: "plus.square") {}
                                Button("Archive", systemImage: "archivebox") {
                                    notebookManager.archiveNotebook(notebook.id)
                                    refreshNotebooks()
                                }
                                Divider()
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    notebookManager.deleteNotebook(notebook.id)
                                    refreshNotebooks()
                                }
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Notebooks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        ForEach(NotebookSortOrder.allCases, id: \.self) { order in
                            Button(order.displayName) {
                                sortOrder = order
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isCreatingNotebook) {
                CreateNotebookSheet { notebook in
                    refreshNotebooks()
                }
            }
            .onAppear {
                refreshNotebooks()
            }
        }
    }

    private func sortedNotebooks() -> [NotebookModel] {
        switch sortOrder {
        case .dateModified:
            return notebooks.sorted { $0.modificationDate > $1.modificationDate }
        case .dateCreated:
            return notebooks.sorted { $0.creationDate > $1.creationDate }
        case .title:
            return notebooks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private func refreshNotebooks() {
        notebooks = notebookManager.fetchNotebooks()
    }
}

// MARK: - NotebookSortOrder

enum NotebookSortOrder: String, CaseIterable {
    case dateModified
    case dateCreated
    case title

    var displayName: String {
        switch self {
        case .dateModified: return "Date Modified"
        case .dateCreated: return "Date Created"
        case .title: return "Title"
        }
    }
}

// MARK: - NotebookCard

struct NotebookCard: View {
    let notebook: NotebookModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail area
            RoundedRectangle(cornerRadius: 8)
                .fill(thumbnailColor)
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    VStack {
                        Spacer()
                        Image(systemName: "book.closed")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if notebook.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .padding(6)
                    }
                }

            Text(notebook.title)
                .font(.caption)
                .lineLimit(1)

            Text("\(notebook.pages.count) pages")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var thumbnailColor: Color {
        guard let label = notebook.colorLabel else { return .accentColor }
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

// MARK: - CreateNotebookSheet

struct CreateNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var selectedTemplate: TemplateType = .blank
    @State private var selectedColor: String? = nil

    let onComplete: (NotebookModel) -> Void

    private let notebookManager = NotebookManager.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField("Notebook Title", text: $title)

                Section("Template") {
                    ForEach(TemplateType.allCases, id: \.self) { template in
                        HStack {
                            Image(systemName: template.iconName)
                            Text(template.displayName)
                            Spacer()
                            if selectedTemplate == template {
                                Image(systemName: "checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTemplate = template }
                    }
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(["blue", "green", "orange", "purple", "red", "yellow"], id: \.self) { color in
                            Circle()
                                .fill(colorForLabel(color))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture { selectedColor = color }
                        }
                    }
                }
            }
            .navigationTitle("New Notebook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let notebook = notebookManager.createNotebook(
                            title: title.isEmpty ? "Untitled" : title,
                            template: selectedTemplate
                        )
                        notebook.colorLabel = selectedColor
                        // Add first page
                        let page = PageModel(
                            backgroundType: backgroundType(for: selectedTemplate),
                            pageSize: .infinite
                        )
                        notebook.pages.append(page)
                        dismiss()
                        onComplete(notebook)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func backgroundType(for template: TemplateType) -> BackgroundType {
        switch template {
        case .blank: return .blank
        case .grid: return .grid
        case .dotGrid: return .dotGrid
        case .ruled: return .ruled
        case .musicStaff: return .musicStaff
        case .graphPaper: return .graphPaper
        }
    }

    private func colorForLabel(_ label: String) -> Color {
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

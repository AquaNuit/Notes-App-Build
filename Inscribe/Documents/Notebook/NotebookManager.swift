import Foundation
import OSLog
import InscribeCore
import InscribeCanvas

// MARK: - NotebookManager

/// Manages notebook CRUD operations.
///
/// This manager handles the creation, deletion, renaming, archiving,
/// and querying of notebooks. It works with in-memory models for now;
/// SwiftData persistence will be added in a future sprint.
public class NotebookManager {

    nonisolated(unsafe) public static let shared = NotebookManager()

    private var notebooks: [NotebookModel] = []
    private let logger = Logger(subsystem: "com.inscribe.documents", category: "NotebookManager")

    // MARK: - CRUD Operations

    /// Create a new notebook.
    public func createNotebook(title: String, template: TemplateType = .blank) -> NotebookModel {
        let notebook = NotebookModel(
            title: title,
            template: template
        )
        notebooks.append(notebook)
        logger.info("Created notebook: \(title)")
        return notebook
    }

    /// Delete a notebook by ID.
    public func deleteNotebook(_ id: UUID) {
        notebooks.removeAll { $0.id == id }
        logger.info("Deleted notebook: \(id)")
    }

    /// Rename a notebook.
    public func renameNotebook(_ id: UUID, title: String) {
        if let index = notebooks.firstIndex(where: { $0.id == id }) {
            notebooks[index].title = title
            notebooks[index].modificationDate = Date()
        }
    }

    /// Toggle favorite status.
    public func toggleFavorite(_ id: UUID) {
        if let index = notebooks.firstIndex(where: { $0.id == id }) {
            notebooks[index].isFavorite.toggle()
        }
    }

    /// Archive a notebook.
    public func archiveNotebook(_ id: UUID) {
        if let index = notebooks.firstIndex(where: { $0.id == id }) {
            notebooks[index].isArchived = true
        }
    }

    /// Unarchive a notebook.
    public func unarchiveNotebook(_ id: UUID) {
        if let index = notebooks.firstIndex(where: { $0.id == id }) {
            notebooks[index].isArchived = false
        }
    }

    // MARK: - Querying

    /// Fetch all non-archived notebooks.
    public func fetchNotebooks() -> [NotebookModel] {
        notebooks.filter { !$0.isArchived }
            .sorted { $0.modificationDate > $1.modificationDate }
    }

    /// Fetch archived notebooks.
    public func fetchArchivedNotebooks() -> [NotebookModel] {
        notebooks.filter { $0.isArchived }
            .sorted { $0.modificationDate > $1.modificationDate }
    }

    /// Fetch favorite notebooks.
    public func fetchFavoriteNotebooks() -> [NotebookModel] {
        notebooks.filter { $0.isFavorite && !$0.isArchived }
            .sorted { $0.modificationDate > $1.modificationDate }
    }

    /// Fetch a specific notebook by ID.
    public func fetchNotebook(_ id: UUID) -> NotebookModel? {
        notebooks.first { $0.id == id }
    }

    /// Search notebooks by title.
    public func searchNotebooks(query: String) -> [NotebookModel] {
        guard !query.isEmpty else { return fetchNotebooks() }
        return notebooks.filter { $0.title.localizedCaseInsensitiveContains(query) && !$0.isArchived }
    }

    /// Get total notebook count.
    public var notebookCount: Int { notebooks.count }
}

// MARK: - NotebookModel

public class NotebookModel: Identifiable, ObservableObject {
    public let id: UUID
    @Published public var title: String
    @Published public var creationDate: Date
    @Published public var modificationDate: Date
    @Published public var iconName: String?
    @Published public var colorLabel: String?
    @Published public var isArchived: Bool
    @Published public var isFavorite: Bool
    @Published public var sortOrder: Int
    @Published public var template: TemplateType

    public var pages: [PageModel] = []

    public init(
        id: UUID = UUID(),
        title: String,
        creationDate: Date = Date(),
        modificationDate: Date = Date(),
        iconName: String? = nil,
        colorLabel: String? = nil,
        isArchived: Bool = false,
        isFavorite: Bool = false,
        sortOrder: Int = 0,
        template: TemplateType = .blank
    ) {
        self.id = id
        self.title = title
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.iconName = iconName
        self.colorLabel = colorLabel
        self.isArchived = isArchived
        self.isFavorite = isFavorite
        self.sortOrder = sortOrder
        self.template = template
    }
}

// MARK: - TemplateType

public enum TemplateType: String, CaseIterable, Codable, Sendable {
    case blank
    case grid
    case dotGrid
    case ruled
    case musicStaff
    case graphPaper

    public var displayName: String {
        switch self {
        case .blank: return "Blank"
        case .grid: return "Grid"
        case .dotGrid: return "Dot Grid"
        case .ruled: return "Ruled"
        case .musicStaff: return "Music Staff"
        case .graphPaper: return "Graph Paper"
        }
    }

    public var iconName: String {
        switch self {
        case .blank: return "rectangle.split.2x2"
        case .grid: return "grid"
        case .dotGrid: return "circle.grid.2x2"
        case .ruled: return "lineweight"
        case .musicStaff: return "music.note.list"
        case .graphPaper: return "function"
        }
    }
}

// MARK: - PageModel

public class PageModel: Identifiable, ObservableObject {
    public let id: UUID
    @Published public var title: String?
    @Published public var creationDate: Date
    @Published public var modificationDate: Date
    @Published public var sortOrder: Int
    @Published public var backgroundType: BackgroundType
    @Published public var pageSize: PageSize
    @Published public var isTemplate: Bool
    @Published public var strokeCount: Int = 0

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        creationDate: Date = Date(),
        modificationDate: Date = Date(),
        sortOrder: Int = 0,
        backgroundType: BackgroundType = .grid,
        pageSize: PageSize = .infinite,
        isTemplate: Bool = false
    ) {
        self.id = id
        self.title = title
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.sortOrder = sortOrder
        self.backgroundType = backgroundType
        self.pageSize = pageSize
        self.isTemplate = isTemplate
    }
}

// MARK: - TagModel

public class TagModel: Identifiable, ObservableObject {
    public let id: UUID
    @Published public var name: String
    @Published public var colorHex: String

    public init(id: UUID = UUID(), name: String, colorHex: String = "#007AFF") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

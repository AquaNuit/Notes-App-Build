import Foundation

// MARK: - UndoableAction

/// A reversible action that can be undone and redone.
///
/// Every mutation to the canvas or document model should be wrapped in an
/// UndoableAction so the user can undo/redo it. Actions can be grouped
/// into transactions via UndoGroup for compound operations.
public protocol UndoableAction: AnyObject, Sendable {
    /// A human-readable label for this action (e.g., "Draw Stroke", "Delete Page")
    var label: String { get }

    /// Undo this action, reverting its effects
    func undo() throws

    /// Redo this action, reapplying its effects
    func redo() throws
}

// MARK: - StrokeAction

/// An undoable action specifically for stroke operations.
public final class StrokeAction: UndoableAction {
    public let label: String
    public let strokeID: UUID
    public let pageID: UUID

    private let undoBlock: @Sendable () throws -> Void
    private let redoBlock: @Sendable () throws -> Void

    public init(
        label: String,
        strokeID: UUID,
        pageID: UUID,
        undo: @escaping @Sendable () throws -> Void,
        redo: @escaping @Sendable () throws -> Void
    ) {
        self.label = label
        self.strokeID = strokeID
        self.pageID = pageID
        self.undoBlock = undo
        self.redoBlock = redo
    }

    public func undo() throws {
        try undoBlock()
    }

    public func redo() throws {
        try redoBlock()
    }
}

// MARK: - CompositeAction

/// Combines multiple actions into a single undoable group.
/// Useful for operations like "Move Selection" (remove + add strokes at new positions).
public final class CompositeAction: UndoableAction, @unchecked Sendable {
    public let label: String
    private var actions: [UndoableAction]

    public init(label: String, actions: [UndoableAction] = []) {
        self.label = label
        self.actions = actions
    }

    public func addAction(_ action: UndoableAction) {
        actions.append(action)
    }

    public func undo() throws {
        try actions.reversed().forEach { try $0.undo() }
    }

    public func redo() throws {
        try actions.forEach { try $0.redo() }
    }
}

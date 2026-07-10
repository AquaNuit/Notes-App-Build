import Foundation

// MARK: - UndoGroup

/// Groups multiple undoable actions into a single transaction.
///
/// Undo groups allow compound operations (like moving a selection of strokes)
/// to be undone as a single action rather than requiring the user to undo
/// each stroke individually.
///
/// Usage:
/// ```swift
/// let group = UndoGroup(label: "Move Strokes")
/// group.addAction(action1)
/// group.addAction(action2)
/// undoManager.registerUndo(group)
/// ```
public class UndoGroup: UndoableAction {
    public let label: String
    public let timestamp: Date

    private var actions: [UndoableAction]

    public init(label: String, actions: [UndoableAction] = []) {
        self.label = label
        self.timestamp = Date()
        self.actions = actions
    }

    /// Add an action to this group
    public func addAction(_ action: UndoableAction) {
        actions.append(action)
    }

    /// The number of actions in this group
    public var actionCount: Int { actions.count }

    /// Whether the group is empty (no actions to undo/redo)
    public var isEmpty: Bool { actions.isEmpty }

    // MARK: - UndoableAction

    public func undo() throws {
        // Undo in reverse order
        for action in actions.reversed() {
            try action.undo()
        }
    }

    public func redo() throws {
        // Redo in original order
        for action in actions {
            try action.redo()
        }
    }
}

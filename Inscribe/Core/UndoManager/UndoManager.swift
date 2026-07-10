import Foundation

// MARK: - UndoManager

/// Manages undo and redo history for canvas and document operations.
///
/// Features:
/// - Unlimited undo/redo (bounded by memory limit)
/// - Grouped operations via UndoGroup
/// - Per-action labels for UI display
/// - Automatic memory management (evicts oldest actions when limit reached)
/// - Coalescing of rapid consecutive same-type operations
public class UndoManager {

    /// Maximum number of actions to keep in the undo stack
    public var maxUndoCount: Int {
        didSet { evictIfNeeded() }
    }

    /// Whether to coalesce rapid consecutive operations of the same type
    public var coalesceEnabled: Bool = true

    /// Time window in seconds for coalescing
    public var coalesceTimeWindow: TimeInterval = 0.25

    // MARK: - Private State

    private var undoStack: [UndoableAction] = []
    private var redoStack: [UndoableAction] = []
    private var activeGroup: UndoGroup? = nil
    private var lastActionTime: Date = .distantPast

    // MARK: - Public Properties

    public var canUndo: Bool { !undoStack.isEmpty || activeGroup?.isEmpty == false }
    public var canRedo: Bool { !redoStack.isEmpty }

    public var undoCount: Int {
        undoStack.count + (activeGroup?.isEmpty == false ? 1 : 0)
    }

    public var redoCount: Int { redoStack.count }

    /// Label of the top undo action (for UI display)
    public var undoLabel: String? {
        if let group = activeGroup, !group.isEmpty {
            return group.label
        }
        return undoStack.last?.label
    }

    /// Label of the top redo action (for UI display)
    public var redoLabel: String? {
        redoStack.last?.label
    }

    // MARK: - Initialization

    public init(maxUndoCount: Int = 500) {
        self.maxUndoCount = maxUndoCount
    }

    // MARK: - Registering Actions

    /// Register an undoable action.
    /// - Parameter action: The action to register
    public func registerUndo(_ action: UndoableAction) {
        if let group = activeGroup {
            group.addAction(action)
        } else {
            if coalesceEnabled {
                coalesceAction(action)
            } else {
                undoStack.append(action)
            }
            evictIfNeeded()
        }
        // Clear redo stack on new action
        redoStack.removeAll()
        lastActionTime = Date()
    }

    /// Begin a new undo group. All subsequent registerUndo calls will be
    /// grouped until endUndoGroup() is called.
    /// - Parameter label: Label for the group
    public func beginUndoGroup(_ label: String) {
        if activeGroup != nil {
            // Nested groups are merged into the outer group
            return
        }
        activeGroup = UndoGroup(label: label)
    }

    /// End the current undo group and register it as a single composite action.
    public func endUndoGroup() {
        guard let group = activeGroup, !group.isEmpty else {
            activeGroup = nil
            return
        }
        undoStack.append(group)
        activeGroup = nil
        evictIfNeeded()
    }

    /// Cancel the current undo group without registering it.
    public func cancelUndoGroup() {
        activeGroup = nil
    }

    // MARK: - Undo / Redo

    /// Undo the most recent action.
    /// - Throws: Errors from the action's undo implementation
    public func undo() throws {
        guard canUndo else { return }

        let action: UndoableAction
        if let group = activeGroup, !group.isEmpty {
            action = group
            activeGroup = nil
        } else {
            action = undoStack.removeLast()
        }

        try action.undo()
        redoStack.append(action)
    }

    /// Redo the most recently undone action.
    /// - Throws: Errors from the action's redo implementation
    public func redo() throws {
        guard canRedo else { return }

        let action = redoStack.removeLast()
        try action.redo()
        undoStack.append(action)
        evictIfNeeded()
    }

    /// Remove all undo and redo history.
    public func removeAll() {
        undoStack.removeAll()
        redoStack.removeAll()
        activeGroup = nil
    }

    // MARK: - Private

    private func coalesceAction(_ action: UndoableAction) {
        let now = Date()
        if now.timeIntervalSince(lastActionTime) < coalesceTimeWindow,
           let lastAction = undoStack.last,
           type(of: lastAction) == type(of: action),
           lastAction.label == action.label {
            // Merge with the last action
            // For stroke actions, this is a no-op (strokes are additive)
            return
        }
        undoStack.append(action)
    }

    private func evictIfNeeded() {
        while undoStack.count > maxUndoCount {
            undoStack.removeFirst()
        }
    }
}

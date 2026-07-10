import XCTest
@testable import InscribeCore

final class UndoManagerTests: XCTestCase {

    func testUndoRedo() throws {
        let manager = UndoManager()
        var value = ""

        let action = StrokeAction(
            label: "Append 'a'",
            strokeID: UUID(),
            pageID: UUID(),
            undo: { value = "" },
            redo: { value = "a" }
        )

        manager.registerUndo(action)
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)

        try manager.undo()
        XCTAssertEqual(value, "")
        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)

        try manager.redo()
        XCTAssertEqual(value, "a")
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    func testRedoStackClearedOnNewAction() throws {
        let manager = UndoManager()

        let action1 = StrokeAction(label: "A", strokeID: UUID(), pageID: UUID(), undo: {}, redo: {})
        let action2 = StrokeAction(label: "B", strokeID: UUID(), pageID: UUID(), undo: {}, redo: {})

        manager.registerUndo(action1)
        try manager.undo()
        XCTAssertTrue(manager.canRedo)

        manager.registerUndo(action2)
        XCTAssertFalse(manager.canRedo) // Redo stack cleared
    }

    func testUndoGroup() throws {
        let manager = UndoManager()
        var count = 0

        manager.beginUndoGroup("Group")
        manager.registerUndo(StrokeAction(
            label: "+1", strokeID: UUID(), pageID: UUID(),
            undo: { count -= 1 }, redo: { count += 1 }
        ))
        manager.registerUndo(StrokeAction(
            label: "+2", strokeID: UUID(), pageID: UUID(),
            undo: { count -= 2 }, redo: { count += 2 }
        ))
        manager.endUndoGroup()

        // Undo should reverse both
        try manager.undo()
        XCTAssertEqual(count, -3)
        XCTAssertTrue(manager.canRedo)

        // Redo should re-apply both
        try manager.redo()
        XCTAssertEqual(count, 3)
    }

    func testMemoryLimitEviction() {
        let manager = UndoManager(maxUndoCount: 3)

        for i in 0..<5 {
            manager.registerUndo(StrokeAction(
                label: "Action \(i)", strokeID: UUID(), pageID: UUID(), undo: {}, redo: {}
            ))
        }

        XCTAssertEqual(manager.undoCount, 3) // Oldest 2 evicted
    }

    func testUndoLabel() {
        let manager = UndoManager()
        manager.registerUndo(StrokeAction(
            label: "Draw Stroke", strokeID: UUID(), pageID: UUID(), undo: {}, redo: {}
        ))

        XCTAssertEqual(manager.undoLabel, "Draw Stroke")
    }

    func testRemoveAll() {
        let manager = UndoManager()
        manager.registerUndo(StrokeAction(
            label: "A", strokeID: UUID(), pageID: UUID(), undo: {}, redo: {}
        ))

        manager.removeAll()
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    func testCanUndoWithoutRedo() {
        let manager = UndoManager()
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }
}

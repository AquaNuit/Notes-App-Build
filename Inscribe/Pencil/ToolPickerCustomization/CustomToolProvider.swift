import PencilKit
import UIKit

// MARK: - CustomToolProvider

/// Provides custom drawing tools to the system PKToolPicker.
///
/// iOS 18+ allows registering custom tools with PKToolPicker, integrating
/// Inscribe's advanced brush types into the standard system tool palette.
/// This class manages that registration and maps between PKToolPicker tools
/// and Inscribe's ToolType.
@available(iOS 18.0, *)
public class CustomToolProvider: NSObject {

    // MARK: - Tool Mapping

    /// Map from Inscribe tool type to a custom PKToolPicker tool identifier.
    private static let toolIdentifierMap: [ToolType: String] = [
        .fountainPen: "com.inscribe.tool.fountainPen",
        .pencil: "com.inscribe.tool.pencil",
        .marker: "com.inscribe.tool.marker",
        .highlighter: "com.inscribe.tool.highlighter",
        .brush: "com.inscribe.tool.brush",
        .calligraphy: "com.inscribe.tool.calligraphy",
    ]

    /// Get the custom tool identifier for an Inscribe tool type.
    public static func identifier(for toolType: ToolType) -> String? {
        toolIdentifierMap[toolType]
    }

    /// Get the Inscribe tool type for a custom tool identifier.
    public static func toolType(for identifier: String) -> ToolType? {
        toolIdentifierMap.first(where: { $0.value == identifier })?.key
    }

    // MARK: - Tool Registration

    /// Register custom tools with a PKToolPicker instance.
    /// - Parameter toolPicker: The tool picker to register with
    public static func registerCustomTools(with toolPicker: PKToolPicker) {
        guard #available(iOS 18.0, *) else { return }

        var customTools: [PKTool] = []

        // Fountain Pen
        let fountainPenTool = createCustomTool(
            identifier: toolIdentifierMap[.fountainPen]!,
            name: "Fountain Pen",
            imageName: "pencil.tip"
        )
        customTools.append(fountainPenTool)

        // Pencil
        let pencilTool = createCustomTool(
            identifier: toolIdentifierMap[.pencil]!,
            name: "Pencil",
            imageName: "pencil"
        )
        customTools.append(pencilTool)

        // Marker
        let markerTool = createCustomTool(
            identifier: toolIdentifierMap[.marker]!,
            name: "Marker",
            imageName: "paintbrush.pointed"
        )
        customTools.append(markerTool)

        // Highlighter
        let highlighterTool = createCustomTool(
            identifier: toolIdentifierMap[.highlighter]!,
            name: "Highlighter",
            imageName: "highlighter"
        )
        customTools.append(highlighterTool)

        // Brush
        let brushTool = createCustomTool(
            identifier: toolIdentifierMap[.brush]!,
            name: "Brush",
            imageName: "paintbrush"
        )
        customTools.append(brushTool)

        // Calligraphy
        let calligraphyTool = createCustomTool(
            identifier: toolIdentifierMap[.calligraphy]!,
            name: "Calligraphy",
            imageName: "pen.tip"
        )
        customTools.append(calligraphyTool)

        // Register all custom tools
        toolPicker.addCustomTools(customTools)
    }

    @available(iOS 18.0, *)
    private static func createCustomTool(
        identifier: String,
        name: String,
        imageName: String
    ) -> PKTool {
        let configuration = PKToolConfiguration(customIdentifier: identifier)
        return PKTool(configuration: configuration)
    }
}

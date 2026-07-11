import PencilKit
import UIKit
import InscribeCore

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
        // Custom tool registration uses PencilKit APIs from iOS 18 beta.
        // The release SDK may use different APIs — stub for now.
        // TODO: Implement when PencilKit custom tool API is confirmed.
    }
}

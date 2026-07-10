import SwiftUI

// MARK: - FloatingToolPalette

/// A floating, compact tool palette that appears on the canvas.
///
/// Allows quick switching between drawing tools, with expandable
/// options for color and width selection.
public struct FloatingToolPalette: View {

    @Environment(AppState.self) private var appState

    @State private var isExpanded: Bool = false
    @State private var showColorPicker: Bool = false

    private let tools: [ToolType] = [
        .fountainPen, .pencil, .marker, .highlighter, .brush, .calligraphy
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                // Tool buttons
                ForEach(tools, id: \.self) { tool in
                    toolButton(for: tool)
                }

                Divider()
                    .frame(width: 24)

                // Color and width
                Button(action: { showColorPicker.toggle() }) {
                    Circle()
                        .fill(Color(
                            red: appState.activeColor.red,
                            green: appState.activeColor.green,
                            blue: appState.activeColor.blue
                        ))
                        .frame(width: 20, height: 20)
                }

                // Width indicator
                WidthIndicator(width: appState.strokeWidth)
            }

            // Toggle button
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .popover(isPresented: $showColorPicker) {
            ColorPickerPopover(color: Binding(
                get: { Color(
                    red: appState.activeColor.red,
                    green: appState.activeColor.green,
                    blue: appState.activeColor.blue
                )},
                set: { newColor in
                    // Convert SwiftUI Color to PlatformColor
                    let resolved = newColor.resolve(in: EnvironmentValues())
                    appState.activeColor = PlatformColor(
                        red: CGFloat(resolved.red),
                        green: CGFloat(resolved.green),
                        blue: CGFloat(resolved.blue),
                        alpha: CGFloat(resolved.opacity)
                    )
                }
            ))
            .padding()
            .frame(width: 300, height: 400)
        }
    }

    @ViewBuilder
    private func toolButton(for tool: ToolType) -> some View {
        Button(action: {
            appState.activeTool = tool
            HapticManager.shared.toolChanged()
        }) {
            Image(systemName: tool.iconName)
                .font(.body)
                .foregroundStyle(appState.activeTool == tool ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    appState.activeTool == tool ?
                    Circle().fill(.tint.opacity(0.2)) :
                    nil
                )
        }
    }
}

// MARK: - WidthIndicator

struct WidthIndicator: View {
    let width: CGFloat

    var body: some View {
        Circle()
            .fill(.secondary)
            .frame(width: width + 8, height: width + 8)
            .frame(width: 24, height: 24)
    }
}

// MARK: - ColorPickerPopover

struct ColorPickerPopover: View {
    @Binding var color: Color

    private let presetColors: [Color] = [
        .black, .white, .red, .orange, .yellow, .green, .cyan,
        .blue, .purple, .pink, .brown, .gray
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Color")
                .font(.headline)

            ColorPicker("Pick a color", selection: $color)
                .labelsHidden()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(presetColors, id: \.self) { presetColor in
                    Circle()
                        .fill(presetColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(color == presetColor ? Color.primary : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            color = presetColor
                        }
                }
            }
        }
    }
}

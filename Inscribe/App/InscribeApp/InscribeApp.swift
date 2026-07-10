import SwiftUI

// MARK: - InscribeApp

/// The main entry point for the Inscribe application.
///
/// InscribeApp sets up the SwiftUI app lifecycle with:
/// - Window group for iPad scenes
/// - App state via dependency injection
/// - Root navigation via AppCoordinator
/// - Support for Stage Manager, Split View, and Slide Over
@available(iOS 17.0, *)
@main
public struct InscribeApp: App {

    @State private var appState = AppState()
    @State private var coordinator = AppCoordinator()

    public init() {
        // Configure appearance
        configureAppearance()
    }

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(coordinator)
                .onAppear {
                    coordinator.appState = appState
                }
        }
        #if os(iOS)
        .defaultSize(CGSize(width: 1024, height: 768))
        #endif
    }

    private func configureAppearance() {
        // Set up default appearance values
        UINavigationBar.appearance().prefersLargeTitles = false
    }
}

// MARK: - ContentView

/// The root content view that manages navigation.
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        switch coordinator.currentRoute {
        case .notebookList:
            NotebookListView()
        case .canvas(let notebookID, let pageID):
            CanvasSessionView(notebookID: notebookID, pageID: pageID)
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - AppState

/// Global application state shared via SwiftUI Environment.
@available(iOS 17.0, *)
@Observable
public final class AppState {
    public var currentNotebookID: UUID?
    public var currentPageID: UUID?
    public var activeTool: ToolType = .fountainPen
    public var activeColorHex: String = "#000000"
    public var activeColor: PlatformColor = .black
    public var strokeWidth: CGFloat = 2.0
    public var isSidebarVisible: Bool = true
    public var isToolPaletteVisible: Bool = true
    public var darkModeEnabled: Bool = false

    public init() {}
}

// MARK: - AppCoordinator

/// Handles navigation and routing for the application.
@available(iOS 17.0, *)
@Observable
public final class AppCoordinator {
    public var currentRoute: Route = .notebookList
    public weak var appState: AppState?

    public enum Route: Equatable {
        case notebookList
        case canvas(notebookID: UUID, pageID: UUID)
        case settings
    }

    public init() {}

    public func navigateToCanvas(notebookID: UUID, pageID: UUID) {
        appState?.currentNotebookID = notebookID
        appState?.currentPageID = pageID
        currentRoute = .canvas(notebookID: notebookID, pageID: pageID)
    }

    public func navigateToNotebookList() {
        appState?.currentNotebookID = nil
        appState?.currentPageID = nil
        currentRoute = .notebookList
    }

    public func navigateToSettings() {
        currentRoute = .settings
    }
}

// MARK: - Preview Stubs

struct NotebookListView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            List {
                Text("Inscribe Notebooks")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Notebooks")
        }
    }
}

struct CanvasSessionView: View {
    let notebookID: UUID
    let pageID: UUID

    @State private var canvasViewModel = CanvasViewModel()

    var body: some View {
        InfiniteCanvasView(viewModel: $canvasViewModel)
            .ignoresSafeArea()
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Text("Settings")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
        }
    }
}

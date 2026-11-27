import AppKit
import SwiftUI

@MainActor
final class EnginePreferences: ObservableObject {
    @Published var useBundled: Bool {
        didSet { defaults.set(useBundled, forKey: "useBundledWine") }
    }
    @Published var external: String {
        didSet { defaults.set(external, forKey: "wine") }
    }
    @Published var finishedSetup: Bool {
        didSet { defaults.set(finishedSetup, forKey: "didFinishEngineSetup") }
    }
    private let defaults = UserDefaults.standard

    init() {
        let previous = UserDefaults.standard.string(forKey: "wine") ?? ""
        external = previous
        useBundled = UserDefaults.standard.object(forKey: "useBundledWine") as? Bool ?? previous.isEmpty
        finishedSetup = UserDefaults.standard.bool(forKey: "didFinishEngineSetup")
        if bundledWine == nil { useBundled = false }
    }

    var engine: String? {
        useBundled ? bundledWine : Self.resolveWine(external)
    }

    static func resolveWine(_ path: String) -> String? {
        let expanded = NSString(string: path).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return nil }
        let file = URL(fileURLWithPath: expanded)
        let choices = file.pathExtension.lowercased() == "app" ? [
            file.appendingPathComponent("Contents/Resources/wine/bin/wine"),
            file.appendingPathComponent("Contents/Resources/bin/wine"),
            file.appendingPathComponent("Contents/MacOS/wine")
        ] : [file]
        return choices.lazy.map { $0.resolvingSymlinksInPath() }.first {
            FileManager.default.isExecutableFile(atPath: $0.path) &&
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }?.path
    }
}

struct EngineSettingsView: View {
    @ObservedObject var preferences: EnginePreferences
    var onboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if onboarding {
                Label("Set up WinBridge", systemImage: "square.on.square")
                    .font(.largeTitle.bold())
                Text("Choose the default Wine engine for Windows apps and Steam.")
                    .foregroundStyle(.secondary)
            }
            Picker("Default Wine engine", selection: $preferences.useBundled) {
                if bundledWine != nil { Text("Built-in Wine 11.0").tag(true) }
                Text("External Wine").tag(false)
            }
            if preferences.useBundled {
                Text("The built-in engine uses Rosetta on Apple Silicon.")
            } else {
                PathField(label: "Wine executable or Wine.app", value: $preferences.external, allowBundle: true)
                if !preferences.external.isEmpty && preferences.engine == nil {
                    Text("Choose an existing Wine launcher or a Wine app with a supported layout.")
                        .foregroundStyle(.secondary)
                }
            }
            if onboarding {
                HStack {
                    Spacer()
                    Button("Continue") { preferences.finishedSetup = true }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(preferences.engine == nil)
                }
            } else {
                Text("A Windows app profile can override this default. Changes apply on the next launch.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: 600, alignment: .leading)
    }
}

struct PathField: View {
    let label: String
    @Binding var value: String
    var directory = false
    var allowBundle = false

    var body: some View {
        HStack {
            TextField(label, text: $value).textFieldStyle(.roundedBorder)
            Button("Choose…") {
                let panel = NSOpenPanel()
                panel.title = label
                panel.canChooseFiles = !directory
                panel.canChooseDirectories = directory
                panel.canCreateDirectories = directory
                panel.treatsFilePackagesAsDirectories = !directory && !allowBundle
                if panel.runModal() == .OK, let url = panel.url { value = url.path }
            }
            .accessibilityLabel("Choose \(label)")
        }
    }
}

@MainActor
final class FinderFiles: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var pending: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        pending += urls
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func take() -> [URL] {
        let urls = pending
        pending.removeAll()
        return urls
    }
}

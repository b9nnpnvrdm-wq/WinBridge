import AppKit
import Sparkle
import SwiftUI
import WinBridgeCore

@main
@MainActor
struct WinBridgeApp: App {
    private let updates = AppUpdates()

    var body: some Scene {
        WindowGroup("WinBridge") {
            SetupView()
                .frame(minWidth: 640, idealWidth: 720, minHeight: 540, idealHeight: 760)
                .task { updates.start() }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                if let controller = updates.controller {
                    Button("Check for Updates…") { controller.checkForUpdates(nil) }
                } else {
                    Link("View WinBridge Releases…", destination: AppUpdates.releases)
                }
            }
        }
    }
}

@MainActor
private final class AppUpdates {
    static let releases = URL(string: "https://github.com/b9nnpnvrdm-wq/WinBridge/releases")!
    let controller: SPUStandardUpdaterController?
    private var started = false

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        if let key = info["SUPublicEDKey"] as? String,
           Data(base64Encoded: key)?.count == 32,
           let feed = info["SUFeedURL"] as? String,
           let url = URL(string: feed), url.scheme == "https", url.host != nil {
            controller = SPUStandardUpdaterController(
                startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
            )
        } else {
            controller = nil
        }
    }

    func start() {
        guard !started, let controller else { return }
        started = true
        controller.startUpdater()
        if controller.updater.automaticallyChecksForUpdates {
            controller.updater.checkForUpdatesInBackground()
        }
    }
}

private struct SetupView: View {
    @AppStorage("wine") private var wine = ""
    @AppStorage("useBundledWine") private var useBundledWine =
        UserDefaults.standard.string(forKey: "wine")?.isEmpty ?? true
    @AppStorage("prefix") private var prefix = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WinBridge/Steam").path
    @AppStorage("steamClient") private var steamClient = ""
    @AppStorage("steamAppID") private var appID = ""
    @AppStorage("metalHUD") private var metalHUD = false
    @State private var installer = ""
    @StateObject private var launcher = Launcher()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WinBridge").font(.largeTitle.bold())
                        Text("Windows Steam setup").foregroundStyle(.secondary)
                    }
                }
                step("Choose a Wine engine", icon: "gearshape.2") {
                    if bundledWine != nil {
                        Toggle("Use built-in Wine 11.0", isOn: $useBundledWine)
                        if useBundledWine {
                            Text("The built-in engine requires Rosetta. Steam and game compatibility with this baseline engine is still being tested.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    if !useBundledWine || bundledWine == nil {
                        Text("Choose the launcher file from a trusted Wine build for macOS.")
                        pathField("Wine executable", value: $wine)
                    }
                    pathField("Steam environment", value: $prefix, directory: true)
                    Text("The default environment is created when you run Steam Setup.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                step("Install Windows Steam", icon: "arrow.down.circle") {
                    Text("Download the Windows installer, select SteamSetup.exe, then run it. When Steam opens, sign in and install your game.")
                    Link("Get Windows Steam", destination: URL(string: "https://store.steampowered.com/about/")!)
                    pathField("SteamSetup.exe", value: $installer)
                    Button("Run Steam Setup") {
                        start(installer, installing: true)
                    }.disabled(launcher.running || installer.isEmpty)
                }
                step("Open Steam or launch a game", icon: "play.circle") {
                    Text("Select the installed Steam.exe in this environment. Leave the App ID blank to open Steam.")
                    pathField("Steam.exe", value: $steamClient)
                    TextField("Steam App ID", text: $appID, prompt: Text("Optional, e.g. 271590"))
                        .textFieldStyle(.roundedBorder)
                    Toggle("Show Metal Performance HUD", isOn: $metalHUD)
                    HStack {
                        Button(appID.isEmpty ? "Open Steam" : "Launch Game") { start(steamClient) }
                            .buttonStyle(.borderedProminent)
                            .disabled(launcher.running || (steamClient.isEmpty && suggestedClient == nil))
                        if let log = launcher.log {
                            Button("Open Log") { NSWorkspace.shared.open(log) }
                        }
                    }
                    Text("GTA V Legacy Story Mode is a test target. Gameplay through WinBridge is still unverified.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                if launcher.running { ProgressView().controlSize(.small) }
                Text(launcher.status).font(.callout).textSelection(.enabled)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.regularMaterial)
        }
        .onChange(of: prefix) { _, _ in steamClient = "" }
    }

    private var bundledWine: String? {
        guard let url = Bundle.main.sharedSupportURL?
            .appendingPathComponent("Wine/bin/wine"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url.path
    }

    private var suggestedClient: String? {
        let base = URL(fileURLWithPath: NSString(string: prefix).expandingTildeInPath)
            .appendingPathComponent("drive_c")
        for folder in ["Program Files (x86)", "Program Files"] {
            let path = base.appendingPathComponent(folder)
                .appendingPathComponent("Steam/Steam.exe").path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    private func start(_ executable: String, installing: Bool = false) {
        let program = executable.isEmpty ? (suggestedClient ?? "") : executable
        if !installing && steamClient.isEmpty { steamClient = program }
        launcher.start(
            wine: (useBundledWine ? bundledWine : nil) ?? wine,
            prefix: prefix, executable: program, installing: installing,
            appID: appID, metalHUD: !installing && metalHUD
        )
    }

    private func step<Content: View>(
        _ title: String, icon: String, @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        } label: {
            Label(title, systemImage: icon).font(.headline)
        }
    }

    private func pathField(_ label: String, value: Binding<String>, directory: Bool = false) -> some View {
        HStack {
            TextField(label, text: value).textFieldStyle(.roundedBorder)
            Button("Choose…") {
                let panel = NSOpenPanel()
                panel.title = label
                panel.canChooseFiles = !directory
                panel.canChooseDirectories = directory
                panel.canCreateDirectories = directory
                panel.treatsFilePackagesAsDirectories = !directory
                if panel.runModal() == .OK, let url = panel.url {
                    value.wrappedValue = url.path
                }
            }.accessibilityLabel("Choose \(label)")
        }
    }
}

@MainActor
private final class Launcher: ObservableObject {
    @Published private(set) var status = "Choose a Windows Steam installer to begin."
    @Published private(set) var running = false
    @Published private(set) var log: URL?
    private var process: Process?

    func start(
        wine: String, prefix: String, executable: String,
        installing: Bool, appID: String, metalHUD: Bool
    ) {
        guard !running else { return }
        do {
            let command = try SteamCommand.make(
                wine: wine, prefix: prefix, windowsExecutable: executable,
                installing: installing, appID: appID, metalHUD: metalHUD
            )
            let files = FileManager.default
            let folder = try files.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            ).appendingPathComponent("WinBridge/Logs", isDirectory: true)
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("\(UUID().uuidString).log")
            try Data().write(to: url)
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }

            let child = Process()
            child.executableURL = command.executable
            child.currentDirectoryURL = command.directory
            child.arguments = command.arguments
            child.environment = command.environment
            child.standardOutput = handle
            child.standardError = handle
            child.terminationHandler = { [weak self] result in
                let code = result.terminationStatus
                let terminated = result.terminationReason == .uncaughtSignal
                Task { @MainActor in
                    guard let self else { return }
                    self.running = false
                    self.process = nil
                    if terminated {
                        self.status = "Wine stopped with signal \(code). Check the log."
                    } else if code != 0 {
                        self.status = "Wine exited with status \(code). Check the log."
                    } else if installing {
                        self.status = "Steam Setup exited. Open Steam to continue."
                    } else {
                        self.status = "Wine exited. Check Steam for the launch result."
                    }
                }
            }
            log = url
            try child.run()
            process = child
            running = true
            status = installing ? "Steam Setup is running…" : "Wine is running…"
        } catch {
            let failure = error as NSError
            if failure.domain == NSPOSIXErrorDomain && failure.code == 86 {
                status = "Wine could not run for this CPU. The built-in engine requires Rosetta."
            } else {
                status = error.localizedDescription
            }
        }
    }
}

import AppKit
import Sparkle
import SwiftUI
import WinBridgeCore

@main
@MainActor
struct WinBridgeApp: App {
    private let updates = AppUpdates()
    @StateObject private var launcher = Launcher()
    @StateObject private var preferences = EnginePreferences()
    @NSApplicationDelegateAdaptor(FinderFiles.self) private var finderFiles
    @State private var tab = "apps"

    var body: some Scene {
        Window("WinBridge", id: "main") {
            Group {
                if preferences.finishedSetup {
                    TabView(selection: $tab) {
                        ApplicationsView(launcher: launcher, preferences: preferences, finderFiles: finderFiles)
                            .tabItem { Label("Windows Apps", systemImage: "square.grid.2x2") }
                            .tag("apps")
                        SetupView(launcher: launcher, preferences: preferences)
                            .tabItem { Label("Steam", systemImage: "gamecontroller") }
                            .tag("steam")
                    }
                } else {
                    EngineSettingsView(preferences: preferences, onboarding: true)
                }
            }
            .onChange(of: finderFiles.pending) { _, files in
                if !files.isEmpty { tab = "apps" }
            }
            .safeAreaInset(edge: .bottom) { LauncherStatus(launcher: launcher) }
            .frame(minWidth: 660, idealWidth: 820, minHeight: 560, idealHeight: 760)
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
        Settings { EngineSettingsView(preferences: preferences).frame(width: 580) }
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
    @AppStorage("prefix") private var prefix = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WinBridge/Steam").path
    @AppStorage("steamClient") private var steamClient = ""
    @AppStorage("steamAppID") private var appID = ""
    @AppStorage("metalHUD") private var metalHUD = false
    @State private var installer = ""
    @ObservedObject var launcher: Launcher
    @ObservedObject var preferences: EnginePreferences
    @AppStorage("steamSoftwareRendering") private var steamSoftwareRendering = false

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
                step("Steam environment", icon: "gearshape.2") {
                    Text(preferences.useBundled ? "Using built-in Wine 11.0" : "Using external Wine")
                    SettingsLink { Text("Change Wine Engine…") }
                    PathField(label: "Steam environment", value: $prefix, directory: true)
                    Text("First launch can take longer while Wine creates this environment.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                step("Install Windows Steam", icon: "arrow.down.circle") {
                    Text("Download the Windows installer, select SteamSetup.exe, then run it. When Steam opens, sign in and install your game.")
                    Link("Get Windows Steam", destination: URL(string: "https://store.steampowered.com/about/")!)
                    PathField(label: "SteamSetup.exe", value: $installer)
                    Button("Run Steam Setup") {
                        start(installer, installing: true)
                    }.disabled(launcher.isRunning(prefix) || installer.isEmpty)
                }
                step("Open Steam or launch a game", icon: "play.circle") {
                    Text("Select the installed Steam.exe in this environment. Leave the App ID blank to open Steam.")
                    PathField(label: "Steam.exe", value: $steamClient)
                    TextField("Steam App ID", text: $appID, prompt: Text("Optional, e.g. 271590"))
                        .textFieldStyle(.roundedBorder)
                    Toggle("Show Metal Performance HUD", isOn: $metalHUD)
                    Toggle("Use software rendering for the Steam interface", isOn: $steamSoftwareRendering)
                    if let logs = steamLogs {
                        Button("Open Steam Logs") { NSWorkspace.shared.open(logs) }
                    }
                    Text("If Steam opens a blank window, quit Steam before retrying with software rendering.")
                        .font(.callout).foregroundStyle(.secondary)
                    if preferences.useBundled {
                        Text("This Wine build still lacks some TLS and media features. If Steam cannot update or sign in, try a compatible external Wine build in Settings.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(appID.isEmpty ? "Open Steam" : "Launch Game") { start(steamClient) }
                            .buttonStyle(.borderedProminent)
                            .disabled(launcher.isRunning(prefix) || resolvedSteam == nil)
                    }
                    Text("GTA V Legacy Story Mode is a test target. Gameplay through WinBridge is still unverified.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: prefix) { _, _ in steamClient = "" }
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

    private var resolvedSteam: String? {
        let entered = NSString(string: steamClient).expandingTildeInPath
        return !entered.isEmpty && FileManager.default.fileExists(atPath: entered) ? entered : suggestedClient
    }

    private var steamLogs: URL? {
        guard let resolvedSteam else { return nil }
        let folder = URL(fileURLWithPath: resolvedSteam).deletingLastPathComponent().appendingPathComponent("logs")
        return FileManager.default.fileExists(atPath: folder.path) ? folder : nil
    }

    private func start(_ executable: String, installing: Bool = false) {
        let program = installing ? executable : (resolvedSteam ?? "")
        if !installing { steamClient = program }
        launcher.start(
            runningMessage: installing ? "Steam Setup is running…" : "Wine is running…",
            completionMessage: installing ? "Steam Setup exited. Open Steam to continue." :
                "Wine exited. Check Steam for the launch result."
        ) {
            try SteamCommand.make(
                wine: preferences.engine ?? "",
                prefix: prefix, windowsExecutable: program, installing: installing,
                appID: appID, metalHUD: !installing && metalHUD,
                softwareRendering: !installing && steamSoftwareRendering
            )
        }
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


}

var bundledWine: String? {
    guard let url = Bundle.main.sharedSupportURL?.appendingPathComponent("Wine/bin/wine"),
          FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
    return url.path
}

struct LauncherStatus: View {
    @ObservedObject var launcher: Launcher

    var body: some View {
        HStack(spacing: 10) {
            if launcher.running { ProgressView().controlSize(.small) }
            Text(launcher.status).font(.callout).textSelection(.enabled)
            Spacer()
            if let log = launcher.log {
                Button("Open Log") { NSWorkspace.shared.open(log) }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

@MainActor
final class Launcher: ObservableObject {
    @Published private(set) var status = "Choose an application to begin."
    @Published private(set) var log: URL?
    @Published private var active: [String: Process] = [:]
    var running: Bool { !active.isEmpty }

    func isRunning(_ prefix: String) -> Bool { active[normalized(prefix)] != nil }

    private func normalized(_ path: String) -> String {
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
            .standardizedFileURL.resolvingSymlinksInPath().path
    }

    func report(_ error: Error) { status = error.localizedDescription }

    func start(
        runningMessage: String, completionMessage: String, command: () throws -> WineInvocation
    ) {
        do {
            let invocation = try command()
            let prefix = normalized(invocation.environment["WINEPREFIX"] ?? "")
            guard active[prefix] == nil else {
                status = "A Windows command is already running in this environment."
                return
            }
            let child = invocation.makeProcess()
            let startTime = ProcessInfo.processInfo.systemUptime
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

            child.standardOutput = handle
            child.standardError = handle
            child.terminationHandler = { [weak self] result in
                let code = result.terminationStatus
                let terminated = result.terminationReason == .uncaughtSignal
                Task { @MainActor in
                    guard let self else { return }
                    self.active.removeValue(forKey: prefix)
                    if terminated {
                        self.status = "Wine stopped with signal \(code). Check the log."
                    } else if code != 0 {
                        self.status = "Wine exited with status \(code). Check the log."
                    } else {
                        let seconds = ProcessInfo.processInfo.systemUptime - startTime
                        self.status = "\(completionMessage) Wine process time \(seconds.formatted(.number.precision(.fractionLength(1)))) s."
                    }
                }
            }
            log = url
            try child.run()
            active[prefix] = child
            status = runningMessage
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

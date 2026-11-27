import AppKit
import SwiftUI
import WinBridgeCore

struct ApplicationsView: View {
    @ObservedObject var launcher: Launcher
    @ObservedObject var preferences: EnginePreferences
    @ObservedObject var finderFiles: FinderFiles
    @State private var dropping = false
    @State private var profiles: [WindowsApplication] = []
    @State private var selected: UUID?
    @State private var ready = false

    private let library = ApplicationLibrary(directory: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WinBridge", isDirectory: true))

    var body: some View {
        HSplitView {
            VStack(spacing: 10) {
                List(selection: $selected) {
                    ForEach(profiles) { profile in
                        Label(profile.name, systemImage: "app.dashed").tag(profile.id)
                    }
                }
                Button { addApplication() } label: { Label("New Windows App", systemImage: "plus") }
                    .disabled(!ready)
                Text("Drop Windows EXEs here")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 14)
            }
            .frame(minWidth: 175, idealWidth: 205, maxWidth: 255)

            if let profile = profiles.first(where: { $0.id == selected }) {
                ApplicationEditor(profile: profile, launcher: launcher, preferences: preferences, save: save)
                    .id(profile.id)
                    .frame(minWidth: 430)
            } else {
                ContentUnavailableView(
                    "Windows Apps", systemImage: "square.grid.2x2",
                    description: Text("Create a profile to open a Windows EXE or install software from an EXE or MSI.")
                )
                .frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            register(urls, run: false)
        } isTargeted: { dropping = $0 }
        .onAppear {
            do {
                if !ready {
                    profiles = try library.load()
                    selected = profiles.first?.id
                    ready = true
                }
                openFinderFiles()
            } catch { launcher.report(error) }
        }
        .onChange(of: finderFiles.pending) { _, _ in openFinderFiles() }
    }

    private func openFinderFiles() {
        guard ready, !finderFiles.pending.isEmpty else { return }
        _ = register(finderFiles.take(), run: true)
    }

    private func register(_ urls: [URL], run: Bool) -> Bool {
        guard ready else { return false }
        var accepted = false
        for url in urls {
            do {
                let profile = try library.profile(forExecutable: url, in: profiles)
                if !profiles.contains(where: { $0.id == profile.id }) { try save(profile) }
                selected = profile.id
                accepted = true
                if run {
                    launcher.start(runningMessage: "Opening \(profile.name)…", completionMessage: "The Windows command exited.") {
                        try profile.command(.run, bundledWine: preferences.engine)
                    }
                }
            } catch { launcher.report(error) }
        }
        return accepted
    }

    private func addApplication() {
        do {
            let profile = try library.makeApplication()
            try save(profile)
            selected = profile.id
        } catch { launcher.report(error) }
    }

    private func save(_ profile: WindowsApplication) throws {
        var next = profiles
        if let index = next.firstIndex(where: { $0.id == profile.id }) {
            next[index] = profile
        } else {
            next.append(profile)
        }
        try library.save(next)
        profiles = next
    }
}

private struct ApplicationEditor: View {
    @State var profile: WindowsApplication
    @ObservedObject var launcher: Launcher
    @ObservedObject var preferences: EnginePreferences
    let save: (WindowsApplication) throws -> Void
    @State private var fileInfo: String?
    @State private var installerInfo: String?
    @State private var componentStatus: String?
    @State private var confirmingUninstall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Application Profile").font(.title2.bold())
                TextField("Application name", text: $profile.name)
                    .textFieldStyle(.roundedBorder)

                GroupBox("Run an executable") {
                    VStack(alignment: .leading, spacing: 10) {
                        PathField(label: "Windows EXE", value: $profile.executable)
                        if let fileInfo { Text(fileInfo).font(.callout).foregroundStyle(.secondary) }
                        Button("Run EXE") { run(.run) }
                            .buttonStyle(.borderedProminent)
                            .disabled(profile.executable.isEmpty)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Install or uninstall") {
                    VStack(alignment: .leading, spacing: 10) {
                        PathField(label: "EXE or MSI installer", value: $profile.installer)
                        if let installerInfo { Text(installerInfo).font(.callout).foregroundStyle(.secondary) }
                        HStack {
                            Button("Run Installer") { run(.install) }.disabled(profile.installer.isEmpty)
                            Button("Uninstall MSI…") { confirmingUninstall = true }
                                .disabled(!profile.isInitialized ||
                                          URL(fileURLWithPath: profile.installer).pathExtension.lowercased() != "msi")
                        }
                        Text("After installation, choose the installed EXE above. To run an EXE uninstaller, select it there.")
                            .font(.callout).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Compatibility and storage") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Each profile has its own Windows files and registry.")
                        PathField(label: "Environment storage folder", value: $profile.location, directory: true)
                            .disabled(profile.isInitialized)
                        PathField(label: "Override the default Wine executable", value: $profile.wine)
                        Toggle("Show Metal Performance HUD", isOn: $profile.metalHUD)
                        HStack {
                            Button("Initialize Environment") { run(.initialize) }.disabled(profile.isInitialized)
                            Button("Browse Windows Files") {
                                NSWorkspace.shared.open(profile.prefix.appendingPathComponent("drive_c"))
                            }.disabled(!profile.isInitialized)
                        }
                        Button("Import Compatibility DLL…", action: importComponent).disabled(!profile.isInitialized)
                        if let componentStatus { Text(componentStatus).font(.callout).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Save Profile") {
                    do { try save(profile) } catch { launcher.report(error) }
                }
            }
            .padding(24)
        }
        .disabled(launcher.isRunning(profile.prefix.path))
        .onAppear {
            fileInfo = inspect(profile.executable)
            installerInfo = inspect(profile.installer)
        }
        .onChange(of: profile.executable) { _, newValue in fileInfo = inspect(newValue) }
        .onChange(of: profile.installer) { _, newValue in installerInfo = inspect(newValue) }
        .confirmationDialog("Uninstall this MSI from the selected profile?", isPresented: $confirmingUninstall) {
            Button("Uninstall", role: .destructive) { run(.uninstall) }
        }
    }

    private func run(_ action: WindowsApplication.Action) {
        do { try save(profile) } catch { launcher.report(error); return }
        launcher.start(runningMessage: "Running the Windows command…", completionMessage: "The Windows command exited successfully.") {
            try profile.command(action, bundledWine: preferences.engine)
        }
    }

    private func importComponent() {
        let panel = NSOpenPanel()
        panel.title = "Select a trusted Windows DLL"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try WindowsComponents.importDLL(url, into: profile)
                componentStatus = "Imported \(url.lastPathComponent) for this profile."
            } catch { launcher.report(error) }
        }
    }

    private func inspect(_ path: String) -> String? {
        guard path.hasPrefix("/") else { return nil }
        do {
            return try WindowsFile.inspect(URL(fileURLWithPath: path)).description
        } catch {
            return error.localizedDescription
        }
    }

}

import AppKit
import SwiftUI
import WinBridgeCore

struct ApplicationsView: View {
    @ObservedObject var launcher: Launcher
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
                    .disabled(!ready || launcher.running)
                    .padding(.bottom, 14)
            }
            .frame(minWidth: 175, idealWidth: 205, maxWidth: 255)

            if let profile = profiles.first(where: { $0.id == selected }) {
                ApplicationEditor(profile: profile, launcher: launcher, save: save)
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
        .onAppear {
            guard !ready else { return }
            do {
                profiles = try library.load()
                selected = profiles.first?.id
                ready = true
            } catch {
                launcher.report(error)
            }
        }
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
                        fileField("Windows EXE", value: $profile.executable)
                        if let fileInfo { Text(fileInfo).font(.callout).foregroundStyle(.secondary) }
                        Button("Run EXE") { run(.run) }
                            .buttonStyle(.borderedProminent)
                            .disabled(profile.executable.isEmpty)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Install or uninstall") {
                    VStack(alignment: .leading, spacing: 10) {
                        fileField("EXE or MSI installer", value: $profile.installer)
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
                        fileField("Environment storage folder", value: $profile.location, directory: true)
                            .disabled(profile.isInitialized)
                        fileField("Wine executable (optional)", value: $profile.wine)
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
        .disabled(launcher.running)
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
            try profile.command(action, bundledWine: bundledWine)
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

    private func fileField(_ label: String, value: Binding<String>, directory: Bool = false) -> some View {
        HStack {
            TextField(label, text: value).textFieldStyle(.roundedBorder)
            Button("Choose…") {
                let panel = NSOpenPanel()
                panel.title = label
                panel.canChooseFiles = !directory
                panel.canChooseDirectories = directory
                panel.canCreateDirectories = directory
                panel.treatsFilePackagesAsDirectories = !directory
                if panel.runModal() == .OK, let url = panel.url { value.wrappedValue = url.path }
            }
            .accessibilityLabel("Choose \(label)")
        }
    }
}

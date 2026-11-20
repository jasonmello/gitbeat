import AppKit
import SwiftUI
import GitBeatCore

@main
struct GitBeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ViewState private var model = AppModel()
    private let prefs = Preferences.shared

    var body: some Scene {
        Window(Brand.name, id: "main") {
            RootView()
                .environment(model)
                .preferredColorScheme(prefs.mode.colorScheme)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1140, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(T("About GitBeat", "Sobre o GitBeat")) { AppDelegate.showAboutPanel() }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(model)
                .preferredColorScheme(prefs.mode.colorScheme)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.streakAtRisk ? "flame.fill" : "waveform.path.ecg")
                Text(Fmt.tokens(model.tokens(on: model.todayKey).total))
            }
            .help(model.streakAtRisk ? T("Your streak ends today", "Sua sequência termina hoje") : Brand.name)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(prefs.mode.colorScheme)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-icon"), i + 1 < args.count {
            Task { @MainActor in Snapshot.renderIcon(to: URL(fileURLWithPath: args[i + 1])) }
            return
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Task { @MainActor in await Snapshot.run(to: URL(fileURLWithPath: args[i + 1])) }
            return
        }
        if args.contains("--integration-status") { // para conferir pelo terminal
            Task { @MainActor in
                print("request: \(await Notifier.shared.requestPermissionResult())")
                let auth = await Notifier.shared.authorizationStatus()
                print("login item: \(LoginItem.status)")
                print("notifications: \(auth.map { String(describing: $0.rawValue) } ?? "unavailable") (0 não decidido, 1 negado, 2 permitido, 3 provisório)")
                exit(0)
            }
            return
        }
        LoginItem.enableOnFirstLaunch()
        Task { @MainActor in Notifier.shared.start() }
        // Rodando por `swift run` não há Info.plist; isto garante ícone no Dock e janela na frente.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Fechar a janela não fecha o app: ele continua na barra de menu.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @MainActor static func showAboutPanel() {
        let credits = NSAttributedString(
            string: T("Proudly developed by Jason Mello", "Orgulhosamente desenvolvido por Jason Mello"),
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .applicationName: Brand.name])
        NSApp.activate()
    }
}

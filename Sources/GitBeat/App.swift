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
            MenuBarLabel(model: model, mascot: model.menuMascot)
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
        let base: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11),
                                                   .foregroundColor: NSColor.secondaryLabelColor]
        let credits = NSMutableAttributedString(
            string: T("Proudly developed by ", "Orgulhosamente desenvolvido por "), attributes: base)
        // O nome é um link para o GitHub do autor.
        credits.append(NSAttributedString(string: Brand.author, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .link: Brand.authorURL,
        ]))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .applicationName: Brand.name])
        NSApp.activate()
    }
}

/// O ícone da barra de menu numa view própria: cada troca de quadro do mascote redesenha só
/// isto, não o corpo do app inteiro (janela, barra e ajustes).
struct MenuBarLabel: View {
    let model: AppModel
    let mascot: MenuBarMascot

    var body: some View {
        HStack(spacing: 4) {
            if model.streakAtRisk {
                Image(systemName: "flame.fill")
            } else {
                MascotFrame(mascot: mascot)
            }
            Text(Fmt.tokens(model.tokens(on: model.todayKey).total))
        }
        .help(model.streakAtRisk ? T("Your streak ends today", "Sua sequência termina hoje") : Brand.name)
    }
}

/// Só a imagem do mascote: é a única coisa que muda a cada quadro.
private struct MascotFrame: View {
    let mascot: MenuBarMascot

    var body: some View {
        Image(nsImage: mascot.image)
            .accessibilityLabel("GitBeat, " + mascot.description)
    }
}

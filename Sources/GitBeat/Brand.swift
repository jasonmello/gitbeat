import AppKit
import SwiftUI

/// Marca do GitBeat: o mascote. Os originais estão em `brand/mascot/`; o app usa as cópias
/// de `Resources/` (copiadas para dentro do `.app` por scripts/build-app.sh).
enum Brand {
    /// Cores do kit do mascote: placa roxa do ícone, sola limão, rosto ameixa.
    static let violet = Color(red: 0.463, green: 0.204, blue: 1.0)      // #7634FF
    static let violetDeep = Color(red: 0.220, green: 0.063, blue: 0.804) // #3810CD
    static let lime = Color(red: 0.796, green: 0.973, blue: 0.353)      // #CBF85A
    static let plum = Color(red: 0.259, green: 0.090, blue: 0.373)      // #42175F
    /// Destaque da marca em texto e ícones pequenos: roxo no claro, limão no escuro (os dois com contraste).
    static let accent = Adaptive(light: Color(red: 0.349, green: 0.125, blue: 0.961), dark: lime)  // #5920F5 / #CBF85A
    static let name = "GitBeat"
    static let author = "Jason Mello"
    /// Todo crédito ao autor leva para o GitHub dele.
    static let authorURL = URL(string: "https://github.com/jasonmello")!

    /// Logo com nome ameixa, para fundo claro; e com nome branco, para fundo escuro.
    static let logoLight = resourceImage("logo-on-light.svg") ?? NSImage()
    static let logoDark = resourceImage("logo-on-dark.svg") ?? NSImage()

    /// O mascote parado em silhueta, versão "template": o macOS pinta na cor do texto do menu.
    /// (O animado fica em `MenuBarMascot`; este é o reserva.)
    static let menuBarIcon: NSImage = {
        let img = resourceImage("MenuBar/idle/000@2x.png") ?? NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: name) ?? NSImage()
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = true
        return img
    }()

    // MARK: arquivos

    /// Pasta dos recursos: `Contents/Resources` no `.app`; `Resources/` do repositório quando
    /// roda direto do `.build` (`swift run`, `--snapshot`).
    static let resourcesDir: URL? = {
        if let url = Bundle.main.resourceURL, FileManager.default.fileExists(atPath: url.appendingPathComponent("Mascot").path) {
            return url
        }
        let repo = URL(fileURLWithPath: #filePath)   // Sources/GitBeat/Brand.swift
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources")
        return FileManager.default.fileExists(atPath: repo.path) ? repo : nil
    }()

    static func resourceURL(_ name: String) -> URL? {
        guard let url = resourcesDir?.appendingPathComponent(name),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func resourceImage(_ name: String) -> NSImage? {
        resourceURL(name).flatMap(NSImage.init(contentsOf:))
    }
}

/// Logo completo (mascote + nome), trocando a cor do nome no tema escuro.
struct BrandLogo: View {
    var height: CGFloat = 24
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Image(nsImage: scheme == .dark ? Brand.logoDark : Brand.logoLight)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel(Brand.name)
    }
}

import AppKit
import SwiftUI
import GitBeatCore

/// Modos de linha de comando para conferir a interface sem gravar a tela:
/// - `GitBeat --snapshot <pasta>`: cada tela em PNG, claro e escuro, inglês e português.
@MainActor
enum Snapshot {
    static func run(to dir: URL) async {
        let model = AppModel(autoRefresh: false)
        await model.refresh()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let prefs = Preferences.shared
        let original = (prefs.language, prefs.style)

        for lang in AppLanguage.allCases {
            prefs.language = lang
            for style in VisualStyle.allCases {
                prefs.style = style
                for scheme in [ColorScheme.light, .dark] {
                    let tag = "\(lang.rawValue)-\(style.rawValue)-\(scheme == .light ? "light" : "dark")"
                    for section in Section.allCases where lang == .en || [.summary, .about].contains(section) {
                        render(page(section), model: model, scheme: scheme, width: 1000,
                               to: dir.appendingPathComponent("\(section.rawValue)-\(tag).png"))
                    }
                }
            }
        }
        prefs.style = .glass
        render(LoadingPage(), model: model, scheme: .light, width: 1000, to: dir.appendingPathComponent("loading.png"))
        render(MenuBarView(), model: model, scheme: .dark, width: 300, to: dir.appendingPathComponent("menu.png"))
        (prefs.language, prefs.style) = original
        print("Snapshots in \(dir.path)")
        exit(0)
    }

    @ViewBuilder
    private static func page(_ section: Section) -> some View {
        switch section {
        case .summary: SummaryView(selection: .constant(.summary))
        case .tokens: TokensView()
        case .github: GitHubView()
        case .time: TimeView()
        case .goals: GoalsView()
        case .about: AboutDataView()
        }
    }

    private static func framed(_ view: some View, model: AppModel, scheme: ColorScheme, width: CGFloat) -> some View {
        view
            .foregroundStyle(Theme.ink)   // como nas cenas do app
            .tint(Brand.violet)
            .environment(model)
            .padding(24)
            .frame(width: width)
            .background(AppBackground())
            .environment(\.colorScheme, scheme)
    }

    // O ImageRenderer desenha o Liquid Glass (macOS 26+). Controles nativos (botões, seletores,
    // links) saem como faixas amarelas: limitação do renderizador, na janela real aparecem normais.

    private static func render(_ view: some View, model: AppModel, scheme: ColorScheme, width: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: framed(view, model: model, scheme: scheme, width: width))
        renderer.scale = 2
        write(renderer.nsImage, to: url)
    }

    private static func write(_ image: NSImage?, to url: URL) {
        guard let image, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            print("failed: \(url.lastPathComponent)")
            return
        }
        try? png.write(to: url)
    }
}

import SwiftUI
import GitBeatCore

/// Tokens visuais do app. Ver DESIGN.md. Componentes nunca usam cor, raio, sombra ou duração soltos.
enum Theme {
    // MARK: cores dos assuntos (cores de dado, uma por assunto, usadas também nos anéis)
    static let tokens = Color.pink
    static let time = Color.teal
    /// Verde dos commits (era o verde da marca antiga; ficou como cor de dado).
    static let github = Color(red: 0, green: 0.788, blue: 0.584)   // #00C995
    static let cost = Color.purple
    static let streak = Color.orange

    // MARK: neutros quentes (matiz levemente amarelado, nunca preto ou branco puros)
    /// Fundo da página, atrás dos cartões.
    static let page = Adaptive(light: Color(red: 0.953, green: 0.953, blue: 0.945),   // #f3f3f1
                               dark: Color(red: 0.043, green: 0.043, blue: 0.047))    // #0b0b0c
    /// Cartões (sempre sólidos: o conteúdo não fica em vidro), um degrau acima da página.
    static let raised = Adaptive(light: Color(red: 0.996, green: 0.996, blue: 0.992),  // #fefefd
                                 dark: Color(red: 0.110, green: 0.110, blue: 0.118))   // #1c1c1e
    /// Trilhas, barras vazias, quadradinhos sem commit.
    static let well = Adaptive(light: Color(red: 0.2, green: 0.17, blue: 0.1).opacity(0.08),
                               dark: Color.white.opacity(0.09))
    /// Borda como anel fino, com alfa sobre o fundo.
    static let hairline = Adaptive(light: Color(red: 0.2, green: 0.17, blue: 0.1).opacity(0.08),
                                   dark: Color.white.opacity(0.08))

    // MARK: raio por papel
    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 18
        static let panel: CGFloat = 22
        /// Elemento dentro de um cartão: raio concêntrico (externo − espaço até a borda).
        static func inner(padding: CGFloat) -> CGFloat { max(card - padding, 4) }
    }

    static let cardPadding: CGFloat = 16
    static let gap: CGFloat = 16
}

/// Uma cor para o claro e outra para o escuro, resolvida pelo ambiente do SwiftUI
/// (funciona também no `ImageRenderer` do modo --snapshot, que não segue a aparência do sistema).
struct Adaptive: ShapeStyle {
    var light: Color
    var dark: Color

    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? dark : light
    }
}

// MARK: movimento

/// Uma curva para quase tudo (ease-out "quint"), saída mais rápida, durações curtas e nomeadas.
enum Motion {
    static func standard(_ duration: Double) -> Animation { .timingCurve(0.22, 1, 0.36, 1, duration: duration) }
    static let instant = standard(0.12)
    static let fast = standard(0.16)
    static let regular = standard(0.24)
    /// Para o que tem significado e merece ser visto: anel fechando.
    static let considered = standard(0.48)
    static let exit = Animation.timingCurve(0.7, 0, 0.84, 0, duration: 0.12)
    static let pressScale: CGFloat = 0.98
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var animation: Animation
    var value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Igual a `.animation(_:value:)`, mas desliga quando "Reduzir movimento" está ativo no macOS.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

// MARK: fundo da janela

/// Fundo da página: neutro, sem manchas coloridas. Cor atrás do texto tira contraste;
/// a cor fica nos dados (anéis, barras, títulos dos cartões).
struct AppBackground: View {
    var body: some View {
        Rectangle().fill(Theme.page).ignoresSafeArea()
    }
}

// MARK: superfícies

/// Fundo de cartão: sempre sólido. Segue a regra do Liquid Glass de deixar o vidro para a
/// camada que flutua sobre o conteúdo (barra lateral, barra de ferramentas, dicas, painéis);
/// texto em cima de vidro perde contraste conforme o que está atrás.
/// Degrau de superfície, anel fino, luz de 1px no topo e sombra em camadas de alfa baixo.
private struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat
    var elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return classic(content, shape: shape)
    }

    private func classic(_ content: Content, shape: RoundedRectangle) -> some View {
        let dark = scheme == .dark
        // A sombra fica só no fundo: aplicada ao conteúdo, ela vazaria para cada texto do cartão.
        return content
            .background(
                shape.fill(Theme.raised)
                    .shadow(color: .black.opacity(dark ? 0.30 : 0.035), radius: 1, y: 1)           // contato
                    .shadow(color: .black.opacity(dark ? (elevated ? 0.50 : 0.25) : (elevated ? 0.09 : 0.035)),
                            radius: elevated ? 16 : 10, y: elevated ? 8 : 4)                         // ambiente
            )
            .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
            .overlay( // "lip": luz de 1px no topo
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(dark ? 0.07 : 0.7), .clear],
                                   startPoint: .top, endPoint: .init(x: 0.5, y: 0.12)),
                    lineWidth: 1)
            )
    }
}

/// Superfície que flutua sobre o conteúdo (dica do gráfico): Liquid Glass no visual padrão,
/// cartão sólido elevado no Clássico ou antes do macOS 26.
private struct FloatingSurface: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if Preferences.shared.usesGlass, #available(macOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.cardSurface(radius: radius, elevated: true)
        }
    }
}

extension View {
    func cardSurface(radius: CGFloat = Theme.Radius.card, elevated: Bool = false) -> some View {
        modifier(CardSurface(radius: radius, elevated: elevated))
    }

    func floatingSurface(radius: CGFloat = Theme.Radius.control) -> some View {
        modifier(FloatingSurface(radius: radius))
    }

    /// Rótulo pequeno em caixa alta ("DAILY AVERAGE", "TOKENS"), na fonte do sistema.
    func eyebrow() -> some View {
        font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .textCase(.uppercase)
    }
}

/// Anel de foco com respiro, para quem navega pelo teclado.
struct FocusRing: View {
    var radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 1)
            .padding(-1)
            .overlay(
                RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 3)
                    .padding(-4)
            )
    }
}

/// Cartão clicável: sobe no hover, encolhe ao pressionar, mostra foco do teclado.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableCard(configuration: configuration)
    }

    private struct PressableCard: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused
        @ViewState private var hovering = false

        var body: some View {
            configuration.label
                .cardSurface(elevated: hovering)
                .overlay { if isFocused { FocusRing(radius: Theme.Radius.card) } }
                .scaleEffect(configuration.isPressed ? Motion.pressScale : 1)
                .motion(configuration.isPressed ? Motion.instant : Motion.fast, value: configuration.isPressed)
                .motion(hovering ? Motion.fast : Motion.exit, value: hovering)
                .onHover { hovering = $0 }
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }
}

// MARK: formatos (seguem o idioma escolhido)

enum Fmt {
    static var locale: Locale { Preferences.shared.language.locale }
    private static var isPT: Bool { Preferences.shared.language == .pt }

    static func number(_ value: Double, decimals: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...decimals)).locale(locale))
    }

    static func int(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    /// en: 598M, 1.2B, 35K · pt: 598 mi, 1,2 bi, 35 mil.
    static func tokens(_ value: Int) -> String { tokens(Double(value)) }

    static func tokens(_ value: Double) -> String {
        let (k, m, b) = isPT ? (" mil", " mi", " bi") : ("K", "M", "B")
        switch abs(value) {
        case ..<1_000: return number(value, decimals: 0)
        case ..<1_000_000: return number(value / 1_000, decimals: 0) + k
        case ..<1_000_000_000: return number(value / 1_000_000, decimals: value < 100_000_000 ? 1 : 0) + m
        default: return number(value / 1_000_000_000, decimals: 1) + b
        }
    }

    /// Ícone do custo: cifrão ou real, conforme a moeda escolhida.
    static var costSymbol: String { Preferences.shared.showsBRL ? "brazilianrealsign.circle.fill" : "dollarsign.circle.fill" }

    /// Recebe o valor em dólar (preço da API) e mostra na moeda escolhida nos Ajustes.
    /// en: $277.45 / R$1,520.10 · pt: US$ 277,45 / R$ 1.520,10.
    static func money(_ usd: Double) -> String {
        let prefs = Preferences.shared
        let (value, code) = prefs.showsBRL ? (usd * prefs.brlPerUSD, "BRL") : (usd, "USD")
        return value.formatted(.currency(code: code).precision(.fractionLength(value >= 1000 ? 0 : 2)).locale(locale))
    }

    /// en: 4h 06m · pt: 4h 06min.
    static func hours(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        let unit = isPT ? "min" : "m"
        if minutes < 60 { return "\(minutes)\(unit)" }
        return String(format: "%dh %02d", minutes / 60, minutes % 60) + unit
    }

    static func shortHours(_ hours: Double) -> String {
        hours < 1 ? "\(Int((hours * 60).rounded()))\(isPT ? "min" : "m")" : number(hours) + "h"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale)).capitalizedFirst
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    static func days(_ n: Int) -> String {
        n == 1 ? T("day", "dia") : T("days", "dias")
    }

    /// Nome de projeto para a tela ("Sem pasta" é guardado assim no núcleo).
    static func project(_ name: String) -> String {
        name == ClaudeLogParser.noFolder ? T("No folder", "Sem pasta") : name
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension Period {
    var name: String {
        switch self {
        case .week: T("Week", "Semana")
        case .month: T("Month", "Mês")
        case .sixMonths: T("6 months", "6 meses")
        case .year: T("Year", "Ano")
        }
    }

    /// Rótulo curto do seletor: W M 6M Y / S M 6M A.
    var short: String {
        switch self {
        case .week: T("W", "S")
        case .month: "M"
        case .sixMonths: "6M"
        case .year: T("Y", "A")
        }
    }
}

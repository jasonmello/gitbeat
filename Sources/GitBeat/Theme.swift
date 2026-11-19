import SwiftUI
import GitBeatCore

/// Tokens visuais do app. Ver DESIGN.md. Componentes nunca usam cor, raio, sombra ou duração soltos.
enum Theme {
    // MARK: cores dos assuntos (cores de dado, como os anéis do app Saúde)
    static let tokens = Color.pink
    static let time = Color.teal
    static let github = Brand.green
    static let cost = Color.purple
    static let streak = Color.orange

    // MARK: neutros quentes (matiz levemente amarelado, nunca preto ou branco puros)
    /// Fundo da página, atrás dos cartões.
    static let page = Adaptive(light: Color(red: 0.961, green: 0.961, blue: 0.953),   // #f5f5f3
                               dark: Color(red: 0.055, green: 0.055, blue: 0.059))    // #0e0e0f
    /// Cartões e popovers no visual clássico, um degrau acima da página.
    static let raised = Adaptive(light: Color(red: 0.992, green: 0.992, blue: 0.988),  // #fdfdfc
                                 dark: Color(red: 0.098, green: 0.098, blue: 0.106))   // #19191b
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

/// Fundo da página. No Liquid Glass, três manchas de luz bem difusas nas cores dos assuntos
/// dão ao vidro o que refratar; no clássico, só o neutro quente.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.page)
            if Preferences.shared.usesGlass {
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    let strength = scheme == .dark ? 0.30 : 0.22
                    ZStack {
                        glow(Theme.tokens, size: w * 0.55).position(x: w * 0.12, y: h * 0.08)
                        glow(Theme.time, size: w * 0.5).position(x: w * 0.92, y: h * 0.35)
                        glow(Theme.github, size: w * 0.55).position(x: w * 0.35, y: h * 0.95)
                    }
                    .opacity(strength)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func glow(_ color: Color, size: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).blur(radius: size * 0.35)
    }
}

// MARK: superfícies

/// Fundo de cartão.
/// - Liquid Glass: `glassEffect` do sistema (interativo nos cartões clicáveis).
/// - Clássico: degrau de superfície, anel fino, luz de 1px no topo e sombra em camadas de alfa baixo.
private struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat
    var elevated: Bool
    var interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if Preferences.shared.usesGlass, #available(macOS 26, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            classic(content, shape: shape)
        }
    }

    private func classic(_ content: Content, shape: RoundedRectangle) -> some View {
        let dark = scheme == .dark
        // A sombra fica só no fundo: aplicada ao conteúdo, ela vazaria para cada texto do cartão.
        return content
            .background(
                shape.fill(Theme.raised)
                    .shadow(color: .black.opacity(dark ? 0.30 : 0.04), radius: 1, y: 1)            // contato
                    .shadow(color: .black.opacity(dark ? (elevated ? 0.55 : 0.35) : (elevated ? 0.10 : 0.045)),
                            radius: elevated ? 14 : 8, y: elevated ? 8 : 3)                          // ambiente
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

extension View {
    func cardSurface(radius: CGFloat = Theme.Radius.card, elevated: Bool = false, interactive: Bool = false) -> some View {
        modifier(CardSurface(radius: radius, elevated: elevated, interactive: interactive))
    }

    /// Rótulo pequeno em caixa alta, mono, com tracking positivo ("DAILY AVERAGE", "TODAY").
    func eyebrow() -> some View {
        font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .tracking(0.8)
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
                .cardSurface(elevated: hovering, interactive: true)
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

    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(value >= 1000 ? 0 : 2)).locale(locale))
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

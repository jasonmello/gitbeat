import Charts
import SwiftUI
import GitBeatCore

/// Cartão: título colorido com ícone, conteúdo embaixo.
/// Com `action`, vira botão: sobe no hover, encolhe ao clicar, aceita foco do teclado.
struct Card<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    var trailing: String?
    var action: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        if let action {
            Button(action: action) { inner }
                .buttonStyle(PressableCardStyle())
        } else {
            inner.cardSurface()
        }
    }

    private var inner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImage).symbolRenderingMode(.hierarchical)
                }
                .font(.headline)
                .foregroundStyle(tint)
                Spacer()
                // Rótulo de apoio e seta em cinza: a cor fica só no título.
                if let trailing {
                    Text(trailing).font(.subheadline).foregroundStyle(.secondary)
                }
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            content
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
        .foregroundStyle(.primary)
    }
}

/// Número grande com unidade menor ao lado, como "598 mi tokens".
struct BigValue: View {
    var value: String
    var unit: String?
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let caption {
                Text(caption).eyebrow().foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit).font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Anéis concêntricos de metas. Passar de 100% desenha uma segunda volta.
struct ActivityRings: View {
    struct Value {
        var progress: Double
        var color: Color
    }

    var values: [Value]
    var size: CGFloat

    var body: some View {
        let line = size * 0.12
        let gap = max(size * 0.015, 1.5)
        ZStack {
            ForEach(Array(values.enumerated()), id: \.offset) { index, v in
                Ring(progress: v.progress, color: v.color, lineWidth: line)
                    .padding(CGFloat(index) * (line + gap))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(values.map { "\(Int(($0.progress * 100).rounded()))%" }.joined(separator: ", "))
        .accessibilityHint(T("Daily goals: tokens, time, commits", "Metas do dia: tokens, tempo, commits"))
    }
}

/// Um anel. Ao aparecer, fecha do zero até o valor: é a animação que tem significado aqui.
struct Ring: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var shown = false

    var body: some View {
        let target = shown ? progress : 0
        let first = min(max(target, 0), 1)
        // Depois da primeira volta o anel continua por cima de si mesmo, até a terceira.
        let lap = min(max(target - 1, 0), 2)
        let second = lap > 1 ? 1 : lap
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)   // trilha: a mesma cor, apagada
            Circle()
                .trim(from: 0, to: first)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if lap > 0 {
                Circle()
                    .trim(from: 0, to: second)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            // Só a ponta faz sombra sobre a volta de baixo: mostra que passou da meta sem escurecer
            // o anel inteiro. Volta fechada certinha (200%, 300%) não tem ponta: o anel está completo.
            let tip = lap.truncatingRemainder(dividingBy: 1)
            if lap > 0, tip > 0.005, tip < 0.995 {
                GeometryReader { geo in
                    let r = (min(geo.size.width, geo.size.height)) / 2
                    let angle = Angle.degrees(360 * tip - 90)
                    Circle()
                        .fill(color)
                        .frame(width: lineWidth, height: lineWidth)
                        .shadow(color: .black.opacity(0.45), radius: lineWidth * 0.18, x: 0, y: 0)
                        .position(x: geo.size.width / 2 + r * cos(angle.radians),
                                  y: geo.size.height / 2 + r * sin(angle.radians))
                }
            }
        }
        .padding(lineWidth / 2)
        .motion(Motion.considered, value: target)
        .onAppear { shown = true }
        .transaction { if reduceMotion { $0.animation = nil } }
    }
}

/// Uma linha da legenda dos anéis: "Tokens  598 mi / 400 mi".
struct RingLegend: View {
    var title: String
    var value: String
    var goal: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).eyebrow().foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(-0.4)
                    .foregroundStyle(color)
                    .lineLimit(1)
                Text("/\(goal)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(color.opacity(0.75))
            }
            .monospacedDigit()
        }
        .fixedSize()
    }
}

extension Period {
    var chartUnit: Calendar.Component {
        switch self {
        case .week, .month: .day
        case .sixMonths: .weekOfYear
        case .year: .month
        }
    }

    var bucketLabel: String {
        switch self {
        case .week, .month: T("per day", "por dia")
        case .sixMonths: T("per week", "por semana")
        case .year: T("per month", "por mês")
        }
    }
}

/// Gráfico de barras padrão do app. Passar o mouse mostra o valor da barra.
struct BarChart: View {
    var points: [AppModel.Point]
    var period: Period
    var tint: Color
    var height: CGFloat = 220
    var format: (Double) -> String

    @ViewState private var selected: Date?

    var body: some View {
        Chart(points) { p in
            BarMark(x: .value("Data", p.date, unit: period.chartUnit),
                    y: .value("Valor", p.value))
                .foregroundStyle(tint.gradient)
                .cornerRadius(3)
                .opacity(selected == nil || sameBucket(selected, p.date) ? 1 : 0.35)
            if let s = selected, sameBucket(s, p.date) {
                RuleMark(x: .value("Data", p.date, unit: period.chartUnit))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label(p.date)).eyebrow().foregroundStyle(.secondary)
                            Text(format(p.value))
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .floatingSurface()
                    }
            }
        }
        .chartXSelection(value: $selected)
        .motion(Motion.fast, value: selected)
        .chartYAxis {
            AxisMarks(position: .trailing) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let d = v.as(Double.self) { Text(format(d)).monospacedDigit() }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: axisStride.0, count: axisStride.1)) { _ in
                AxisValueLabel(format: axisFormat, centered: true)
            }
        }
        .frame(height: height)
    }

    private var axisStride: (Calendar.Component, Int) {
        switch period {
        case .week: (.day, 1)
        case .month: (.day, 7)
        case .sixMonths: (.month, 1)
        case .year: (.month, 1)
        }
    }

    private var axisFormat: Date.FormatStyle {
        let loc = Fmt.locale
        switch period {
        case .week: return .dateTime.weekday(.abbreviated).locale(loc)
        case .month: return .dateTime.day().month(.abbreviated).locale(loc)
        case .sixMonths: return .dateTime.month(.abbreviated).locale(loc)
        case .year: return .dateTime.month(.narrow).locale(loc)
        }
    }

    private func sameBucket(_ a: Date?, _ b: Date) -> Bool {
        guard let a else { return false }
        return Calendar.current.isDate(a, equalTo: b, toGranularity: period.chartUnit)
    }

    private func label(_ date: Date) -> String {
        switch period {
        case .week, .month: return Fmt.day(date)
        case .sixMonths: return T("week of ", "semana de ") + Fmt.day(date)
        case .year: return date.formatted(.dateTime.month(.wide).year().locale(Fmt.locale))
        }
    }
}

/// Lista com barra proporcional, para "por projeto" e "por modelo".
struct ProportionList: View {
    struct Row: Identifiable {
        var name: String
        var value: Double
        var detail: String
        var id: String { name }
    }

    var rows: [Row]
    var tint: Color
    var limit = 8

    var body: some View {
        let top = Array(rows.prefix(limit))
        let maxValue = top.map(\.value).max() ?? 1
        VStack(spacing: 11) {
            if top.isEmpty {
                EmptyNote(text: T("Nothing in this period.", "Nada neste período."))
            }
            ForEach(top) { row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(row.name).lineLimit(1)
                        Spacer()
                        Text(row.detail).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .font(.callout)
                    GeometryReader { geo in
                        Capsule().fill(Theme.well)
                            .overlay(alignment: .leading) {
                                Capsule().fill(tint.gradient)
                                    .frame(width: max(6, geo.size.width * row.value / max(maxValue, 1)))
                            }
                    }
                    .frame(height: 6)
                }
            }
        }
    }
}

/// Título de página com sobretítulo, como "THURSDAY, NOVEMBER 19 / Summary".
struct PageHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let subtitle {
                Text(subtitle).eyebrow().foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

struct PeriodPicker: View {
    @Binding var period: Period

    var body: some View {
        Picker(T("Period", "Período"), selection: $period) {
            ForEach(Period.allCases) { Text($0.short).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 320)
        .help(Period.allCases.map { "\($0.short): \($0.name)" }.joined(separator: " · "))
    }
}

/// Frase curta para quando não há dado, no lugar de um gráfico vazio.
struct EmptyNote: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: carregamento

/// Bloco cinza com um brilho que passa, enquanto os dados são lidos pela primeira vez.
struct Skeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Theme.well)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.35), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: phase * geo.size.width * 1.6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .blendMode(.plusLighter)
                }
            }
            .frame(width: width, height: height)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

/// Esqueleto da página enquanto o histórico do Claude Code é lido (a primeira leitura leva uns 20 s).
struct LoadingPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            VStack(alignment: .leading, spacing: 8) {
                Skeleton(width: 180, height: 10)
                Skeleton(width: 240, height: 28)
            }
            HStack(spacing: Theme.gap) {
                skeletonCard(height: 190)
                skeletonCard(height: 190).frame(width: 260)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.gap), GridItem(.flexible(), spacing: Theme.gap)],
                      spacing: Theme.gap) {
                ForEach(0..<4, id: \.self) { _ in skeletonCard(height: 170) }
            }
            HStack(spacing: 12) {
                MascotView(mood: .idle, size: 56)
                Text(T("Reading your coding history. The first time takes about 20 seconds; after that, under one.",
                       "Lendo o seu histórico. Na primeira vez leva uns 20 segundos; depois, menos de um."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func skeletonCard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Skeleton(width: 110, height: 10)
            Skeleton(width: 160, height: 26)
            Spacer(minLength: 0)
            Skeleton(height: 44)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .cardSurface()
    }
}

/// Estado vazio: nenhuma conversa de nenhuma ferramenta encontrada.
struct EmptyPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MascotView(mood: .curious, size: 96)
            PageHeader(title: T("Nothing to show yet", "Nada para mostrar ainda"), subtitle: T("Coding tools", "Ferramentas"))
            Text(T("No sessions found for Claude Code, OpenCode, Codex or Gemini CLI. Use one of them once and press Refresh (⌘R).",
                   "Não achei sessões do Claude Code, OpenCode, Codex nem Gemini CLI. Use uma delas uma vez e clique em Atualizar (⌘R)."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }
}

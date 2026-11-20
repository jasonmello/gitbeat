import Charts
import SwiftUI
import GitBeatCore

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: Section?

    var body: some View {
        let today = model.todayKey
        let rings = model.rings(on: today)
        let tokens = model.tokens(on: today)
        let week = model.dayKeys(.week)

        VStack(alignment: .leading, spacing: Theme.gap) {
            PageHeader(title: T("Summary", "Resumo"), subtitle: Fmt.longDay(Date()))

            HStack(alignment: .top, spacing: Theme.gap) {
                Card(title: T("Today's rings", "Anéis de hoje"), systemImage: "circle.circle", tint: .red,
                     action: { selection = .goals }) {
                    // A semana em anéis aparece quando cabe; em janela estreita, só hoje.
                    ViewThatFits(in: .horizontal) {
                        todayRings(rings, tokens, today: today, week: week)
                        todayRings(rings, tokens, today: today, week: nil)
                    }
                }

                Card(title: T("Streak", "Sequência"), systemImage: "flame.fill", tint: Theme.streak,
                     action: { selection = .goals }) {
                    BigValue(value: Fmt.int(model.currentStreak), unit: Fmt.days(model.currentStreak))
                    Text(T("in a row coding with AI or committing", "seguidos programando com IA ou fazendo commits"))
                        .font(.callout).foregroundStyle(.secondary)
                    StreakWeek(days: week).padding(.vertical, 4)
                    Divider()
                    Text(T("Record: ", "Recorde: ") + "\(Fmt.int(model.longestStreak)) \(Fmt.days(model.longestStreak))")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                }
                .frame(width: 270)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.gap), GridItem(.flexible(), spacing: Theme.gap)],
                      spacing: Theme.gap) {
                summaryCard(.tokens, value: Fmt.tokens(tokens.total), unit: "tokens",
                            detail: T("\(Fmt.tokens(tokens.output)) output · \(Fmt.int(tokens.responses)) responses",
                                      "\(Fmt.tokens(tokens.output)) de saída · \(Fmt.int(tokens.responses)) respostas"),
                            points: model.series(.week) { Double(model.tokenSum($0).total) })

                summaryCard(.time, value: Fmt.hours(model.hours(on: today)), unit: nil,
                            detail: T("coding with AI", "programando com IA"),
                            points: model.series(.week) { model.hoursSum($0) })

                summaryCard(.github, value: Fmt.int(model.commits(on: today)), unit: "commits",
                            detail: T("\(model.prsMergedSum(week)) PRs merged in the last 7 days",
                                      "\(model.prsMergedSum(week)) PRs mesclados nos últimos 7 dias"),
                            points: model.series(.week) { Double(model.commitSum($0)) })

                Card(title: T("Equivalent cost", "Custo equivalente"), systemImage: "dollarsign.circle.fill",
                     tint: Theme.cost, trailing: T("Today", "Hoje"), action: { selection = .tokens }) {
                    BigValue(value: Fmt.money(tokens.cost))
                    Text(T("\(Fmt.money(model.tokenSum(model.dayKeys(.month)).cost)) in the last 30 days, at API prices",
                           "\(Fmt.money(model.tokenSum(model.dayKeys(.month)).cost)) nos últimos 30 dias, a preço da API"))
                        .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    MiniBars(points: model.series(.week) { model.tokenSum($0).cost }, tint: Theme.cost)
                }
            }

            if let error = model.githubErrorText {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    /// Anéis de hoje com a legenda; com `week`, a semana em anéis pequenos à direita.
    private func todayRings(_ rings: AppModel.RingValues, _ tokens: TokenTotals,
                            today: String, week: [String]?) -> some View {
        HStack(alignment: .center, spacing: 24) {
            ActivityRings(values: [
                .init(progress: rings.tokens, color: Theme.tokens),
                .init(progress: rings.hours, color: Theme.time),
                .init(progress: rings.commits, color: Theme.github),
            ], size: 150)
            VStack(alignment: .leading, spacing: 12) {
                RingLegend(title: T("Tokens", "Tokens"), value: Fmt.tokens(tokens.total),
                           goal: Fmt.tokens(model.goals.tokens), color: Theme.tokens)
                RingLegend(title: T("Time", "Tempo"), value: Fmt.shortHours(model.hours(on: today)),
                           goal: Fmt.shortHours(model.goals.hours), color: Theme.time)
                RingLegend(title: "Commits", value: Fmt.int(model.commits(on: today)),
                           goal: Fmt.int(model.goals.commits), color: Theme.github)
            }
            Spacer(minLength: 16)
            if let week { WeekRings(days: week).fixedSize() }
        }
    }

    private func summaryCard(_ section: Section, value: String, unit: String?,
                             detail: String, points: [AppModel.Point]) -> some View {
        Card(title: section.title, systemImage: section.systemImage, tint: section.tint, trailing: T("Today", "Hoje"),
             action: { selection = section }) {
            BigValue(value: value, unit: unit)
            Text(detail).font(.callout).monospacedDigit().foregroundStyle(.secondary)
            MiniBars(points: points, tint: section.tint)
        }
    }
}

/// Os anéis de cada um dos últimos 7 dias, pequenos, com a letra do dia embaixo.
/// Mostra o ritmo da semana sem sair do cartão de hoje.
struct WeekRings: View {
    @Environment(AppModel.self) private var model
    var days: [String]

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(T("Last 7 days", "Últimos 7 dias")).eyebrow().foregroundStyle(.secondary)
            HStack(spacing: 7) {
                ForEach(days, id: \.self) { day in
                    let r = model.rings(on: day)
                    let isToday = day == model.todayKey
                    VStack(spacing: 6) {
                        ActivityRings(values: [
                            .init(progress: r.tokens, color: Theme.tokens),
                            .init(progress: r.hours, color: Theme.time),
                            .init(progress: r.commits, color: Theme.github),
                        ], size: 30)
                        Text(letter(day))
                            .font(.caption2.weight(isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                            .fixedSize()
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(T("Rings for the last 7 days", "Anéis dos últimos 7 dias"))
    }

    private func letter(_ day: String) -> String {
        guard let date = model.days.date(day) else { return "" }
        return date.formatted(.dateTime.weekday(.narrow).locale(Fmt.locale))
    }
}

/// Os últimos 7 dias como bolinhas: cheia com atividade, vazia sem. Hoje sem atividade
/// aparece tracejado (o dia ainda pode contar).
struct StreakWeek: View {
    @Environment(AppModel.self) private var model
    var days: [String]

    var body: some View {
        let active = model.activeDays
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let on = active.contains(day)
                let isToday = day == model.todayKey
                VStack(spacing: 5) {
                    ZStack {
                        if on {
                            Circle().fill(Theme.streak.gradient)
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                        } else if isToday {
                            Circle().strokeBorder(Theme.streak, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                        } else {
                            Circle().fill(Theme.well)
                        }
                    }
                    .frame(width: 20, height: 20)
                    Text(letter(day))
                        .font(.caption2.weight(isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(T("Active days this week: ", "Dias ativos na semana: ") + "\(days.filter(active.contains).count)/\(days.count)")
    }

    private func letter(_ day: String) -> String {
        guard let date = model.days.date(day) else { return "" }
        return date.formatted(.dateTime.weekday(.narrow).locale(Fmt.locale))
    }
}

/// Barrinhas dos últimos 7 dias, sem eixo, para os cartões do resumo.
struct MiniBars: View {
    var points: [AppModel.Point]
    var tint: Color

    var body: some View {
        Chart(points) { p in
            BarMark(x: .value("Day", p.date, unit: .day), y: .value("Value", p.value))
                .foregroundStyle(Calendar.current.isDateInToday(p.date) ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.45)))
                .cornerRadius(4)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow).locale(Fmt.locale), centered: true)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 60)
    }
}

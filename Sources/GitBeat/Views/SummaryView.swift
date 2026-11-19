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
                    HStack(spacing: 28) {
                        ActivityRings(values: [
                            .init(progress: rings.tokens, color: Theme.tokens),
                            .init(progress: rings.hours, color: Theme.time),
                            .init(progress: rings.commits, color: Theme.github),
                        ], size: 150)
                        VStack(alignment: .leading, spacing: 10) {
                            RingLegend(title: T("Tokens", "Tokens"), value: Fmt.tokens(tokens.total),
                                       goal: Fmt.tokens(model.goals.tokens), color: Theme.tokens)
                            RingLegend(title: T("Time", "Tempo"), value: Fmt.shortHours(model.hours(on: today)),
                                       goal: Fmt.shortHours(model.goals.hours), color: Theme.time)
                            RingLegend(title: "Commits", value: Fmt.int(model.commits(on: today)),
                                       goal: Fmt.int(model.goals.commits), color: Theme.github)
                        }
                        Spacer(minLength: 0)
                    }
                }

                Card(title: T("Streak", "Sequência"), systemImage: "flame.fill", tint: Theme.streak,
                     action: { selection = .goals }) {
                    BigValue(value: Fmt.int(model.currentStreak), unit: Fmt.days(model.currentStreak))
                    Text(T("in a row coding with AI or committing", "seguidos programando com IA ou fazendo commits"))
                        .font(.callout).foregroundStyle(.secondary)
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

/// Barrinhas dos últimos 7 dias, sem eixo, para os cartões do resumo.
struct MiniBars: View {
    var points: [AppModel.Point]
    var tint: Color

    var body: some View {
        Chart(points) { p in
            BarMark(x: .value("Day", p.date, unit: .day), y: .value("Value", p.value))
                .foregroundStyle(Calendar.current.isDateInToday(p.date) ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.32)))
                .cornerRadius(2)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow).locale(Fmt.locale), centered: true)
            }
        }
        .frame(height: 56)
    }
}

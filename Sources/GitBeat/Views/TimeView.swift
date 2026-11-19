import Charts
import SwiftUI
import GitBeatCore

struct TimeView: View {
    @Environment(AppModel.self) private var model
    @ViewState private var period: Period = .week

    var body: some View {
        let keys = model.dayKeys(period)
        let total = model.hoursSum(keys)

        VStack(alignment: .leading, spacing: Theme.gap) {
            PageHeader(title: T("Time", "Tempo"), subtitle: T("Coding with AI", "Programando com IA"))
            PeriodPicker(period: $period)

            Card(title: T("Hours ", "Horas ") + period.bucketLabel, systemImage: "clock.fill", tint: Theme.time, trailing: period.name) {
                HStack(alignment: .bottom, spacing: 32) {
                    BigValue(value: Fmt.hours(total / Double(model.elapsedDays(keys))), caption: T("Daily average", "Média diária"))
                    BigValue(value: Fmt.hours(total), caption: T("Total in period", "Total no período"))
                }
                BarChart(points: model.series(period) { model.hoursSum($0) },
                         period: period, tint: Theme.time, format: Fmt.shortHours)
            }

            Card(title: T("Peak hours", "Horários de pico"), systemImage: "sun.max.fill", tint: Theme.time,
                 trailing: T("Last 30 days", "Últimos 30 dias")) {
                Chart(Array(model.responsesByHour.enumerated()), id: \.offset) { hour, count in
                    BarMark(x: .value("Hour", hour), y: .value("Responses", count))
                        .foregroundStyle(Theme.time.gradient)
                        .cornerRadius(2)
                }
                .chartXScale(domain: -0.5...23.5)
                .chartXAxis {
                    AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { v in
                        AxisValueLabel { if let h = v.as(Int.self) { Text("\(h)h").monospacedDigit() } }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 160)
                if let peak = model.responsesByHour.indices.max(by: { model.responsesByHour[$0] < model.responsesByHour[$1] }),
                   model.responsesByHour[peak] > 0 {
                    Text(T("You code with AI the most around \(peak)h.", "Você mais programa com IA por volta das \(peak)h."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Text(T("Active time adds up the gaps between replies of up to 15 minutes. Longer breaks don't count, and parallel sessions count once.",
                   "Tempo ativo soma os intervalos entre respostas de até 15 minutos. Pausas maiores não contam, e sessões em paralelo contam uma vez só."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

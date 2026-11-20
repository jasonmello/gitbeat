import SwiftUI
import GitBeatCore

struct GoalsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let keys = model.dayKeys(.month)
        let metAll = keys.filter { k in
            let r = model.rings(on: k)
            return r.tokens >= 1 && r.hours >= 1 && r.commits >= 1
        }.count

        VStack(alignment: .leading, spacing: Theme.gap) {
            PageHeader(title: T("Goals", "Metas"), subtitle: T("Rings and streaks", "Anéis e sequências"))

            HStack(alignment: .top, spacing: Theme.gap) {
                Card(title: T("Current streak", "Sequência atual"), systemImage: "flame.fill", tint: Theme.streak) {
                    BigValue(value: Fmt.int(model.currentStreak), unit: Fmt.days(model.currentStreak))
                }
                Card(title: T("Record", "Recorde"), systemImage: "trophy.fill", tint: Theme.streak) {
                    BigValue(value: Fmt.int(model.longestStreak), unit: Fmt.days(model.longestStreak))
                }
                Card(title: T("All three rings closed", "Três anéis fechados"), systemImage: "checkmark.seal.fill", tint: Theme.tokens,
                     trailing: T("30 days", "30 dias")) {
                    BigValue(value: Fmt.int(metAll), unit: Fmt.days(metAll))
                }
            }

            Card(title: T("Last two weeks", "Últimas duas semanas"), systemImage: "calendar", tint: Theme.tokens) {
                let recent = model.days.lastDays(14, endingAt: Date())
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
                    ForEach(recent, id: \.self) { key in
                        let r = model.rings(on: key)
                        VStack(spacing: 4) {
                            ActivityRings(values: [
                                .init(progress: r.tokens, color: Theme.tokens),
                                .init(progress: r.hours, color: Theme.time),
                                .init(progress: r.commits, color: Theme.github),
                            ], size: 52)
                            Text(model.days.date(key).map { $0.formatted(.dateTime.weekday(.abbreviated).day().locale(Fmt.locale)) } ?? key)
                                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Card(title: T("Daily goals", "Metas diárias"), systemImage: "target", tint: Theme.streak) {
                GoalsForm()
            }
        }
    }
}

/// Edita as três metas. Aparece na tela Metas e nos Ajustes (⌘,).
struct GoalsForm: View {
    @Environment(AppModel.self) private var model

    private static let tokenSteps: [Int] = [10, 25, 50, 100, 200, 300, 400, 500, 750, 1_000, 1_500, 2_000].map { $0 * 1_000_000 }

    var body: some View {
        @Bindable var model = model
        Form {
            Picker(selection: $model.goals.tokens) {
                ForEach(Self.tokenSteps + (Self.tokenSteps.contains(model.goals.tokens) ? [] : [model.goals.tokens]), id: \.self) {
                    Text(Fmt.tokens($0)).tag($0)
                }
            } label: {
                Label(T("Tokens per day", "Tokens por dia"), systemImage: "bolt.fill").foregroundStyle(Theme.tokens)
            }
            Stepper(value: $model.goals.hours, in: 0.5...16, step: 0.5) {
                Label(T("Hours per day: ", "Horas por dia: ") + Fmt.number(model.goals.hours) + "h", systemImage: "clock.fill")
                    .foregroundStyle(Theme.time)
            }
            Stepper(value: $model.goals.commits, in: 1...50) {
                Label(T("Commits per day: ", "Commits por dia: ") + "\(model.goals.commits)", systemImage: "arrow.triangle.branch")
                    .foregroundStyle(Theme.github)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

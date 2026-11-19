import SwiftUI
import GitBeatCore

struct GitHubView: View {
    @Environment(AppModel.self) private var model
    @ViewState private var period: Period = .month

    var body: some View {
        let keys = model.dayKeys(period)
        VStack(alignment: .leading, spacing: Theme.gap) {
            PageHeader(title: "GitHub", subtitle: model.github.map { "@\($0.login)" })

            if let error = model.githubErrorText {
                Card(title: T("Couldn't read GitHub", "Não consegui ler o GitHub"), systemImage: "exclamationmark.triangle.fill", tint: .orange) {
                    Text(error).font(.callout).textSelection(.enabled)
                    if model.github != nil {
                        Text(T("Showing the last saved data.", "Mostrando os últimos dados salvos."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if model.github == nil {
                Card(title: "GitHub", systemImage: "arrow.triangle.branch", tint: Theme.github) {
                    if model.isLoading {
                        VStack(alignment: .leading, spacing: 10) {
                            Skeleton(width: 160, height: 26)
                            Skeleton(height: 120)
                        }
                    } else {
                        EmptyNote(text: T("No GitHub data yet. Press Refresh (⌘R).", "Sem dados do GitHub ainda. Clique em Atualizar (⌘R)."))
                    }
                }
            } else {
                PeriodPicker(period: $period)

                Card(title: "Commits \(period.bucketLabel)", systemImage: "arrow.triangle.branch", tint: Theme.github, trailing: period.name) {
                    HStack(alignment: .bottom, spacing: 32) {
                        BigValue(value: Fmt.int(model.commitSum(keys)), unit: "commits", caption: "Total")
                        BigValue(value: Fmt.int(model.prsOpenedSum(keys)), unit: T("opened", "abertos"), caption: "Pull requests")
                        BigValue(value: Fmt.int(model.prsMergedSum(keys)), unit: T("merged", "mesclados"), caption: " ")
                    }
                    BarChart(points: model.series(period) { Double(model.commitSum($0)) },
                             period: period, tint: Theme.github, format: { Fmt.int(Int($0)) })
                }

                Card(title: T("Commits in the last year", "Commits no último ano"), systemImage: "square.grid.3x3.fill", tint: Theme.github) {
                    ContributionGrid(counts: (model.github?.commits ?? [:]).mapValues { $0.values.reduce(0, +) }, days: model.days)
                    Label(T("Includes private repositories. Your GitHub profile calendar may show fewer — see About the data.",
                            "Inclui repositórios privados. O calendário do seu perfil no GitHub pode mostrar menos — veja Sobre os dados."),
                          systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: Theme.gap) {
                    Card(title: T("By repository", "Por repositório"), systemImage: "folder.fill", tint: Theme.github, trailing: period.name) {
                        ProportionList(rows: repoRows(keys), tint: Theme.github)
                    }
                    Card(title: T("Recent pull requests", "Pull requests recentes"), systemImage: "arrow.triangle.pull", tint: Theme.github) {
                        RecentPRs(prs: Array((model.github?.pullRequests ?? []).sorted { $0.createdAt > $1.createdAt }.prefix(8)))
                    }
                }

                Text(T("Commits count what reached each repository's default branch. A squash-merged PR becomes one commit.",
                       "Commits contam o que entrou no branch principal de cada repositório. Um PR mesclado com squash vira um commit."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func repoRows(_ keys: [String]) -> [ProportionList.Row] {
        var totals: [String: Int] = [:]
        for k in keys {
            for (repo, n) in model.github?.commits[k] ?? [:] { totals[repo, default: 0] += n }
        }
        return totals.sorted { $0.value > $1.value }.map {
            ProportionList.Row(name: $0.key.split(separator: "/").last.map(String.init) ?? $0.key,
                               value: Double($0.value), detail: Fmt.int($0.value))
        }
    }
}

/// Quadriculado no estilo do perfil do GitHub: uma coluna por semana, de domingo a sábado.
/// Sem ScrollView: 53 colunas cabem no cartão (e assim o modo --snapshot também desenha).
struct ContributionGrid: View {
    var counts: [String: Int]
    var days: DayKeys

    var body: some View {
        let weeks = buildWeeks()
        let maxCount = max(counts.values.max() ?? 1, 1)
        HStack(alignment: .top, spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 3) {
                    ForEach(week, id: \.self) { key in
                        let count = counts[key] ?? 0
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(count == 0 ? AnyShapeStyle(Theme.well)
                                  : AnyShapeStyle(Theme.github.opacity(0.3 + 0.7 * Double(count) / Double(maxCount))))
                            .frame(width: 11, height: 11)
                            .help("\(key): \(count) commits")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildWeeks() -> [[String]] {
        let cal = days.calendar
        let today = days.startOfDay(Date())
        guard let yearAgo = cal.date(byAdding: .day, value: -364, to: today) else { return [] }
        let weekday = cal.component(.weekday, from: yearAgo) // 1 = domingo
        guard var cursor = cal.date(byAdding: .day, value: -(weekday - 1), to: yearAgo) else { return [] }
        var weeks: [[String]] = []
        while cursor <= today {
            var week: [String] = []
            for _ in 0..<7 where cursor <= today {
                week.append(days.key(cursor))
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            weeks.append(week)
        }
        return weeks
    }
}

struct RecentPRs: View {
    var prs: [PullRequestInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if prs.isEmpty { EmptyNote(text: T("No PRs in the last year.", "Nenhum PR no último ano.")) }
            ForEach(prs, id: \.self) { pr in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: pr.mergedAt == nil ? "circle.dotted" : "checkmark.circle.fill")
                        .foregroundStyle(pr.mergedAt == nil ? Color.secondary : Theme.github)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pr.title).font(.callout).lineLimit(2)
                        Text("\(pr.repo.split(separator: "/").last.map(String.init) ?? pr.repo) · \(Fmt.day(pr.createdAt))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

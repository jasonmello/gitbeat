import SwiftUI
import GitBeatCore

struct TokensView: View {
    enum Metric: String, CaseIterable, Identifiable {
        case total, output, cost
        var id: String { rawValue }
        var title: String {
            switch self {
            case .total: T("Total", "Total")
            case .output: T("Output", "Saída")
            case .cost: T("Cost", "Custo")
            }
        }
    }

    @Environment(AppModel.self) private var model
    @ViewState private var period: Period = .week
    @ViewState private var metric: Metric = .total

    var body: some View {
        let keys = model.dayKeys(period)
        let sum = model.tokenSum(keys)
        let elapsed = model.elapsedDays(keys)
        let tools = Stats.breakdown(model.byTool, over: keys)

        VStack(alignment: .leading, spacing: Theme.gap) {
            PageHeader(title: "Tokens", subtitle: model.toolsFound.map(Tool.displayName).joined(separator: " · "))

            HStack {
                PeriodPicker(period: $period)
                Spacer()
                Picker(T("Metric", "Métrica"), selection: $metric) {
                    ForEach(Metric.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 230)
            }

            Card(title: "\(metric.title) \(period.bucketLabel)", systemImage: "bolt.fill", tint: Theme.tokens,
                 trailing: period.name) {
                HStack(alignment: .bottom, spacing: 32) {
                    BigValue(value: format(value(sum) / Double(elapsed)), unit: metric == .cost ? nil : "tokens",
                             caption: T("Daily average", "Média diária"))
                    BigValue(value: format(value(sum)), caption: T("Total in period", "Total no período"))
                }
                BarChart(points: model.series(period) { value(model.tokenSum($0)) },
                         period: period, tint: metric == .cost ? Theme.cost : Theme.tokens, format: format)
            }

            Card(title: T("Where the tokens come from", "De onde vêm os tokens"), systemImage: "chart.bar.doc.horizontal",
                 tint: Theme.tokens, trailing: period.name) {
                MixBar(totals: sum)
                Text(T("Cache reads are the context the model re-reads on every reply. They are cheap, but dominate the count.",
                       "Leitura de cache é o contexto que o modelo relê a cada resposta. É barata, mas domina a contagem."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            if tools.count > 1 {
                Card(title: T("By tool", "Por ferramenta"), systemImage: "hammer.fill", tint: Theme.tokens, trailing: period.name) {
                    ProportionList(rows: rows(tools), tint: Theme.tokens)
                }
            }

            HStack(alignment: .top, spacing: Theme.gap) {
                Card(title: T("By project", "Por projeto"), systemImage: "folder.fill", tint: Theme.tokens, trailing: period.name) {
                    ProportionList(rows: rows(Stats.breakdown(model.byProject, over: keys), project: true), tint: Theme.tokens)
                }
                Card(title: T("By model", "Por modelo"), systemImage: "cpu.fill", tint: Theme.cost, trailing: period.name) {
                    ProportionList(rows: rows(Stats.breakdown(model.byModel, over: keys)), tint: Theme.cost)
                }
            }

            Text(T("Cost is the equivalent at API list prices. On a Pro or Max subscription you don't pay per token. Codex and Gemini CLI don't record cost, so they count as zero here.",
                   "Custo é o equivalente a preço de API. Na assinatura Pro ou Max você não paga por token. Codex e Gemini CLI não gravam custo, então contam como zero aqui."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func value(_ t: TokenTotals) -> Double {
        switch metric {
        case .total: Double(t.total)
        case .output: Double(t.output)
        case .cost: t.cost
        }
    }

    private func format(_ v: Double) -> String {
        metric == .cost ? Fmt.money(v) : Fmt.tokens(v)
    }

    private func rows(_ items: [(name: String, totals: TokenTotals)], project: Bool = false) -> [ProportionList.Row] {
        items.map { item in
            ProportionList.Row(name: project ? Fmt.project(item.name) : item.name,
                               value: value(item.totals), detail: format(value(item.totals)))
        }
        .sorted { $0.value > $1.value }
    }
}

/// Barra única dividida por tipo de token, com legenda.
struct MixBar: View {
    var totals: TokenTotals

    private var parts: [(String, Int, Color)] {
        [(T("Cache read", "Leitura de cache"), totals.cacheRead, Theme.tokens.opacity(0.35)),
         (T("Cache write", "Escrita de cache"), totals.cacheWrite, Theme.cost),
         (T("Input", "Entrada"), totals.input, Theme.streak),
         (T("Output", "Saída"), totals.output, Theme.tokens)]
    }

    var body: some View {
        let total = max(totals.total, 1)
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts, id: \.0) { part in
                        if part.1 > 0 {
                            Rectangle().fill(part.2)
                                .frame(width: max(3, geo.size.width * Double(part.1) / Double(total)))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .frame(height: 14)
            HStack(spacing: 18) {
                ForEach(parts, id: \.0) { part in
                    HStack(spacing: 6) {
                        Circle().fill(part.2).frame(width: 8, height: 8)
                        Text(part.0).foregroundStyle(.secondary)
                        Text(Fmt.tokens(part.1)).monospacedDigit().foregroundStyle(.primary)
                    }
                    .font(.caption)
                }
            }
        }
    }
}

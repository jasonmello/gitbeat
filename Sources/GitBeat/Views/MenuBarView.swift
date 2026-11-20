import AppKit
import SwiftUI
import GitBeatCore

/// O painel que abre ao clicar no ícone da barra de menu.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let today = model.todayKey
        let r = model.rings(on: today)
        let tokens = model.tokens(on: today)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                BrandLogo(height: 24)
                Spacer()
                Text(Fmt.day(Date())).font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                ActivityRings(values: [
                    .init(progress: r.tokens, color: Theme.tokens),
                    .init(progress: r.hours, color: Theme.time),
                    .init(progress: r.commits, color: Theme.github),
                ], size: 96)
                // Número na cor do texto (lê bem sobre qualquer fundo do painel);
                // a cor do assunto fica no anel e no pontinho.
                VStack(alignment: .leading, spacing: 9) {
                    row("Tokens", Fmt.tokens(tokens.total), goal: Fmt.tokens(model.goals.tokens), Theme.tokens)
                    row(T("Time", "Tempo"), Fmt.shortHours(model.hours(on: today)),
                        goal: Fmt.shortHours(model.goals.hours), Theme.time)
                    row("Commits", Fmt.int(model.commits(on: today)), goal: Fmt.int(model.goals.commits), Theme.github)
                }
            }

            HStack(spacing: 8) {
                chip(systemImage: "flame.fill", tint: Theme.streak,
                     text: "\(model.currentStreak) \(Fmt.days(model.currentStreak))",
                     detail: model.streakAtRisk ? T("ends today", "termina hoje") : nil)
                chip(systemImage: Fmt.costSymbol, tint: Theme.cost,
                     text: Fmt.money(tokens.cost), detail: nil)
                    .help(T("Equivalent cost today, at API prices", "Custo equivalente de hoje, a preço da API"))
            }

            Divider()

            HStack(spacing: 4) {
                Button {
                    openWindow(id: "main")
                    NSApp.activate()
                } label: {
                    Text(T("Open GitBeat", "Abrir o GitBeat")).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                Button {
                    Task { await model.refresh(forceGitHub: true) }
                } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .disabled(model.isLoading)
                .help(T("Refresh", "Atualizar"))
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power").frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help(T("Quit GitBeat", "Sair do GitBeat"))
            }
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 320)
        .onAppear { model.refreshIfStale() }
    }

    private func row(_ title: String, _ value: String, goal: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                Text("/\(goal)").font(.system(.subheadline, design: .rounded).weight(.medium)).foregroundStyle(.secondary)
            }
            .monospacedDigit()
        }
    }

    private func chip(systemImage: String, tint: Color, text: String, detail: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(text).fontWeight(.semibold).monospacedDigit()
            if let detail {
                Text(detail).foregroundStyle(tint)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.well))
    }
}

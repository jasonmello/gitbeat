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

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                BrandLogo(height: 18)
                Spacer()
                Text(T("Today", "Hoje")).eyebrow().foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                ActivityRings(values: [
                    .init(progress: r.tokens, color: Theme.tokens),
                    .init(progress: r.hours, color: Theme.time),
                    .init(progress: r.commits, color: Theme.github),
                ], size: 92)
                VStack(alignment: .leading, spacing: 6) {
                    row("Tokens", Fmt.tokens(tokens.total), Theme.tokens)
                    row(T("Time", "Tempo"), Fmt.hours(model.hours(on: today)), Theme.time)
                    row("Commits", Fmt.int(model.commits(on: today)), Theme.github)
                    row(T("Cost", "Custo"), Fmt.money(tokens.cost), Theme.cost)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Theme.streak)
                Text("\(model.currentStreak) \(Fmt.days(model.currentStreak)) " + T("in a row", "seguidos"))
                    .font(.callout).monospacedDigit()
            }
            Divider()
            HStack {
                Button(T("Open dashboard", "Abrir painel")) {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
                Button {
                    Task { await model.refresh(forceGitHub: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .help(T("Refresh", "Atualizar"))
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help(T("Quit GitBeat", "Sair do GitBeat"))
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func row(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(color).monospacedDigit()
        }
        .font(.callout)
    }
}

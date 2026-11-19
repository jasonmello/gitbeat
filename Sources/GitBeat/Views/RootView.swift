import SwiftUI
import GitBeatCore

enum Section: String, CaseIterable, Identifiable, Hashable {
    case summary, tokens, github, time, goals, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: T("Summary", "Resumo")
        case .tokens: T("Tokens", "Tokens")
        case .github: "GitHub"
        case .time: T("Time", "Tempo")
        case .goals: T("Goals", "Metas")
        case .about: T("About the data", "Sobre os dados")
        }
    }

    var systemImage: String {
        switch self {
        case .summary: "heart.text.square.fill"
        case .tokens: "bolt.fill"
        case .github: "arrow.triangle.branch"
        case .time: "clock.fill"
        case .goals: "target"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .summary: .red
        case .tokens: Theme.tokens
        case .github: Theme.github
        case .time: Theme.time
        case .goals: Theme.streak
        case .about: .secondary
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @ViewState private var selection: Section? = .summary

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Section.allCases.filter { $0 != .about }) { row($0) }
                SwiftUI.Section { row(.about) }
            }
            .safeAreaInset(edge: .top) {
                BrandLogo(height: 26)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
            }
            .safeAreaInset(edge: .bottom) { CreditLine().padding(14) }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ScrollView {
                Group {
                    if model.isFirstLoad {
                        LoadingPage()
                    } else if model.isEmpty && selection != .github && selection != .about {
                        EmptyPage()
                    } else {
                        switch selection ?? .summary {
                        case .summary: SummaryView(selection: $selection)
                        case .tokens: TokensView()
                        case .github: GitHubView()
                        case .time: TimeView()
                        case .goals: GoalsView()
                        case .about: AboutDataView()
                        }
                    }
                }
                .transition(.opacity)
                .motion(Motion.regular, value: model.isFirstLoad)
                .padding(24)
                .frame(maxWidth: 1040)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshButton()
            }
        }
    }

    private func row(_ section: Section) -> some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: section.systemImage).foregroundStyle(section.tint)
        }
        .tag(section)
    }
}

/// "Proudly developed by Jason Mello", no rodapé da barra lateral e no painel Sobre.
struct CreditLine: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.fill").foregroundStyle(Brand.green)
            Text(T("Proudly developed by ", "Orgulhosamente desenvolvido por ")) + Text(Brand.author).fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RefreshButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            if model.isLoading {
                ProgressView().controlSize(.small)
            } else if let updated = model.lastUpdated {
                Text(T("Updated at ", "Atualizado às ") + Fmt.time(updated))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            Button {
                Task { await model.refresh(forceGitHub: true) }
            } label: {
                Label(T("Refresh", "Atualizar"), systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading)
            .keyboardShortcut("r")
            .help(T("Re-read your coding tools and GitHub (⌘R)", "Reler as ferramentas e o GitHub (⌘R)"))
        }
    }
}

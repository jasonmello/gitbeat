import AppKit
import SwiftUI
import GitBeatCore

/// Explica de onde vem cada número, onde o histórico fica guardado e as diferenças que o usuário pode notar.
struct AboutDataView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            PageHeader(title: T("About the data", "Sobre os dados"), subtitle: Brand.name)

            Card(title: T("Where the numbers come from", "De onde vêm os números"), systemImage: "tray.full.fill", tint: Theme.tokens) {
                Paragraph(T("GitBeat reads the session files your AI coding tools already keep on this Mac. It only takes numbers out of them: time, project folder, model and token counts. The text of your conversations is never stored by GitBeat or sent anywhere.",
                       "O GitBeat lê os arquivos de sessão que as suas ferramentas de IA já guardam neste Mac. Ele só tira números deles: horário, pasta do projeto, modelo e quantidade de tokens. O texto das conversas nunca é guardado pelo GitBeat nem enviado a lugar nenhum."))
                VStack(alignment: .leading, spacing: 6) {
                    toolRow(Tool.claudeCode, "~/.claude/projects")
                    toolRow(Tool.openCode, "~/.local/share/opencode")
                    toolRow(Tool.codex, "~/.codex/sessions")
                    toolRow(Tool.gemini, "~/.gemini/tmp")
                }
                Paragraph(T("Cursor and Antigravity keep usage in your online account, so it can't be read from this Mac.",
                       "O Cursor e o Antigravity guardam o uso na sua conta online, então não dá para ler pelo Mac."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Card(title: T("Your history is kept", "Seu histórico fica guardado"), systemImage: "externaldrive.fill.badge.icloud", tint: Theme.time) {
                Paragraph(T("Claude Code deletes conversations older than 30 days by default. GitBeat keeps a permanent copy of the numbers, so your history keeps growing even after the original files are gone.",
                       "O Claude Code apaga conversas com mais de 30 dias, por padrão. O GitBeat guarda uma cópia permanente dos números, então o seu histórico continua crescendo mesmo depois que os arquivos originais somem."))
                place(T("On this Mac", "Neste Mac"), model.historyLocalDir)
                if let cloud = model.historyCloudDir {
                    place("iCloud Drive", cloud)
                    Paragraph(T("Each Mac writes its own folder, so there are no sync conflicts. Open GitBeat on another Mac with the same iCloud account and you'll see both.",
                           "Cada Mac grava a própria pasta, então não há conflito de sincronização. Abra o GitBeat em outro Mac com a mesma conta do iCloud e você verá os dois."))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Label(T("iCloud Drive is off on this Mac, so the history is only kept locally. Turn it on in System Settings → Apple Account → iCloud.",
                            "O iCloud Drive está desligado neste Mac, então o histórico fica só aqui. Ligue em Ajustes do Sistema → Conta Apple → iCloud."),
                          systemImage: "exclamationmark.icloud")
                        .font(.callout)
                }
                Paragraph(T("\(Fmt.int(model.recordCount)) responses saved.", "\(Fmt.int(model.recordCount)) respostas guardadas."))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }

            Card(title: T("Why GitHub may show fewer commits", "Por que o GitHub pode mostrar menos commits"), systemImage: "lock.fill", tint: Theme.github) {
                Paragraph(T("Your GitHub profile calendar only counts private repositories when “Include private contributions on my profile” is on. GitBeat reads each repository's history directly, so private work counts here either way. If you want the green squares on your profile to match, turn that option on in your GitHub profile settings.",
                       "O calendário do seu perfil no GitHub só conta repositórios privados quando a opção “Include private contributions on my profile” está ligada. O GitBeat lê o histórico de cada repositório direto, então o trabalho privado conta aqui de qualquer jeito. Se quiser que os quadradinhos verdes do perfil batam, ligue essa opção nos ajustes do seu perfil no GitHub."))
                Link(T("Open GitHub profile settings", "Abrir ajustes do perfil no GitHub"),
                     destination: URL(string: "https://github.com/settings/profile")!)
                    .font(.callout)
            }

            HStack(alignment: .top, spacing: Theme.gap) {
                Card(title: T("Cost", "Custo"), systemImage: "dollarsign.circle.fill", tint: Theme.cost) {
                    Paragraph(T("What the same usage would cost at Anthropic API list prices (OpenCode records its own cost). On a Pro or Max subscription you don't pay per token.",
                           "Quanto o mesmo uso custaria a preço de API da Anthropic (o OpenCode grava o próprio custo). Na assinatura Pro ou Max você não paga por token."))
                        .font(.callout)
                }
                Card(title: T("Active time", "Tempo ativo"), systemImage: "clock.fill", tint: Theme.time) {
                    Paragraph(T("Gaps of up to 15 minutes between replies count as active. Longer breaks don't, and parallel sessions count once.",
                           "Intervalos de até 15 minutos entre respostas contam como ativos. Pausas maiores não, e sessões em paralelo contam uma vez só."))
                        .font(.callout)
                }
            }

            Card(title: T("Requirements", "Requisitos"), systemImage: "laptopcomputer", tint: .secondary) {
                Paragraph(T("macOS 14 or later; Liquid Glass needs macOS 26. GitHub data needs the GitHub CLI (gh) signed in. You don't need Xcode to use GitBeat — or even to build it: it builds with the free Command Line Tools.",
                       "macOS 14 ou mais novo; o Liquid Glass precisa do macOS 26. Os dados do GitHub precisam do GitHub CLI (gh) logado. Você não precisa do Xcode para usar o GitBeat, nem para compilar: ele compila com as Command Line Tools, que são gratuitas."))
                    .font(.callout)
            }

            CreditLine()
        }
    }

    private func toolRow(_ tool: String, _ path: String) -> some View {
        let found = model.toolsFound.contains(tool)
        let installed = model.toolsInstalled.contains(tool)
        let status = found ? T("Found", "Encontrado")
            : installed ? T("Installed, no usage yet", "Instalado, sem uso ainda")
            : T("Not found", "Não encontrado")
        return HStack(spacing: 8) {
            Image(systemName: found ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(found ? AnyShapeStyle(Brand.green) : AnyShapeStyle(.tertiary))
            Text(Tool.displayName(tool)).fontWeight(.medium)
            Text(path).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            Text(status).eyebrow().foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private func place(_ title: String, _ url: URL) -> some View {
        HStack(spacing: 8) {
            Text(title).fontWeight(.medium)
            Text(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button(T("Show in Finder", "Mostrar no Finder")) {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            .controlSize(.small)
        }
        .font(.callout)
    }
}

/// Parágrafo que quebra em quantas linhas precisar (sem isso, o cartão corta em uma linha).
struct Paragraph: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }
}

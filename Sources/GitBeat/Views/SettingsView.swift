import AppKit
import SwiftUI
import GitBeatCore

/// Ajustes (⌘,): idioma, visual, tema e metas.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label(T("General", "Geral"), systemImage: "gearshape") }
            GoalsForm()
                .padding(.vertical, 8)
                .tabItem { Label(T("Goals", "Metas"), systemImage: "target") }
        }
        .frame(width: 480)
        .padding(20)
    }
}

struct GeneralSettings: View {
    var body: some View {
        @Bindable var prefs = Preferences.shared
        Form {
            Picker(T("Language", "Idioma"), selection: $prefs.language) {
                ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            Picker(T("Look", "Visual"), selection: $prefs.style) {
                ForEach(VisualStyle.allCases) { Text($0.title).tag($0) }
            }
            if prefs.style == .glass, !prefs.usesGlass {
                Text(T("Liquid Glass needs macOS 26 or later. Showing Classic.",
                       "Liquid Glass precisa do macOS 26 ou mais novo. Mostrando o Clássico."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker(T("Appearance", "Aparência"), selection: $prefs.mode) {
                ForEach(ThemeMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            SwiftUI.Section(T("Cost", "Custo")) {
                CurrencyRows()
            }
            SwiftUI.Section(T("Startup", "Inicialização")) {
                LoginItemRow()
            }
            SwiftUI.Section(T("Notifications", "Notificações")) {
                NotificationRows()
            }
            CreditLine().padding(.top, 6)
        }
        .formStyle(.grouped)
    }
}

/// Abrir no login, refletindo o estado real do sistema (o usuário pode mudar em Ajustes do Sistema).
struct LoginItemRow: View {
    @ViewState private var status = LoginItem.status

    var body: some View {
        Toggle(T("Open GitBeat at login", "Abrir o GitBeat ao iniciar o Mac"), isOn: Binding(
            get: { status == .enabled || status == .needsApproval },
            set: { LoginItem.set($0); status = LoginItem.status }))
            .disabled(status == .unavailable)
            .onAppear { status = LoginItem.status }
        switch status {
        case .needsApproval:
            HStack {
                Text(T("macOS is waiting for your approval in Login Items.", "O macOS está esperando sua aprovação em Itens de Início."))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(T("Open Login Items", "Abrir Itens de Início")) { LoginItem.openSystemSettings() }
                    .controlSize(.small)
            }
        case .unavailable:
            Text(T("Available when GitBeat runs as an installed app.", "Disponível quando o GitBeat roda como app instalado."))
                .font(.caption).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }
}

struct NotificationRows: View {
    @Environment(AppModel.self) private var model
    @ViewState private var denied = false
    @ViewState private var blocked = false

    var body: some View {
        @Bindable var prefs = Preferences.shared
        Toggle(T("When I close all three rings", "Quando eu fechar os três anéis"), isOn: $prefs.notifyRings)
        Toggle(T("Before my streak ends", "Antes de a sequência acabar"), isOn: $prefs.notifyStreak)
        if prefs.notifyStreak {
            Picker(T("Reminder time", "Horário do lembrete"), selection: $prefs.reminderHour) {
                ForEach(17...23, id: \.self) { h in
                    Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date())
                        .map { $0.formatted(.dateTime.hour().minute().locale(Fmt.locale)) } ?? "\(h)h").tag(h)
                }
            }
        }
        if blocked {
            Label(T("macOS isn't letting this copy of GitBeat send notifications. This usually happens with apps signed only on this Mac, and goes away once GitBeat is signed with an Apple Developer ID. Meanwhile, the menu bar icon turns into a flame when your streak is at risk.",
                    "O macOS não está deixando esta cópia do GitBeat mandar notificações. Isso costuma acontecer com apps assinados só neste Mac, e some quando o GitBeat for assinado com um Apple Developer ID. Enquanto isso, o ícone da barra de menu vira uma chama quando a sequência está em risco."),
                  systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if denied {
            HStack {
                Text(T("Notifications for GitBeat are off in System Settings.", "As notificações do GitBeat estão desligadas nos Ajustes do Sistema."))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(T("Open Notifications", "Abrir Notificações")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
        EmptyView()
            .task(id: "\(prefs.notifyRings)\(prefs.notifyStreak)\(prefs.reminderHour)") {
                if prefs.notifyRings || prefs.notifyStreak {
                    if case .blockedBySystem = await Notifier.shared.requestPermissionResult() { blocked = true }
                }
                denied = await Notifier.shared.authorizationStatus() == .denied
                Notifier.shared.update(with: model)
            }
    }
}

/// Moeda do custo equivalente. Real pede a cotação do dólar, informada pelo usuário.
struct CurrencyRows: View {
    var body: some View {
        @Bindable var prefs = Preferences.shared
        Picker(T("Show cost in", "Mostrar custo em"), selection: $prefs.currency) {
            ForEach(CostCurrency.allCases) { Text($0.title).tag($0) }
        }
        if prefs.currency == .brl {
            TextField(T("R$ per US$ 1", "R$ por US$ 1"), value: $prefs.brlPerUSD,
                      format: .number.precision(.fractionLength(0...4)).locale(Fmt.locale))
                .multilineTextAlignment(.trailing)
            Text(prefs.brlPerUSD > 0
                 ? T("Prices come from the API in dollars and are converted with this rate. Update it when you like; GitBeat doesn't look it up online.",
                     "Os preços da API são em dólar e são convertidos com esta cotação. Atualize quando quiser; o GitBeat não busca cotação na internet.")
                 : T("Enter the dollar rate to see costs in reais. Until then, they stay in dollars.",
                     "Informe a cotação do dólar para ver o custo em reais. Até lá, ele continua em dólar."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

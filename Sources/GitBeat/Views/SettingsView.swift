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
        .frame(width: 460)
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
            CreditLine().padding(.top, 6)
        }
        .formStyle(.grouped)
    }
}

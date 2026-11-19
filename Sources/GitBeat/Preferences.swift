import Observation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, pt
    var id: String { rawValue }
    var locale: Locale { Locale(identifier: self == .en ? "en_US" : "pt_BR") }
    var displayName: String { self == .en ? "English" : "Português" }
}

/// Liquid Glass é o visual oficial; Clássico usa cartões sólidos (e é o que aparece antes do macOS 26).
enum VisualStyle: String, CaseIterable, Identifiable {
    case glass, classic
    var id: String { rawValue }
    var title: String { self == .glass ? "Liquid Glass" : T("Classic", "Clássico") }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: T("Automatic", "Automático")
        case .light: T("Light", "Claro")
        case .dark: T("Dark", "Escuro")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Preferências de aparência e idioma, guardadas em UserDefaults.
/// Como é `@Observable`, qualquer tela que chame `T(...)` redesenha ao trocar o idioma.
@Observable
final class Preferences {
    static let shared = Preferences()

    var language: AppLanguage { didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") } }
    var style: VisualStyle { didSet { UserDefaults.standard.set(style.rawValue, forKey: "style") } }
    var mode: ThemeMode { didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") } }
    var notifyRings: Bool { didSet { UserDefaults.standard.set(notifyRings, forKey: "notifyRings") } }
    var notifyStreak: Bool { didSet { UserDefaults.standard.set(notifyStreak, forKey: "notifyStreak") } }
    /// Hora do lembrete de sequência (0–23).
    var reminderHour: Int { didSet { UserDefaults.standard.set(reminderHour, forKey: "reminderHour") } }

    init() {
        let d = UserDefaults.standard
        language = d.string(forKey: "language").flatMap(AppLanguage.init) ?? .en
        style = d.string(forKey: "style").flatMap(VisualStyle.init) ?? .glass
        mode = d.string(forKey: "mode").flatMap(ThemeMode.init) ?? .system
        notifyRings = d.object(forKey: "notifyRings") as? Bool ?? true
        notifyStreak = d.object(forKey: "notifyStreak") as? Bool ?? true
        reminderHour = d.object(forKey: "reminderHour") as? Int ?? 21
    }

    /// Liquid Glass só existe a partir do macOS 26.
    var usesGlass: Bool {
        guard style == .glass else { return false }
        if #available(macOS 26, *) { return true }
        return false
    }
}

/// Texto nos dois idiomas, lado a lado. Inglês é o original.
func T(_ en: String, _ pt: String) -> String {
    Preferences.shared.language == .pt ? pt : en
}

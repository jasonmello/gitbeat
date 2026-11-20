import AppKit
import ServiceManagement
import UserNotifications
import GitBeatCore

/// Abrir no login e notificações. As duas exigem rodar como .app (com bundle identifier);
/// por `swift run` elas ficam desligadas em vez de travar o app.
enum SystemIntegration {
    static var isBundledApp: Bool { Bundle.main.bundleIdentifier != nil }
}

// MARK: abrir no login

enum LoginItem {
    enum Status { case enabled, disabled, needsApproval, unavailable }

    static var status: Status {
        guard SystemIntegration.isBundledApp else { return .unavailable }
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .needsApproval
        case .notRegistered, .notFound: return .disabled
        @unknown default: return .disabled
        }
    }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        guard SystemIntegration.isBundledApp else { return false }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }

    /// Na primeira abertura como .app, liga sozinho (o usuário pode desligar nos Ajustes).
    static func enableOnFirstLaunch() {
        let key = "loginItemConfigured"
        guard SystemIntegration.isBundledApp, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        if status == .disabled { set(true) }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

// MARK: notificações

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private static let streakID = "streak-reminder"
    private static let lastRingsKey = "lastRingsNotifiedDay"

    private var center: UNUserNotificationCenter? {
        SystemIntegration.isBundledApp ? UNUserNotificationCenter.current() : nil
    }

    func start() {
        guard let center else { return }
        center.delegate = self
        let prefs = Preferences.shared
        if prefs.notifyRings || prefs.notifyStreak { requestPermission() }
    }

    func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { NSLog("GitBeat: notification permission error: %@", error.localizedDescription) }
        }
    }

    enum PermissionResult: CustomStringConvertible {
        case granted, notGranted, blockedBySystem, unavailable, failed(String)
        var description: String {
            switch self {
            case .granted: "granted"
            case .notGranted: "not granted"
            case .blockedBySystem: "blocked by macOS (app not allowed to send notifications)"
            case .unavailable: "unavailable"
            case .failed(let msg): "error: \(msg)"
            }
        }
    }

    /// Pede a permissão e devolve o resultado. `blockedBySystem` é o que acontece com o app
    /// assinado só localmente (ver docs/decisoes.md).
    func requestPermissionResult() async -> PermissionResult {
        guard let center else { return .unavailable }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound]) ? .granted : .notGranted
        } catch let error as UNError where error.code == .notificationsNotAllowed {
            return .blockedBySystem
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus? {
        guard let center else { return nil }
        return await center.notificationSettings().authorizationStatus
    }

    /// Chamado depois de cada atualização dos dados.
    func update(with model: AppModel) {
        guard let center else { return }
        let prefs = Preferences.shared
        let today = model.todayKey
        let r = model.rings(on: today)
        let state = NotificationPlanner.State(
            now: Date(), todayKey: today,
            allRingsClosed: r.tokens >= 1 && r.hours >= 1 && r.commits >= 1,
            todayActive: model.activeDays.contains(today),
            streak: model.currentStreak,
            lastRingsNotifiedDay: UserDefaults.standard.string(forKey: Self.lastRingsKey),
            notifyRings: prefs.notifyRings, notifyStreak: prefs.notifyStreak, reminderHour: prefs.reminderHour)
        let plan = NotificationPlanner.plan(state, calendar: model.days.calendar)

        if plan.postRingsClosed {
            UserDefaults.standard.set(today, forKey: Self.lastRingsKey)
            post(id: "rings-\(today)",
                 title: T("All three rings closed", "Três anéis fechados"),
                 body: T("Tokens, time and commits: you hit every goal today.",
                         "Tokens, tempo e commits: você bateu todas as metas hoje."),
                 trigger: nil)
        }

        center.removePendingNotificationRequests(withIdentifiers: [Self.streakID])
        if let at = plan.streakReminderAt {
            let comps = model.days.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            let n = state.streak
            post(id: Self.streakID,
                 title: T("Keep your streak going", "Não perca a sequência"),
                 body: T("Your \(n)-day streak ends today. Code with AI or push a commit to keep it.",
                         "Sua sequência de \(n) \(n == 1 ? "dia" : "dias") termina hoje. Programe com IA ou faça um commit para manter."),
                 trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        }
    }

    private func post(id: String, title: String, body: String, trigger: UNNotificationTrigger?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center?.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Mostra o aviso mesmo com o app aberto.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

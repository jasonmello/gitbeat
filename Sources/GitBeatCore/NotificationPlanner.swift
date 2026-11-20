import Foundation

/// Decide quais notificações mandar, sem falar com o sistema (o app executa a decisão).
///
/// - Anéis fechados: uma vez por dia, quando os três anéis passam de 100%.
/// - Sequência em risco: lembrete agendado para o horário escolhido, se hoje ainda não teve
///   atividade e existe uma sequência para perder. Cancelado assim que hoje ganha atividade.
public enum NotificationPlanner {
    public struct State: Equatable, Sendable {
        public var now: Date
        public var todayKey: String
        public var allRingsClosed: Bool
        public var todayActive: Bool
        /// Sequência contando até ontem quando hoje ainda está vazio.
        public var streak: Int
        public var lastRingsNotifiedDay: String?
        public var notifyRings: Bool
        public var notifyStreak: Bool
        public var reminderHour: Int

        public init(now: Date, todayKey: String, allRingsClosed: Bool, todayActive: Bool, streak: Int,
                    lastRingsNotifiedDay: String?, notifyRings: Bool, notifyStreak: Bool, reminderHour: Int) {
            self.now = now
            self.todayKey = todayKey
            self.allRingsClosed = allRingsClosed
            self.todayActive = todayActive
            self.streak = streak
            self.lastRingsNotifiedDay = lastRingsNotifiedDay
            self.notifyRings = notifyRings
            self.notifyStreak = notifyStreak
            self.reminderHour = reminderHour
        }
    }

    public struct Plan: Equatable, Sendable {
        public var postRingsClosed = false
        /// Quando agendar o lembrete da sequência; `nil` = nenhum lembrete pendente.
        public var streakReminderAt: Date?
    }

    public static func plan(_ s: State, calendar: Calendar) -> Plan {
        var plan = Plan()
        plan.postRingsClosed = s.notifyRings && s.allRingsClosed && s.lastRingsNotifiedDay != s.todayKey

        if s.notifyStreak, !s.todayActive, s.streak >= 1,
           let at = calendar.date(bySettingHour: s.reminderHour, minute: 0, second: 0, of: s.now),
           at > s.now {
            plan.streakReminderAt = at
        }
        return plan
    }
}

// Vindo do kit do mascote v2 (integration/GitBeatActivityMeter.swift), sem mudança de lógica.
// Mede a atividade RECENTE a partir de um total cumulativo (o total de hoje): o número na barra
// mostra o total; o movimento do mascote mostra o ritmo dos últimos minutos.
import Foundation

/// Rolling activity from cumulative token snapshots. Counts are not used as a score.
public struct ActivityMeter {
    public enum Level: String, CaseIterable { case idle, flowing, busy, burst }
    public struct Configuration {
        public var window: TimeInterval = 60
        public var busyTokens: Int64 = 100_000
        public var burstTokens: Int64 = 500_000
        public var minimumDwell: TimeInterval = 2
        public init() {}
    }
    public let configuration: Configuration
    public private(set) var totalTokens: Int64 = 0
    private var previous: (count: Int64, date: Date)?
    private var events: [(date: Date, count: Int64)] = []
    private var current: Level = .idle
    private var changedAt: Date?

    public init(configuration: Configuration = Configuration()) {
        precondition(configuration.window > 0)
        precondition(configuration.busyTokens > 0 && configuration.burstTokens > configuration.busyTokens)
        precondition(configuration.minimumDwell >= 0)
        self.configuration = configuration
    }

    /// Supply the SAME cumulative series every time (e.g. today's total).
    /// The first snapshot establishes a baseline; a counter reset clears activity.
    /// Snapshots spanning more than the window establish a new baseline, since
    /// their delta cannot be reliably attributed to the last 60 seconds.
    public mutating func observe(totalTokens count: Int64, at date: Date = Date(), countActivity: Bool = true) {
        guard count >= 0 else { return }
        if let old = previous, date < old.date { return }
        totalTokens = count
        if let old = previous {
            let gap = date.timeIntervalSince(old.date)
            if count < old.count || gap > configuration.window || !countActivity {
                clearActivity()
            } else if count > old.count {
                events.append((date, count - old.count))
            }
        }
        previous = (count, date)
        prune(at: date)
    }

    public mutating func clearActivity() {
        events.removeAll()
        current = .idle
        changedAt = nil
    }

    private mutating func prune(at date: Date) {
        let cutoff = date.addingTimeInterval(-configuration.window)
        events.removeAll { $0.date <= cutoff }
    }

    /// Token count observed within the rolling window, not an extrapolation.
    public mutating func recentTokens(at date: Date = Date()) -> Int64 {
        prune(at: date)
        return events.reduce(Int64(0)) { sum, event in
            let result = sum.addingReportingOverflow(event.count)
            return result.overflow ? Int64.max : result.partialValue
        }
    }

    public mutating func level(at date: Date = Date()) -> Level {
        let count = recentTokens(at: date)
        let target: Level = count >= configuration.burstTokens ? .burst
            : count >= configuration.busyTokens ? .busy : count > 0 ? .flowing : .idle
        // Zero activity always returns to quiet immediately. Short dwell prevents
        // rapid active-state oscillation around thresholds.
        if target == .idle || target != current && (changedAt == nil || date.timeIntervalSince(changedAt!) >= configuration.minimumDwell) {
            if target != current { changedAt = date }
            current = target
        }
        return current
    }
}

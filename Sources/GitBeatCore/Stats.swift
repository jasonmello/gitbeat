import Foundation

/// Dias são chaves "aaaa-mm-dd" no fuso local, iguais às do calendário do GitHub.
public struct DayKeys: Sendable {
    public let calendar: Calendar
    private let formatter: DateFormatter

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        formatter = f
    }

    public func key(_ date: Date) -> String { formatter.string(from: date) }

    /// As chaves de muitas datas de uma vez. Formatar data é caro; aqui só formata quando a data
    /// sai do dia anterior, então uma lista em ordem de tempo custa uma formatação por dia, não por item.
    public func keys(_ dates: [Date]) -> [String] {
        var out: [String] = []
        out.reserveCapacity(dates.count)
        var window: DateInterval?
        var current = ""
        for d in dates {
            if let w = window, d >= w.start, d < w.end {
                out.append(current)
                continue
            }
            current = key(d)
            window = calendar.dateInterval(of: .day, for: d)
            out.append(current)
        }
        return out
    }
    public func date(_ key: String) -> Date? { formatter.date(from: key) }
    public func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    /// As chaves dos `count` dias que terminam em `end` (inclusive), do mais antigo ao mais novo.
    public func lastDays(_ count: Int, endingAt end: Date) -> [String] {
        let start = startOfDay(end)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: start).map(key)
        }
    }
}

public struct TokenTotals: Equatable, Sendable {
    public var input = 0
    public var output = 0
    public var cacheWrite = 0
    public var cacheRead = 0
    public var cost = 0.0
    public var responses = 0

    public init() {}

    public var total: Int { input + output + cacheWrite + cacheRead }

    public mutating func add(_ r: UsageRecord) {
        input += r.input
        output += r.output
        cacheWrite += r.cacheWrite
        cacheRead += r.cacheRead
        cost += Pricing.cost(of: r) ?? 0
        responses += 1
    }

    public mutating func add(_ o: TokenTotals) {
        input += o.input
        output += o.output
        cacheWrite += o.cacheWrite
        cacheRead += o.cacheRead
        cost += o.cost
        responses += o.responses
    }
}

public enum Stats {
    /// `keys`: as chaves de dia já calculadas (`DayKeys.keys`), na mesma ordem de `records`.
    public static func tokensByDay(_ records: [UsageRecord], days: DayKeys, keys: [String]? = nil) -> [String: TokenTotals] {
        let keys = keys ?? days.keys(records.map(\.timestamp))
        var out: [String: TokenTotals] = [:]
        for (r, k) in zip(records, keys) { out[k, default: TokenTotals()].add(r) }
        return out
    }

    /// Soma por uma chave (projeto, modelo) dentro de um conjunto de dias. Maior primeiro.
    public static func breakdown(_ records: [UsageRecord], days: DayKeys, in dayKeys: Set<String>,
                                 by key: (UsageRecord) -> String) -> [(name: String, totals: TokenTotals)] {
        var out: [String: TokenTotals] = [:]
        for r in records where dayKeys.contains(days.key(r.timestamp)) {
            out[key(r), default: TokenTotals()].add(r)
        }
        return out.map { (name: $0.key, totals: $0.value) }.sorted { $0.totals.total > $1.totals.total }
    }

    /// Soma um mapa diário dentro de um conjunto de dias.
    public static func sum<V>(_ map: [String: V], over keys: [String], zero: V, _ add: (V, V) -> V) -> V {
        keys.reduce(zero) { acc, k in map[k].map { add(acc, $0) } ?? acc }
    }
}

/// Tempo com o Claude Code ativo: soma dos intervalos entre respostas que ficam abaixo de `maxGap`.
/// Sessões em paralelo não contam em dobro, porque tudo vira uma linha do tempo só.
public enum SessionTime {
    public static let defaultGap: TimeInterval = 15 * 60

    public static func activeSecondsByDay(_ timestamps: [Date], days: DayKeys,
                                          maxGap: TimeInterval = defaultGap) -> [String: Double] {
        let sorted = timestamps.sorted()
        let keys = days.keys(sorted)
        var out: [String: Double] = [:]
        for i in sorted.indices.dropLast() {
            let gap = sorted[i + 1].timeIntervalSince(sorted[i])
            if gap > 0, gap <= maxGap { out[keys[i], default: 0] += gap }
        }
        return out
    }

    /// Quantas respostas caíram em cada hora do dia (0–23).
    public static func responsesByHour(_ timestamps: [Date], calendar: Calendar) -> [Int] {
        var hours = Array(repeating: 0, count: 24)
        for t in timestamps { hours[calendar.component(.hour, from: t)] += 1 }
        return hours
    }
}

/// Metas diárias, desenhadas como anéis.
public struct Goals: Codable, Equatable, Sendable {
    public var tokens: Int
    public var hours: Double
    public var commits: Int

    public init(tokens: Int, hours: Double, commits: Int) {
        self.tokens = tokens
        self.hours = hours
        self.commits = commits
    }

    public static let standard = Goals(tokens: 400_000_000, hours: 4, commits: 3)
}

public enum Streaks {
    /// Dias seguidos com atividade, terminando hoje. Se hoje ainda está vazio, conta até ontem
    /// (o dia não acabou, a sequência não quebrou).
    public static func current(activeDays: Set<String>, today: Date, days: DayKeys) -> Int {
        var day = days.startOfDay(today)
        if !activeDays.contains(days.key(day)) {
            guard let y = days.calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var count = 0
        while activeDays.contains(days.key(day)) {
            count += 1
            guard let prev = days.calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    public static func longest(activeDays: Set<String>, days: DayKeys) -> Int {
        let dates = activeDays.compactMap(days.date).map(days.startOfDay).sorted()
        var best = 0, run = 0
        var previous: Date?
        for d in dates {
            if let p = previous, days.calendar.dateComponents([.day], from: p, to: d).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = d
        }
        return best
    }
}

/// Faixas de tempo dos gráficos: semana e mês por dia, 6 meses por semana, ano por mês.
public enum Period: String, CaseIterable, Identifiable, Sendable {
    case week = "S", month = "M", sixMonths = "6M", year = "A"
    public var id: String { rawValue }


    public struct Bucket: Identifiable, Sendable {
        public var start: Date
        public var dayKeys: [String]
        public var id: Date { start }
    }

    public func buckets(endingAt today: Date, days: DayKeys) -> [Bucket] {
        let cal = days.calendar
        switch self {
        case .week, .month:
            let count = self == .week ? 7 : 30
            return days.lastDays(count, endingAt: today).compactMap { k in
                days.date(k).map { Bucket(start: $0, dayKeys: [k]) }
            }
        case .sixMonths:
            let all = days.lastDays(26 * 7, endingAt: today)
            return stride(from: 0, to: all.count, by: 7).compactMap { i in
                let slice = Array(all[i..<min(i + 7, all.count)])
                return slice.first.flatMap(days.date).map { Bucket(start: $0, dayKeys: slice) }
            }
        case .year:
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
            return (0..<12).reversed().compactMap { offset in
                guard let start = cal.date(byAdding: .month, value: -offset, to: thisMonth),
                      let range = cal.range(of: .day, in: .month, for: start) else { return nil }
                let keys = range.compactMap { d -> String? in
                    guard let date = cal.date(byAdding: .day, value: d - 1, to: start), date <= today else { return nil }
                    return days.key(date)
                }
                return Bucket(start: start, dayKeys: keys)
            }
        }
    }

}

extension Stats {
    /// Totais por dia e por uma chave (projeto, modelo). Calculado uma vez, somado depois para qualquer período.
    public static func tokensByDay(_ records: [UsageRecord], days: DayKeys, keys: [String]? = nil,
                                   groupedBy key: (UsageRecord) -> String) -> [String: [String: TokenTotals]] {
        let keys = keys ?? days.keys(records.map(\.timestamp))
        var out: [String: [String: TokenTotals]] = [:]
        for (r, k) in zip(records, keys) { out[k, default: [:]][key(r), default: TokenTotals()].add(r) }
        return out
    }

    /// Soma os grupos dentro dos dias pedidos. Maior primeiro.
    public static func breakdown(_ byDay: [String: [String: TokenTotals]], over keys: [String]) -> [(name: String, totals: TokenTotals)] {
        var out: [String: TokenTotals] = [:]
        for k in keys {
            for (name, t) in byDay[k] ?? [:] { out[name, default: TokenTotals()].add(t) }
        }
        return out.map { (name: $0.key, totals: $0.value) }.sorted { $0.totals.total > $1.totals.total }
    }
}

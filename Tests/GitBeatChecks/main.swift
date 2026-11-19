import Foundation
import GitBeatCore

// Checagens do núcleo. Rodam sem Xcode: `swift run GitBeatChecks`.
// (As Command Line Tools não trazem o plugin de macros do Swift Testing.)

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0

func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition() {
        failures += 1
        print("FALHOU \(file):\(line)")
    }
}

struct Missing: Error {}
func req<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let value else { print("FALHOU (nil) \(file):\(line)"); failures += 1; throw Missing() }
    return value
}

func run(_ name: String, _ body: () throws -> Void) {
    do { try body() } catch { failures += 1; print("ERRO em \(name): \(error)") }
}

private let saoPaulo: DayKeys = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return DayKeys(calendar: cal)
}()

private func line(id: String = "msg_1", ts: String = "2026-11-19T22:21:35.577Z", model: String = "claude-opus-5-5",
                  cwd: String = "/Users/x/Developer/semear", input: Int = 2, output: Int = 663,
                  create: Int = 38765, w1h: Int = 38765, read: Int = 46622, type: String = "assistant") -> Data {
    let json = """
    {"type":"\(type)","timestamp":"\(ts)","cwd":"\(cwd)","message":{"id":"\(id)","model":"\(model)","usage":\
    {"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":\(create),\
    "cache_read_input_tokens":\(read),"cache_creation":{"ephemeral_1h_input_tokens":\(w1h),"ephemeral_5m_input_tokens":0}}}}
    """
    return Data(json.utf8)
}

enum ParserTests {
    static func readsUsageFromAssistantLine() throws {
        let r = try req(ClaudeLogParser.parse(line: line()))
        expect(r.id == "msg_1")
        expect(r.project == "semear")
        expect(r.output == 663)
        expect(r.cacheWrite1h == 38765)
        expect(r.cacheWrite5m == 0)
        expect(r.cacheRead == 46622)
        expect(r.totalTokens == 2 + 663 + 38765 + 46622)
    }

    static func ignoresUserAndSyntheticLines() {
        expect(ClaudeLogParser.parse(line: line(type: "user")) == nil)
        expect(ClaudeLogParser.parse(line: line(model: "<synthetic>")) == nil)
        expect(ClaudeLogParser.parse(line: Data("não é json".utf8)) == nil)
    }

    static func projectNames() {
        expect(ClaudeLogParser.projectName(fromCWD: "/Users/x/Documents/Dental Course Hub/.claude/worktrees/onda-a") == "Dental Course Hub")
        expect(ClaudeLogParser.projectName(fromCWD: "/Users/x/Library/Application Support/Claude/scratch-workspaces/a/b") == "Sem pasta")
        expect(ClaudeLogParser.projectName(fromCWD: nil) == "Sem pasta")
    }
}

enum StoreTests {
    static func dedupesRepeatedMessageIds() {
        let a = ClaudeLogParser.parse(line: line(id: "a"))!
        let b = ClaudeLogParser.parse(line: line(id: "b"))!
        expect(UsageStore.dedupe([a, a, b, a]).count == 2)
    }

    static func readsIncrementallyAndKeepsPartialLineForLater() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = dir.appendingPathComponent("projects/p")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let file = project.appendingPathComponent("s.jsonl")
        var content = line(id: "a") + Data("\n".utf8) + Data("{\"type\":\"user\"}\n".utf8)
        try content.write(to: file)

        let store = UsageStore(root: dir.appendingPathComponent("projects"), cacheURL: dir.appendingPathComponent("cache.json"))
        expect(store.refresh().map(\.id) == ["a"])

        // linha ainda sendo escrita: sem \n no fim
        content += line(id: "b", ts: "2026-11-19T23:00:00Z")
        try content.write(to: file)
        expect(store.refresh().map(\.id) == ["a"])

        content += Data("\n".utf8)
        try content.write(to: file)
        expect(store.refresh().map(\.id) == ["a", "b"])

        // um store novo lê do cache em disco, mesmo se o arquivo sumir
        try FileManager.default.removeItem(at: file)
        let reopened = UsageStore(root: dir.appendingPathComponent("projects"), cacheURL: dir.appendingPathComponent("cache.json"))
        expect(reopened.refresh().map(\.id) == ["a", "b"])
    }
}

enum PricingTests {
    static func opusCost() throws {
        let r = UsageRecord(id: "x", timestamp: Date(), project: "p", model: "claude-opus-5-5",
                            input: 1_000_000, output: 1_000_000, cacheWrite5m: 1_000_000, cacheWrite1h: 1_000_000, cacheRead: 1_000_000)
        // 4 + 20 + 5 + 8 + 0,20
        let cost = try req(Pricing.cost(of: r))
        expect(abs(cost - 37.2) < 0.0001)
    }

    static func longestPrefixWins() {
        expect(Pricing.price(for: "claude-opus-5-5")?.input == 4)
        expect(Pricing.price(for: "claude-opus-5")?.input == 5)
        expect(Pricing.price(for: "claude-fable-5-2")?.read == 0.20)
        expect(Pricing.price(for: "gpt-5") == nil)
    }

    static func displayNames() {
        expect(Pricing.displayName(for: "claude-opus-5-5") == "Opus 5.5")
        expect(Pricing.displayName(for: "claude-haiku-4-5-20251001") == "Haiku 4.5")
    }
}

enum StatsTests {
    static func dayKeyUsesLocalTimezone() {
        // 01:30 UTC do dia 20 ainda é dia 19 em São Paulo (UTC-3)
        let d = ClaudeLogParser.parseDate("2026-11-20T01:30:00Z")!
        expect(saoPaulo.key(d) == "2026-11-19")
    }

    static func sessionTimeIgnoresLongGapsAndOverlap() {
        let t0 = ClaudeLogParser.parseDate("2026-11-19T12:00:00Z")!
        let stamps = [0, 60, 120, 120, 3600, 3660].map { t0.addingTimeInterval(TimeInterval($0)) }
        let secs = SessionTime.activeSecondsByDay(stamps, days: saoPaulo)
        expect(secs["2026-11-19"] == 180) // 60 + 60 + (0) + pausa de 58 min ignorada + 60
    }

    static func streaks() {
        let today = saoPaulo.date("2026-11-19")!
        let active: Set = ["2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-10", "2026-11-11"]
        expect(Streaks.current(activeDays: active, today: today, days: saoPaulo) == 4) // hoje vazio: conta até ontem
        expect(Streaks.current(activeDays: active.union(["2026-11-19"]), today: today, days: saoPaulo) == 5)
        expect(Streaks.current(activeDays: ["2026-11-10"], today: today, days: saoPaulo) == 0)
        expect(Streaks.longest(activeDays: active, days: saoPaulo) == 4)
    }

    static func periodBuckets() {
        let today = saoPaulo.date("2026-11-19")!
        expect(Period.week.buckets(endingAt: today, days: saoPaulo).count == 7)
        expect(Period.week.buckets(endingAt: today, days: saoPaulo).last?.dayKeys == ["2026-11-19"])
        let year = Period.year.buckets(endingAt: today, days: saoPaulo)
        expect(year.count == 12)
        expect(year.last?.dayKeys.count == 19) // novembro até hoje
        expect(Period.sixMonths.buckets(endingAt: today, days: saoPaulo).count == 26)
    }
}

enum GitHubTests {
    static func parsesHistory() throws {
        let json = """
        {"data":{"viewer":{"repositories":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[
          {"nameWithOwner":"jm/a","defaultBranchRef":{"target":{"history":{"nodes":[
            {"authoredDate":"2026-11-17T15:00:00Z"},{"authoredDate":"2026-11-18T01:00:00Z"}]}}}},
          {"nameWithOwner":"jm/b","defaultBranchRef":{"target":{"history":{"nodes":[{"authoredDate":"2026-11-17T12:00:00Z"}]}}}},
          {"nameWithOwner":"jm/vazio","defaultBranchRef":null}
        ]}}}}
        """
        let page = try GitHubParser.parseHistory(Data(json.utf8), days: saoPaulo)
        let snap = GitHubSnapshot(login: "jm", fetchedAt: Date(), commits: page.commits, pullRequests: [])
        // 01:00 UTC do dia 18 é dia 17 em São Paulo
        expect(snap.commitsOn("2026-11-17") == 3)
        expect(snap.commitsOn("2026-11-18") == 0)
        expect(page.commits["2026-11-17"]?["jm/a"] == 2)
        expect(!page.hasNextPage)
    }

    static func parsesPRPage() throws {
        let json = """
        {"data":{"search":{"pageInfo":{"hasNextPage":true,"endCursor":"Y3"},"nodes":[
          {"title":"Nova tela","createdAt":"2026-11-19T22:29:16Z","mergedAt":"2026-11-19T22:32:15Z","repository":{"nameWithOwner":"jm/a"}},
          {"title":"Aberto","createdAt":"2026-11-18T10:00:00Z","mergedAt":null,"repository":{"nameWithOwner":"jm/b"}},
          {}
        ]}}}
        """
        let page = try GitHubParser.parsePRs(Data(json.utf8))
        expect(page.items.count == 2)
        expect(page.hasNextPage && page.endCursor == "Y3")
        let snap = GitHubSnapshot(login: "jm", fetchedAt: Date(), commits: [:], pullRequests: page.items)
        expect(snap.prsMerged(on: "2026-11-19", days: saoPaulo) == 1)
        expect(snap.prsOpened(on: "2026-11-18", days: saoPaulo) == 1)
    }
}

enum OtherToolTests {
    static func codexUsesCumulativeDeltas() {
        let lines = [
            #"{"timestamp":"2026-11-19T10:00:00Z","type":"session_meta","payload":{"id":"s1","cwd":"/Users/x/Developer/semear"}}"#,
            #"{"timestamp":"2026-11-19T10:00:01Z","type":"turn_context","payload":{"cwd":"/Users/x/Developer/semear","model":"gpt-5"}}"#,
            #"{"timestamp":"2026-11-19T10:00:05Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":50,"reasoning_output_tokens":20,"total_tokens":1050},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":50}}}}"#,
            #"{"timestamp":"2026-11-19T10:00:06Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":50,"total_tokens":1050}}}}"#,
            #"{"timestamp":"2026-11-19T10:01:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":2500,"cached_input_tokens":1900,"output_tokens":120,"total_tokens":2620}}}}"#,
            #"{"timestamp":"2026-11-19T10:01:01Z","type":"event_msg","payload":{"type":"token_count","info":null}}"#,
        ]
        let records = CodexParser.parse(fileContents: Data(lines.joined(separator: "\n").utf8), fileID: "f")
        expect(records.count == 2)                    // o evento repetido não conta
        expect(records.first?.input == 200)           // 1000 - 800 em cache
        expect(records.first?.cacheRead == 800)
        expect(records.last?.output == 70)            // 120 - 50
        expect(records.last?.input == 400)            // (2500-1000) - (1900-800)
        expect(records.first?.model == "gpt-5")
        expect(records.first?.project == "semear")
        expect(records.first?.tool == Tool.codex)
    }

    static func geminiKeepsLastLinePerID() {
        let lines = [
            #"{"sessionId":"abc","projectHash":"x","startTime":"2026-11-19T10:00:00Z"}"#,
            #"{"id":"u1","timestamp":"2026-11-19T10:00:01Z","type":"user","content":"oi"}"#,
            #"{"id":"g1","timestamp":"2026-11-19T10:00:02Z","type":"gemini","model":"gemini-2.5-pro","content":"..."}"#,
            #"{"id":"g1","timestamp":"2026-11-19T10:00:02Z","type":"gemini","model":"gemini-2.5-pro","tokens":{"input":1000,"output":100,"cached":600,"thoughts":40,"tool":10,"total":1150}}"#,
        ]
        let records = GeminiParser.parse(fileContents: Data(lines.joined(separator: "\n").utf8), project: "semear")
        expect(records.count == 1)
        expect(records.first?.input == 410)    // 1000 - 600 + 10
        expect(records.first?.output == 140)   // 100 + 40 de raciocínio
        expect(records.first?.cacheRead == 600)
        expect(records.first?.tool == Tool.gemini)
    }

    static func openCodeMessageShapes() {
        let new: [String: Any] = ["model": ["id": "claude-opus-5-5", "providerID": "anthropic"], "cost": 0.12,
                                  "tokens": ["input": 10, "output": 200, "reasoning": 30, "cache": ["read": 5000, "write": 100]],
                                  "time": ["created": 1_763_550_000_000]]
        let r = OpenCodeReader.record(fromMessage: new, id: "msg_1", directory: "/Users/x/Developer/semear")
        expect(r?.output == 230)
        expect(r?.cacheRead == 5000)
        expect(r?.costUSD == 0.12)
        expect(r?.project == "semear")
        expect(r.map { Pricing.cost(of: $0) } == 0.12) // custo gravado vence a tabela

        let legacy: [String: Any] = ["role": "assistant", "modelID": "gpt-5", "path": ["cwd": "/tmp/projeto"],
                                     "tokens": ["input": 1, "output": 2, "reasoning": 0, "cache": ["read": 0, "write": 0]],
                                     "time": ["created": 1_763_550_000_000]]
        expect(OpenCodeReader.record(fromMessage: legacy, id: "m2", directory: nil)?.model == "gpt-5")
        expect(OpenCodeReader.record(fromMessage: ["role": "user"], id: "m3", directory: nil) == nil)
    }
}

enum ArchiveTests {
    static func oldRecordsDecodeAsClaudeCode() throws {
        let json = #"{"id":"a","t":785000000,"p":"semear","m":"claude-opus-5-5","o":10}"#
        let r = try JSONDecoder().decode(UsageRecord.self, from: Data(json.utf8))
        expect(r.tool == Tool.claudeCode)
        expect(r.output == 10 && r.input == 0)
        let again = try JSONDecoder().decode(UsageRecord.self, from: JSONEncoder().encode(
            UsageRecord(id: "b", tool: Tool.codex, timestamp: Date(), project: "p", model: "gpt-5", output: 3, costUSD: 1.5)))
        expect(again.tool == Tool.codex && again.costUSD == 1.5)
    }

    static func eachMacWritesItsOwnFolder() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let local = dir.appendingPathComponent("local"), cloud = dir.appendingPathComponent("cloud")
        let t = ClaudeLogParser.parseDate("2026-11-19T12:00:00Z")!
        let macA = HistoryArchive(localDir: local, cloudDir: cloud, machine: .init(id: "A", name: "Mac A"))
        macA.save([UsageRecord(id: "a1", timestamp: t, project: "p", model: "m", output: 1)], days: saoPaulo)

        // Outro Mac, com outra pasta local, vê o registro de A pelo iCloud
        let macB = HistoryArchive(localDir: dir.appendingPathComponent("localB"), cloudDir: cloud, machine: .init(id: "B", name: "Mac B"))
        let seenByB = macB.load()
        expect(seenByB.own.isEmpty)
        expect(seenByB.others.map(\.id) == ["a1"])

        // A relê os próprios (local + iCloud trazem o mesmo; o app tira a repetição)
        let seenByA = macA.load()
        expect(UsageStore.dedupe(seenByA.own).map(\.id) == ["a1"])
        expect(FileManager.default.fileExists(atPath: cloud.appendingPathComponent("A/2026-11.json").path))
    }
}

enum NotificationTests {
    static func plans() {
        let cal = saoPaulo.calendar
        let morning = cal.date(bySettingHour: 10, minute: 0, second: 0, of: saoPaulo.date("2026-11-19")!)!
        let night = cal.date(bySettingHour: 22, minute: 0, second: 0, of: saoPaulo.date("2026-11-19")!)!
        func state(_ now: Date, rings: Bool = false, active: Bool = false, streak: Int = 5, last: String? = nil,
                   notifyRings: Bool = true, notifyStreak: Bool = true) -> NotificationPlanner.State {
            .init(now: now, todayKey: "2026-11-19", allRingsClosed: rings, todayActive: active, streak: streak,
                  lastRingsNotifiedDay: last, notifyRings: notifyRings, notifyStreak: notifyStreak, reminderHour: 21)
        }
        // anéis fechados: avisa uma vez por dia
        expect(NotificationPlanner.plan(state(morning, rings: true, active: true), calendar: cal).postRingsClosed)
        expect(!NotificationPlanner.plan(state(morning, rings: true, active: true, last: "2026-11-19"), calendar: cal).postRingsClosed)
        expect(!NotificationPlanner.plan(state(morning, rings: true, active: true, notifyRings: false), calendar: cal).postRingsClosed)
        // sequência em risco: agenda para as 21h se hoje está vazio
        let reminder = NotificationPlanner.plan(state(morning), calendar: cal).streakReminderAt
        expect(reminder.map { cal.component(.hour, from: $0) } == 21)
        expect(NotificationPlanner.plan(state(morning, active: true), calendar: cal).streakReminderAt == nil)   // já teve atividade
        expect(NotificationPlanner.plan(state(morning, streak: 0), calendar: cal).streakReminderAt == nil)      // nada a perder
        expect(NotificationPlanner.plan(state(night), calendar: cal).streakReminderAt == nil)                   // horário já passou
        expect(NotificationPlanner.plan(state(morning, notifyStreak: false), calendar: cal).streakReminderAt == nil)
    }
}

if CommandLine.arguments.contains("--real") {
    // Lê os arquivos de verdade e imprime os últimos 7 dias, para conferir com uma soma independente.
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent("gitbeat-check-cache.json")
    let store = UsageStore(cacheURL: cache)
    let t0 = Date()
    let records = store.refresh()
    print("registros: \(records.count) em \(String(format: "%.1f", Date().timeIntervalSince(t0)))s")
    let codexCache = FileManager.default.temporaryDirectory.appendingPathComponent("gitbeat-check-codex.json")
    try? FileManager.default.removeItem(at: codexCache)
    let codex = FileSource(roots: CodexParser.roots, extensions: ["jsonl"], cacheURL: codexCache) { url, data in
        CodexParser.parse(fileContents: data, fileID: url.deletingPathExtension().lastPathComponent)
    }.refresh()
    let opencode = OpenCodeReader.read()
    func sum(_ r: [UsageRecord]) -> String { "respostas \(r.count) entrada \(r.reduce(0) { $0 + $1.input }) cache \(r.reduce(0) { $0 + $1.cacheRead }) saída \(r.reduce(0) { $0 + $1.output })" }
    print("codex:", sum(codex))
    print("opencode:", sum(opencode))
    let days = DayKeys()
    let byDay = Stats.tokensByDay(records, days: days)
    let secs = SessionTime.activeSecondsByDay(records.map(\.timestamp), days: days)
    for k in days.lastDays(7, endingAt: Date()) {
        let t = byDay[k] ?? TokenTotals()
        print(k, "total", t.total, "saida", t.output, "respostas", t.responses,
              String(format: "custo US$ %.2f  horas %.1f", t.cost, (secs[k] ?? 0) / 3600))
    }
    exit(0)
}

run("parser") { try ParserTests.readsUsageFromAssistantLine(); ParserTests.ignoresUserAndSyntheticLines(); ParserTests.projectNames() }
run("store") { StoreTests.dedupesRepeatedMessageIds(); try StoreTests.readsIncrementallyAndKeepsPartialLineForLater() }
run("pricing") { try PricingTests.opusCost(); PricingTests.longestPrefixWins(); PricingTests.displayNames() }
run("stats") { StatsTests.dayKeyUsesLocalTimezone(); StatsTests.sessionTimeIgnoresLongGapsAndOverlap(); StatsTests.streaks(); StatsTests.periodBuckets() }
run("other tools") { OtherToolTests.codexUsesCumulativeDeltas(); OtherToolTests.geminiKeepsLastLinePerID(); OtherToolTests.openCodeMessageShapes() }
run("archive") { try ArchiveTests.oldRecordsDecodeAsClaudeCode(); ArchiveTests.eachMacWritesItsOwnFolder() }
run("notifications") { NotificationTests.plans() }
run("github") { try GitHubTests.parsesHistory(); try GitHubTests.parsesPRPage() }

print(failures == 0 ? "OK: \(checks) checagens" : "\(failures) falha(s) em \(checks) checagens")
exit(failures == 0 ? 0 : 1)

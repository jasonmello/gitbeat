import CryptoKit
import Foundation
import IOKit
import Observation
import GitBeatCore

/// Estado do app: lê os dados em segundo plano e entrega números prontos para as telas.
@MainActor @Observable
final class AppModel {
    // Ferramentas de IA (Claude Code, OpenCode, Codex, Gemini CLI)
    private(set) var tokensByDay: [String: TokenTotals] = [:]
    private(set) var byProject: [String: [String: TokenTotals]] = [:]
    private(set) var byModel: [String: [String: TokenTotals]] = [:]
    private(set) var byTool: [String: [String: TokenTotals]] = [:]
    private(set) var secondsByDay: [String: Double] = [:]
    /// Respostas por hora do dia nos últimos 30 dias.
    private(set) var responsesByHour: [Int] = Array(repeating: 0, count: 24)
    private(set) var firstDay: String?
    /// Ferramentas com pelo menos um registro.
    private(set) var toolsFound: [String] = []

    /// Ferramentas cuja pasta existe neste Mac (instaladas, mesmo sem uso ainda).
    var toolsInstalled: [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let paths: [String: URL] = [
            Tool.claudeCode: UsageStore.defaultRoot,
            Tool.openCode: OpenCodeReader.dataDir,
            Tool.codex: CodexParser.home,
            Tool.gemini: home.appendingPathComponent(".gemini/tmp"),
        ]
        return Tool.all.filter { paths[$0].map { fm.fileExists(atPath: $0.path) } ?? false }
    }
    private(set) var recordCount = 0

    // GitHub
    private(set) var github: GitHubSnapshot?
    private(set) var githubError: Error?

    private(set) var isLoading = false
    private(set) var lastUpdated: Date?

    var goals: Goals {
        didSet { saveGoals() }
    }

    let days = DayKeys()
    private let claude: UsageStore
    private let codex: FileSource
    private let gemini: FileSource
    private let archive: HistoryArchive
    private let githubClient = GitHubClient()
    private let githubCacheURL: URL
    private var timer: Timer?
    private static let goalsKey = "goals"
    private static let githubMaxAge: TimeInterval = 30 * 60

    static var supportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GitBeat", isDirectory: true)
    }

    var historyLocalDir: URL { archive.localDir }
    var historyCloudDir: URL? { archive.cloudDir }

    init(autoRefresh: Bool = true) {
        Self.migrateOldSupportFolder()
        let support = Self.supportDir
        claude = UsageStore(cacheURL: support.appendingPathComponent("claude-usage.json"))
        codex = FileSource(roots: CodexParser.roots, extensions: ["jsonl"],
                           cacheURL: support.appendingPathComponent("codex-usage.json")) { url, data in
            CodexParser.parse(fileContents: data, fileID: url.deletingPathExtension().lastPathComponent)
        }
        gemini = FileSource(roots: [GeminiParser.root], extensions: ["jsonl", "json"],
                            cacheURL: support.appendingPathComponent("gemini-usage.json")) { url, data in
            guard url.pathComponents.contains("chats") else { return [] }
            return GeminiParser.parse(fileContents: data, project: GeminiParser.projectName(forChatFile: url))
        }
        archive = HistoryArchive(localDir: support.appendingPathComponent("History", isDirectory: true),
                                 cloudDir: HistoryArchive.defaultCloudDir,
                                 machine: Self.machineInfo())
        githubCacheURL = support.appendingPathComponent("github-v2.json")

        if let data = UserDefaults.standard.data(forKey: Self.goalsKey),
           let saved = try? JSONDecoder().decode(Goals.self, from: data) {
            goals = saved
        } else {
            goals = .standard
        }
        if let data = try? Data(contentsOf: githubCacheURL) {
            github = try? JSONDecoder().decode(GitHubSnapshot.self, from: data)
        }

        guard autoRefresh else { return }
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// O app se chamava Saúde Dev: aproveita o cache antigo para não reler tudo.
    private static func migrateOldSupportFolder() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = base.appendingPathComponent("SaudeDev")
        if fm.fileExists(atPath: old.path), !fm.fileExists(atPath: supportDir.path) {
            try? fm.moveItem(at: old, to: supportDir)
        }
    }

    /// Id estável deste Mac: hash do id de hardware (o número real não vai para o iCloud).
    /// Não depende das preferências do app, então o `.app` e o binário de teste usam a mesma pasta.
    private static func machineInfo() -> HistoryArchive.MachineInfo {
        let name = Host.current().localizedName ?? "Mac"
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        let raw = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
        guard let raw else { return .init(id: "mac-unknown", name: name) }
        let digest = SHA256.hash(data: Data(raw.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return .init(id: "mac-\(digest)", name: name)
    }

    // MARK: atualização

    private struct Computed: Sendable {
        var tokensByDay: [String: TokenTotals]
        var byProject: [String: [String: TokenTotals]]
        var byModel: [String: [String: TokenTotals]]
        var byTool: [String: [String: TokenTotals]]
        var secondsByDay: [String: Double]
        var responsesByHour: [Int]
        var firstDay: String?
        var toolsFound: [String]
        var recordCount: Int
    }

    func refresh(forceGitHub: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let (claude, codex, gemini, archive, days) = (self.claude, self.codex, self.gemini, self.archive, self.days)
        let computed = await Task.detached(priority: .userInitiated) { () -> Computed in
            let fromTools = claude.refresh() + OpenCodeReader.read() + codex.refresh() + gemini.refresh()
            let stored = archive.load()
            // Os deste Mac (ferramentas + o que já estava guardado) voltam para o histórico;
            // os de outros Macs só entram na conta.
            let own = UsageStore.dedupe(fromTools + stored.own)
            archive.save(own, days: days)
            let records = UsageStore.dedupe(own + stored.others)

            let stamps = records.map(\.timestamp)
            let monthAgo = Date().addingTimeInterval(-30 * 86_400)
            return Computed(
                tokensByDay: Stats.tokensByDay(records, days: days),
                byProject: Stats.tokensByDay(records, days: days) { $0.project },
                byModel: Stats.tokensByDay(records, days: days) { Pricing.displayName(for: $0.model) },
                byTool: Stats.tokensByDay(records, days: days) { Tool.displayName($0.tool) },
                secondsByDay: SessionTime.activeSecondsByDay(stamps, days: days),
                responsesByHour: SessionTime.responsesByHour(stamps.filter { $0 >= monthAgo }, calendar: days.calendar),
                firstDay: records.first.map { days.key($0.timestamp) },
                toolsFound: Tool.all.filter { t in records.contains { $0.tool == t } },
                recordCount: records.count
            )
        }.value

        tokensByDay = computed.tokensByDay
        byProject = computed.byProject
        byModel = computed.byModel
        byTool = computed.byTool
        secondsByDay = computed.secondsByDay
        responsesByHour = computed.responsesByHour
        firstDay = computed.firstDay
        toolsFound = computed.toolsFound
        recordCount = computed.recordCount

        let stale = github.map { Date().timeIntervalSince($0.fetchedAt) > Self.githubMaxAge } ?? true
        if forceGitHub || stale { await refreshGitHub() }
        lastUpdated = Date()
    }

    private func refreshGitHub() async {
        let client = githubClient
        let days = self.days
        let result = await Task.detached(priority: .utility) { () -> Result<GitHubSnapshot, Error> in
            Result { try client.fetch(days: days) }
        }.value
        switch result {
        case .success(let snapshot):
            github = snapshot
            githubError = nil
            if let data = try? JSONEncoder().encode(snapshot) {
                try? FileManager.default.createDirectory(at: githubCacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: githubCacheURL, options: .atomic)
            }
        case .failure(let error):
            githubError = error
        }
    }

    /// Mensagem de erro do GitHub no idioma escolhido.
    var githubErrorText: String? {
        guard let githubError else { return nil }
        switch githubError as? GitHubError {
        case .ghNotFound:
            return T("GitHub CLI (gh) not found. Install it with `brew install gh` and run `gh auth login`.",
                     "Não achei o GitHub CLI (gh). Instale com `brew install gh` e rode `gh auth login`.")
        case .command(let msg):
            return T("gh returned an error: ", "O gh respondeu com erro: ") + msg
        case nil:
            return githubError.localizedDescription
        }
    }

    private func saveGoals() {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: Self.goalsKey)
        }
    }

    // MARK: números do dia

    var todayKey: String { days.key(Date()) }

    /// Ainda não terminou a primeira leitura do histórico.
    var isFirstLoad: Bool { firstDay == nil && (isLoading || lastUpdated == nil) }
    /// Terminou de ler e não achou nenhuma sessão.
    var isEmpty: Bool { firstDay == nil && !isLoading && lastUpdated != nil }

    func tokens(on day: String) -> TokenTotals { tokensByDay[day] ?? TokenTotals() }
    func hours(on day: String) -> Double { (secondsByDay[day] ?? 0) / 3600 }
    func commits(on day: String) -> Int { github?.commitsOn(day) ?? 0 }
    func prsMerged(on day: String) -> Int { github?.prsMerged(on: day, days: days) ?? 0 }
    func prsOpened(on day: String) -> Int { github?.prsOpened(on: day, days: days) ?? 0 }

    struct RingValues {
        var tokens: Double
        var hours: Double
        var commits: Double
    }

    func rings(on day: String) -> RingValues {
        RingValues(
            tokens: goals.tokens > 0 ? Double(tokens(on: day).total) / Double(goals.tokens) : 0,
            hours: goals.hours > 0 ? hours(on: day) / goals.hours : 0,
            commits: goals.commits > 0 ? Double(commits(on: day)) / Double(goals.commits) : 0
        )
    }

    /// Dias com qualquer atividade: uma resposta de alguma ferramenta ou um commit.
    var activeDays: Set<String> {
        var set = Set(tokensByDay.filter { $0.value.responses > 0 }.keys)
        if let github {
            set.formUnion(github.commits.filter { $0.value.values.reduce(0, +) > 0 }.keys)
        }
        return set
    }

    var currentStreak: Int { Streaks.current(activeDays: activeDays, today: Date(), days: days) }
    var longestStreak: Int { Streaks.longest(activeDays: activeDays, days: days) }

    // MARK: séries para os gráficos

    struct Point: Identifiable {
        var date: Date
        var value: Double
        var id: Date { date }
    }

    func series(_ period: Period, _ value: ([String]) -> Double) -> [Point] {
        period.buckets(endingAt: Date(), days: days).map { Point(date: $0.start, value: value($0.dayKeys)) }
    }

    func dayKeys(_ period: Period) -> [String] {
        period.buckets(endingAt: Date(), days: days).flatMap(\.dayKeys)
    }

    func tokenSum(_ keys: [String]) -> TokenTotals {
        Stats.sum(tokensByDay, over: keys, zero: TokenTotals()) { var a = $0; a.add($1); return a }
    }

    func hoursSum(_ keys: [String]) -> Double {
        keys.reduce(0) { $0 + hours(on: $1) }
    }

    func commitSum(_ keys: [String]) -> Int { keys.reduce(0) { $0 + commits(on: $1) } }
    func prsMergedSum(_ keys: [String]) -> Int { keys.reduce(0) { $0 + prsMerged(on: $1) } }
    func prsOpenedSum(_ keys: [String]) -> Int { keys.reduce(0) { $0 + prsOpened(on: $1) } }

    /// Quantos dias do período já existiam (o histórico começa no primeiro registro), para a média não ficar diluída.
    func elapsedDays(_ keys: [String]) -> Int {
        guard let first = firstDay else { return max(keys.count, 1) }
        return max(keys.filter { $0 >= first }.count, 1)
    }
}

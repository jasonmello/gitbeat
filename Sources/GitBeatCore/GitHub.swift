import Foundation

public struct PullRequestInfo: Codable, Hashable, Sendable {
    public var title: String
    public var repo: String
    public var createdAt: Date
    public var mergedAt: Date?

    public init(title: String, repo: String, createdAt: Date, mergedAt: Date?) {
        self.title = title
        self.repo = repo
        self.createdAt = createdAt
        self.mergedAt = mergedAt
    }
}

/// O que o app guarda do GitHub. Dias são chaves "aaaa-mm-dd" no fuso local.
public struct GitHubSnapshot: Codable, Sendable {
    public var login: String
    public var fetchedAt: Date
    /// Commits seus no branch principal, por dia e por repositório (inclui repositórios privados).
    public var commits: [String: [String: Int]]
    public var pullRequests: [PullRequestInfo]

    public init(login: String, fetchedAt: Date, commits: [String: [String: Int]], pullRequests: [PullRequestInfo]) {
        self.login = login
        self.fetchedAt = fetchedAt
        self.commits = commits
        self.pullRequests = pullRequests
    }

    public func commitsOn(_ day: String) -> Int { commits[day]?.values.reduce(0, +) ?? 0 }

    public func prsOpened(on day: String, days: DayKeys) -> Int {
        pullRequests.filter { days.key($0.createdAt) == day }.count
    }

    public func prsMerged(on day: String, days: DayKeys) -> Int {
        pullRequests.filter { $0.mergedAt.map(days.key) == day }.count
    }
}

public enum GitHubParser {
    public struct Viewer {
        public var id: String
        public var login: String
    }

    public static func parseViewer(_ data: Data) throws -> Viewer {
        let root = try JSONDecoder().decode(ViewerResponse.self, from: data)
        return Viewer(id: root.data.viewer.id, login: root.data.viewer.login)
    }

    public struct HistoryPage {
        public var commits: [String: [String: Int]]
        public var endCursor: String?
        public var hasNextPage: Bool
    }

    /// Uma página de repositórios, cada um com seus commits no branch principal.
    public static func parseHistory(_ data: Data, days: DayKeys) throws -> HistoryPage {
        let root = try JSONDecoder().decode(HistoryResponse.self, from: data)
        let repos = root.data.viewer.repositories
        var commits: [String: [String: Int]] = [:]
        for repo in repos.nodes {
            for node in repo.defaultBranchRef?.target?.history?.nodes ?? [] {
                guard let date = ClaudeLogParser.parseDate(node.authoredDate) else { continue }
                commits[days.key(date), default: [:]][repo.nameWithOwner, default: 0] += 1
            }
        }
        return HistoryPage(commits: commits, endCursor: repos.pageInfo.endCursor, hasNextPage: repos.pageInfo.hasNextPage)
    }

    public struct PRPage {
        public var items: [PullRequestInfo]
        public var endCursor: String?
        public var hasNextPage: Bool
    }

    public static func parsePRs(_ data: Data) throws -> PRPage {
        let root = try JSONDecoder().decode(SearchResponse.self, from: data)
        let items = root.data.search.nodes.compactMap { n -> PullRequestInfo? in
            guard let title = n.title, let repo = n.repository?.nameWithOwner,
                  let created = n.createdAt.flatMap(ClaudeLogParser.parseDate) else { return nil }
            return PullRequestInfo(title: title, repo: repo, createdAt: created,
                                   mergedAt: n.mergedAt.flatMap(ClaudeLogParser.parseDate))
        }
        let info = root.data.search.pageInfo
        return PRPage(items: items, endCursor: info.endCursor, hasNextPage: info.hasNextPage)
    }

    // MARK: formato das respostas do GraphQL

    struct PageInfo: Decodable { var hasNextPage: Bool; var endCursor: String? }
    struct Repo: Decodable { var nameWithOwner: String }

    struct ViewerResponse: Decodable {
        struct DataBox: Decodable { var viewer: V }
        struct V: Decodable { var id: String; var login: String }
        var data: DataBox
    }

    struct HistoryResponse: Decodable {
        struct DataBox: Decodable { var viewer: V }
        struct V: Decodable { var repositories: Repos }
        struct Repos: Decodable { var pageInfo: PageInfo; var nodes: [RepoNode] }
        struct RepoNode: Decodable { var nameWithOwner: String; var defaultBranchRef: Ref? }
        struct Ref: Decodable { var target: Target? }
        struct Target: Decodable { var history: History? }
        struct History: Decodable { var nodes: [Commit] }
        struct Commit: Decodable { var authoredDate: String }
        var data: DataBox
    }

    struct SearchResponse: Decodable {
        struct DataBox: Decodable { var search: Search }
        struct Search: Decodable { var pageInfo: PageInfo; var nodes: [Node] }
        struct Node: Decodable {
            var title: String?
            var createdAt: String?
            var mergedAt: String?
            var repository: Repo?
        }
        var data: DataBox
    }
}

public enum GitHubError: LocalizedError {
    case ghNotFound
    case command(String)

    public var errorDescription: String? {
        switch self {
        case .ghNotFound: "Não achei o GitHub CLI (gh). Instale com `brew install gh` e rode `gh auth login`."
        case .command(let msg): "O gh respondeu com erro: \(msg)"
        }
    }
}

/// Fala com o GitHub pelo `gh` já logado na máquina. Nenhum token passa pelo app.
///
/// Os commits vêm do histórico do branch principal de cada repositório, e não do calendário de
/// contribuições do perfil: o calendário esconde repositórios privados quando a opção
/// "contribuições privadas" do perfil está desligada.
public final class GitHubClient: @unchecked Sendable {
    public init() {}

    static let viewerQuery = "query { viewer { id login } }"

    /// Até 100 commits por repositório no período; acima disso o dia mais antigo fica de fora.
    static let historyQuery = """
    query($since: GitTimestamp!, $uid: ID!, $after: String) { viewer {
      repositories(first: 50, after: $after, orderBy: {field: PUSHED_AT, direction: DESC},
                   ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]) {
        pageInfo { hasNextPage endCursor }
        nodes { nameWithOwner defaultBranchRef { target { ... on Commit {
          history(first: 100, since: $since, author: {id: $uid}) { nodes { authoredDate } }
        } } } }
      }
    } }
    """

    static let prQuery = """
    query($q: String!, $after: String) { search(query: $q, type: ISSUE, first: 100, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { ... on PullRequest { title createdAt mergedAt repository { nameWithOwner } } }
    } }
    """

    /// Apps abertos pelo Finder não herdam o PATH do terminal, então procuramos nos lugares comuns.
    static func findGH() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/gh", "/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func run(_ args: [String]) throws -> Data {
        guard let gh = Self.findGH() else { throw GitHubError.ghNotFound }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GitHubError.command(String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return data
    }

    public func fetch(now: Date = Date(), days: DayKeys = DayKeys()) throws -> GitHubSnapshot {
        let viewer = try GitHubParser.parseViewer(run(["api", "graphql", "-f", "query=\(Self.viewerQuery)"]))
        let since = days.calendar.date(byAdding: .day, value: -365, to: now) ?? now

        var commits: [String: [String: Int]] = [:]
        var cursor: String?
        for _ in 0..<6 { // até 300 repositórios
            var args = ["api", "graphql", "-f", "query=\(Self.historyQuery)",
                        "-f", "since=\(ISO8601DateFormatter().string(from: since))", "-f", "uid=\(viewer.id)"]
            if let cursor { args += ["-f", "after=\(cursor)"] }
            let page = try GitHubParser.parseHistory(run(args), days: days)
            for (day, repos) in page.commits {
                commits[day, default: [:]].merge(repos, uniquingKeysWith: +)
            }
            guard page.hasNextPage, let next = page.endCursor else { break }
            cursor = next
        }

        let q = "author:\(viewer.login) is:pr created:>=\(days.key(since))"
        var prs: [PullRequestInfo] = []
        cursor = nil
        for _ in 0..<10 { // a busca do GitHub para em 1.000 resultados
            var args = ["api", "graphql", "-f", "query=\(Self.prQuery)", "-f", "q=\(q)"]
            if let cursor { args += ["-f", "after=\(cursor)"] }
            let page = try GitHubParser.parsePRs(run(args))
            prs += page.items
            guard page.hasNextPage, let next = page.endCursor else { break }
            cursor = next
        }
        return GitHubSnapshot(login: viewer.login, fetchedAt: now, commits: commits, pullRequests: prs)
    }
}

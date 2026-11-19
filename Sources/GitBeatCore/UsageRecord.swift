import Foundation

/// Uma resposta de um modelo, com os tokens que ela gastou. Vem do Claude Code, OpenCode, Codex ou Gemini CLI.
public struct UsageRecord: Codable, Hashable, Sendable {
    public var id: String
    /// Qual ferramenta gerou: ver `Tool`.
    public var tool: String
    public var timestamp: Date
    public var project: String
    public var model: String
    public var input: Int
    public var output: Int
    public var cacheWrite5m: Int
    public var cacheWrite1h: Int
    public var cacheRead: Int
    public var fast: Bool
    /// Custo em dólar quando a própria ferramenta grava (OpenCode). Senão, calculado por `Pricing`.
    public var costUSD: Double?

    public init(id: String, tool: String = Tool.claudeCode, timestamp: Date, project: String, model: String,
                input: Int = 0, output: Int = 0, cacheWrite5m: Int = 0, cacheWrite1h: Int = 0,
                cacheRead: Int = 0, fast: Bool = false, costUSD: Double? = nil) {
        self.id = id
        self.tool = tool
        self.timestamp = timestamp
        self.project = project
        self.model = model
        self.input = input
        self.output = output
        self.cacheWrite5m = cacheWrite5m
        self.cacheWrite1h = cacheWrite1h
        self.cacheRead = cacheRead
        self.fast = fast
        self.costUSD = costUSD
    }

    public var cacheWrite: Int { cacheWrite5m + cacheWrite1h }
    public var totalTokens: Int { input + output + cacheWrite + cacheRead }

    // Chaves curtas: o cache e o histórico guardam centenas de milhares destes.
    enum CodingKeys: String, CodingKey {
        case id, tool = "s", timestamp = "t", project = "p", model = "m", input = "i", output = "o"
        case cacheWrite5m = "w5", cacheWrite1h = "w1", cacheRead = "r", fast = "f", costUSD = "c"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        tool = try c.decodeIfPresent(String.self, forKey: .tool) ?? Tool.claudeCode // registros antigos
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        project = try c.decode(String.self, forKey: .project)
        model = try c.decode(String.self, forKey: .model)
        input = try c.decodeIfPresent(Int.self, forKey: .input) ?? 0
        output = try c.decodeIfPresent(Int.self, forKey: .output) ?? 0
        cacheWrite5m = try c.decodeIfPresent(Int.self, forKey: .cacheWrite5m) ?? 0
        cacheWrite1h = try c.decodeIfPresent(Int.self, forKey: .cacheWrite1h) ?? 0
        cacheRead = try c.decodeIfPresent(Int.self, forKey: .cacheRead) ?? 0
        fast = try c.decodeIfPresent(Bool.self, forKey: .fast) ?? false
        costUSD = try c.decodeIfPresent(Double.self, forKey: .costUSD)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        if tool != Tool.claudeCode { try c.encode(tool, forKey: .tool) }
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(project, forKey: .project)
        try c.encode(model, forKey: .model)
        if input != 0 { try c.encode(input, forKey: .input) }
        if output != 0 { try c.encode(output, forKey: .output) }
        if cacheWrite5m != 0 { try c.encode(cacheWrite5m, forKey: .cacheWrite5m) }
        if cacheWrite1h != 0 { try c.encode(cacheWrite1h, forKey: .cacheWrite1h) }
        if cacheRead != 0 { try c.encode(cacheRead, forKey: .cacheRead) }
        if fast { try c.encode(fast, forKey: .fast) }
        try c.encodeIfPresent(costUSD, forKey: .costUSD)
    }
}

/// Identificadores das ferramentas. Ficam gravados no histórico: não mudar.
public enum Tool {
    public static let claudeCode = "claude-code"
    public static let openCode = "opencode"
    public static let codex = "codex"
    public static let gemini = "gemini"
    public static let all = [claudeCode, openCode, codex, gemini]

    public static func displayName(_ id: String) -> String {
        switch id {
        case claudeCode: "Claude Code"
        case openCode: "OpenCode"
        case codex: "Codex CLI"
        case gemini: "Gemini CLI"
        default: id
        }
    }
}

/// Lê uma linha do `.jsonl` do Claude Code e devolve o registro de uso, se for uma resposta do modelo.
public enum ClaudeLogParser {
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()

    public static func parseDate(_ s: String) -> Date? {
        isoFrac.date(from: s) ?? iso.date(from: s)
    }

    public static func parse(line: Data) -> UsageRecord? {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              obj["type"] as? String == "assistant",
              let msg = obj["message"] as? [String: Any],
              let usage = msg["usage"] as? [String: Any],
              let tsString = obj["timestamp"] as? String,
              let ts = parseDate(tsString)
        else { return nil }

        let model = msg["model"] as? String ?? "desconhecido"
        if model.hasPrefix("<") { return nil } // "<synthetic>": mensagem gerada localmente, sem custo

        func int(_ dict: [String: Any]?, _ key: String) -> Int {
            (dict?[key] as? NSNumber)?.intValue ?? 0
        }
        let creation = int(usage, "cache_creation_input_tokens")
        var w1 = 0
        if let breakdown = usage["cache_creation"] as? [String: Any] {
            w1 = min(int(breakdown, "ephemeral_1h_input_tokens"), creation)
        }
        let id = (msg["id"] as? String) ?? (obj["requestId"] as? String) ?? (obj["uuid"] as? String) ?? UUID().uuidString

        return UsageRecord(
            id: id,
            timestamp: ts,
            project: projectName(fromCWD: obj["cwd"] as? String),
            model: model,
            input: int(usage, "input_tokens"),
            output: int(usage, "output_tokens"),
            cacheWrite5m: creation - w1,
            cacheWrite1h: w1,
            cacheRead: int(usage, "cache_read_input_tokens"),
            fast: (usage["speed"] as? String) == "fast"
        )
    }

    public static let noFolder = "Sem pasta"

    /// Nome do projeto a partir da pasta onde a sessão rodou. Worktrees contam como o projeto-mãe.
    public static func projectName(fromCWD cwd: String?) -> String {
        guard let cwd, !cwd.isEmpty, !cwd.contains("/scratch-workspaces/") else { return noFolder }
        var parts = cwd.split(separator: "/").map(String.init)
        if let i = parts.firstIndex(of: ".claude"), i > 0 { parts = Array(parts[..<i]) }
        return parts.last ?? noFolder
    }
}

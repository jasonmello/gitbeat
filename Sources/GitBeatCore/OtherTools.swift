import Foundation
import SQLite3

// Leitores das outras ferramentas. Formatos tirados do código-fonte de cada uma em 2026-11-19
// (ver docs/arquitetura.md). Nenhum foi testado com arquivos reais nesta máquina: onde o
// código-fonte deixou dúvida, o leitor aceita as duas formas.

private func dict(_ v: Any?) -> [String: Any]? { v as? [String: Any] }
private func int(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }
private func double(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
private func date(_ v: Any?) -> Date? {
    if let s = v as? String { return ClaudeLogParser.parseDate(s) }
    if let n = v as? NSNumber { // epoch em ms (ou s, se pequeno)
        let x = n.doubleValue
        return Date(timeIntervalSince1970: x > 10_000_000_000 ? x / 1000 : x)
    }
    return nil
}
private func lastComponent(_ path: String?) -> String {
    ClaudeLogParser.projectName(fromCWD: path)
}

// MARK: Codex CLI

/// Codex grava um `.jsonl` por sessão em `$CODEX_HOME/sessions` (padrão `~/.codex`).
/// Eventos `token_count` trazem `total_token_usage` (acumulado na sessão) e `last_token_usage`.
/// Usamos a diferença do acumulado: eventos repetidos ou estimados não somam em dobro.
public enum CodexParser {
    public static func parse(fileContents data: Data, fileID: String) -> [UsageRecord] {
        var records: [UsageRecord] = []
        var model = "codex"
        var cwd: String?
        var previous: [String: Int] = [:]
        var index = 0
        for lineSub in data.split(separator: 0x0A) {
            index += 1
            guard let obj = (try? JSONSerialization.jsonObject(with: Data(lineSub))) as? [String: Any] else { continue }
            let item = dict(obj["payload"]) ?? obj
            let kind = (obj["type"] as? String) ?? ""
            let itemType = (item["type"] as? String) ?? kind

            if kind == "session_meta" || itemType == "session_meta" {
                cwd = (item["cwd"] as? String) ?? cwd
                continue
            }
            if kind == "turn_context" || itemType == "turn_context" {
                cwd = (item["cwd"] as? String) ?? cwd
                model = (item["model"] as? String) ?? model
                continue
            }
            guard itemType == "token_count", let info = dict(item["info"]),
                  let total = dict(info["total_token_usage"]) else { continue }

            let keys = ["input_tokens", "cached_input_tokens", "cache_write_input_tokens", "output_tokens"]
            var delta: [String: Int] = [:]
            for k in keys { delta[k] = max(int(total[k]) - (previous[k] ?? 0), 0) }
            for k in keys { previous[k] = max(int(total[k]), previous[k] ?? 0) }
            guard delta.values.contains(where: { $0 > 0 }),
                  let ts = date(obj["timestamp"]) ?? date(item["timestamp"]) else { continue }

            let cached = delta["cached_input_tokens"] ?? 0
            records.append(UsageRecord(
                id: "codex:\(fileID):\(index)", tool: Tool.codex, timestamp: ts,
                project: lastComponent(cwd), model: model,
                input: max((delta["input_tokens"] ?? 0) - cached, 0), // input_tokens inclui o cache
                output: delta["output_tokens"] ?? 0,                  // raciocínio já está dentro da saída
                cacheWrite5m: delta["cache_write_input_tokens"] ?? 0,
                cacheRead: cached))
        }
        return records
    }

    public static var home: URL {
        let env = ProcessInfo.processInfo.environment["CODEX_HOME"]
        return env.map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    /// Sessões ativas e arquivadas: as arquivadas também gastaram tokens.
    public static var roots: [URL] {
        [home.appendingPathComponent("sessions"), home.appendingPathComponent("archived_sessions")]
    }
}

// MARK: Gemini CLI

/// Gemini grava cada conversa em `~/.gemini/tmp/<projeto>/chats/session-*.jsonl` (antes, `.json`).
/// A mesma mensagem é regravada quando muda: vale a última linha de cada `id`.
public enum GeminiParser {
    public static func parse(fileContents data: Data, project: String) -> [UsageRecord] {
        var messages: [String: [String: Any]] = [:]
        var order: [String] = []

        func take(_ m: [String: Any]) {
            guard let id = m["id"] as? String else { return }
            if messages[id] == nil { order.append(id) }
            messages[id] = m
        }

        if let whole = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let list = whole["messages"] as? [[String: Any]] {
            list.forEach(take) // formato antigo: um JSON com "messages"
        } else {
            for lineSub in data.split(separator: 0x0A) {
                if let m = (try? JSONSerialization.jsonObject(with: Data(lineSub))) as? [String: Any] { take(m) }
            }
        }

        return order.compactMap { id -> UsageRecord? in
            guard let m = messages[id], m["type"] as? String == "gemini",
                  let tokens = dict(m["tokens"]), let ts = date(m["timestamp"]) else { return nil }
            let cached = int(tokens["cached"])
            return UsageRecord(
                id: "gemini:\(id)", tool: Tool.gemini, timestamp: ts, project: project,
                model: (m["model"] as? String) ?? "gemini",
                input: max(int(tokens["input"]) - cached, 0) + int(tokens["tool"]),
                output: int(tokens["output"]) + int(tokens["thoughts"]), // raciocínio é cobrado como saída
                cacheRead: cached)
        }
    }

    public static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/tmp")
    }

    /// Nome do projeto: o `.project_root` da pasta, se existir; senão o nome da pasta.
    public static func projectName(forChatFile url: URL) -> String {
        var dir = url.deletingLastPathComponent()
        while dir.lastPathComponent != "tmp", dir.path != "/" {
            let marker = dir.appendingPathComponent(".project_root")
            if let root = try? String(contentsOf: marker, encoding: .utf8) {
                return lastComponent(root.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if dir.deletingLastPathComponent().lastPathComponent == "tmp" { return dir.lastPathComponent }
            dir = dir.deletingLastPathComponent()
        }
        return ClaudeLogParser.noFolder
    }
}

// MARK: OpenCode

/// OpenCode guarda tudo num SQLite (`~/.local/share/opencode/opencode.db`, ou `OPENCODE_DB`).
/// Mensagens do assistente ficam em `session_message.data` (JSON com tokens e custo);
/// a pasta vem de `session_v2.directory`. Versões antigas usavam um JSON por mensagem.
public enum OpenCodeReader {
    public static var dataDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share/opencode")
    }

    public static func read() -> [UsageRecord] {
        var out: [UsageRecord] = []
        for db in databaseFiles() { out += readSQLite(db) }
        out += readLegacyJSON(dataDir.appendingPathComponent("storage/message"))
        return out
    }

    static func databaseFiles() -> [URL] {
        if let env = ProcessInfo.processInfo.environment["OPENCODE_DB"], env != ":memory:" {
            return [URL(fileURLWithPath: env)]
        }
        let files = (try? FileManager.default.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "db" }
    }

    /// Converte o JSON de uma mensagem do assistente (novo ou antigo) num registro.
    public static func record(fromMessage m: [String: Any], id: String, directory: String?) -> UsageRecord? {
        let role = (m["role"] as? String) ?? (m["type"] as? String)
        guard role == nil || role == "assistant", let tokens = dict(m["tokens"]) else { return nil }
        let cache = dict(tokens["cache"])
        let model = dict(m["model"])
        let modelID = (model?["id"] as? String) ?? (m["modelID"] as? String) ?? "opencode"
        let time = dict(m["time"])
        guard let ts = date(time?["created"]) else { return nil }
        let cwd = directory ?? (dict(m["path"])?["cwd"] as? String)
        return UsageRecord(
            id: "opencode:\(id)", tool: Tool.openCode, timestamp: ts, project: lastComponent(cwd), model: modelID,
            input: int(tokens["input"]),
            output: int(tokens["output"]) + int(tokens["reasoning"]),
            cacheWrite5m: int(cache?["write"]),
            cacheRead: int(cache?["read"]),
            costUSD: double(m["cost"]))
    }

    static func readSQLite(_ url: URL) -> [UsageRecord] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }
        let sql = """
        SELECT m.id, m.data, s.directory FROM session_message m
        LEFT JOIN session_v2 s ON s.id = m.session_id WHERE m.type = 'assistant'
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [UsageRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idC = sqlite3_column_text(stmt, 0), let dataC = sqlite3_column_text(stmt, 1) else { continue }
            let id = String(cString: idC)
            let dir = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            if let m = (try? JSONSerialization.jsonObject(with: Data(String(cString: dataC).utf8))) as? [String: Any],
               let r = record(fromMessage: m, id: id, directory: dir) {
                out.append(r)
            }
        }
        return out
    }

    static func readLegacyJSON(_ root: URL) -> [UsageRecord] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var out: [UsageRecord] = []
        for case let url as URL in walker where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let m = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            let id = (m["id"] as? String) ?? url.deletingPathExtension().lastPathComponent
            if let r = record(fromMessage: m, id: id, directory: nil) { out.append(r) }
        }
        return out
    }
}

// MARK: leitura com cache por arquivo

/// Lê arquivos que mudam pouco (Codex, Gemini) e relê só os que mudaram desde a última vez.
public final class FileSource: @unchecked Sendable {
    struct Entry: Codable { var size: UInt64; var mtime: Double; var records: [UsageRecord] }

    let roots: [URL]
    let extensions: Set<String>
    let parse: (URL, Data) -> [UsageRecord]
    let cacheURL: URL
    private var entries: [String: Entry] = [:]
    private let lock = NSLock()

    public init(roots: [URL], extensions: Set<String>, cacheURL: URL, parse: @escaping (URL, Data) -> [UsageRecord]) {
        self.roots = roots
        self.extensions = extensions
        self.cacheURL = cacheURL
        self.parse = parse
        if let data = try? Data(contentsOf: cacheURL),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = saved
        }
    }

    public func refresh() -> [UsageRecord] {
        lock.lock(); defer { lock.unlock() }
        var changed = false
        for root in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { continue }
            for case let url as URL in walker where extensions.contains(url.pathExtension) {
                guard let v = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                      let size = v.fileSize else { continue }
                let mtime = v.contentModificationDate?.timeIntervalSince1970 ?? 0
                if let e = entries[url.path], e.size == UInt64(size), e.mtime == mtime { continue }
                guard let data = try? Data(contentsOf: url) else { continue }
                entries[url.path] = Entry(size: UInt64(size), mtime: mtime, records: parse(url, data))
                changed = true
            }
        }
        if changed, let data = try? JSONEncoder().encode(entries) {
            try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        }
        return entries.values.flatMap(\.records)
    }
}

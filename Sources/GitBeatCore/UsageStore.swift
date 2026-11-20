import Foundation

/// Lê linhas de um arquivo grande sem carregar tudo, passando adiante só as que contêm todas as `needles`.
public enum JSONLReader {
    /// Lê a partir de `offset` e devolve o novo offset: o fim da última linha completa.
    /// Uma linha ainda sendo escrita (sem `\n`) fica para a próxima leitura.
    public static func readLines(at url: URL, from offset: UInt64, needles: [String],
                                 _ body: (Data) -> Void) throws -> UInt64 {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)

        let needleBytes = needles.map { Array($0.utf8) }
        var position = offset
        var buffer = Data()

        while let chunk = try handle.read(upToCount: 8 << 20), !chunk.isEmpty {
            buffer.append(chunk)
            var consumed = 0
            buffer.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                guard let base = raw.baseAddress else { return }
                let count = raw.count
                var start = 0
                while start < count, let nl = memchr(base + start, 0x0A, count - start) {
                    let end = base.distance(to: UnsafeRawPointer(nl))
                    let length = end - start
                    if length > 0 {
                        let line = base + start
                        let matches = needleBytes.allSatisfy { n in
                            n.withUnsafeBytes { memmem(line, length, $0.baseAddress, n.count) != nil }
                        }
                        if matches { body(Data(bytes: line, count: length)) }
                    }
                    start = end + 1
                }
                consumed = start
            }
            position += UInt64(consumed)
            buffer.removeSubrange(0..<consumed)
        }
        return position
    }
}

/// Junta os registros de todos os `.jsonl` do Claude Code, com cache em disco.
/// Arquivos que só cresceram são lidos a partir de onde parou. Arquivos apagados pelo
/// Claude Code (limpeza de 30 dias) continuam no cache, então o histórico não se perde.
public final class UsageStore: @unchecked Sendable {
    struct FileState: Codable {
        var size: UInt64
        var mtime: Double
        var offset: UInt64
        var records: [UsageRecord]
    }
    struct CacheFile: Codable {
        var version: Int
        var files: [String: FileState]
    }
    static let cacheVersion = 1

    public let root: URL
    public let cacheURL: URL
    private var files: [String: FileState] = [:]
    private let lock = NSLock()
    private var dirty = false
    /// O último resultado de `refresh`, devolvido direto quando nenhum arquivo mudou.
    private var lastResult: [UsageRecord]?

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    }

    public init(root: URL = UsageStore.defaultRoot, cacheURL: URL) {
        self.root = root
        self.cacheURL = cacheURL
        if let data = try? Data(contentsOf: cacheURL),
           let cache = try? JSONDecoder().decode(CacheFile.self, from: data),
           cache.version == Self.cacheVersion {
            files = cache.files
        }
    }

    /// Relê o que mudou e devolve todos os registros, sem repetição, em ordem de tempo.
    /// Com `persist: false` não regrava o cache em disco (releituras rápidas; a completa grava).
    /// Com `only`, olha só esses arquivos (os que o FSEvents disse que mudaram), sem percorrer as
    /// centenas de pastas de projetos.
    public func refresh(persist: Bool = true, only: [URL]? = nil) -> [UsageRecord] {
        lock.lock(); defer { lock.unlock() }
        let fm = FileManager.default
        var changed = false
        let rootPath = root.standardizedFileURL.path + "/"
        let candidates: AnySequence<Any> = only.map { urls in
            AnySequence(urls.filter { $0.standardizedFileURL.path.hasPrefix(rootPath) }.map { $0 as Any })
        } ?? AnySequence(fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                            .map { Array($0) } ?? [])

        do {
            for case let url as URL in candidates where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                      let sizeInt = values.fileSize else { continue }
                let size = UInt64(sizeInt)
                let mtime = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                let key = url.path

                var state = files[key] ?? FileState(size: 0, mtime: 0, offset: 0, records: [])
                if files[key] != nil, state.size == size, state.mtime == mtime { continue }
                if size < state.offset { state = FileState(size: 0, mtime: 0, offset: 0, records: []) }

                var fresh: [UsageRecord] = []
                let newOffset = (try? JSONLReader.readLines(at: url, from: state.offset,
                                                            needles: ["\"usage\"", "\"assistant\""]) { line in
                    if let r = ClaudeLogParser.parse(line: line) { fresh.append(r) }
                }) ?? state.offset
                state.records.append(contentsOf: fresh)
                state.offset = newOffset
                state.size = size
                state.mtime = mtime
                files[key] = state
                changed = true
            }
        }
        if changed { dirty = true }
        if persist, dirty { save(); dirty = false }
        if !changed, let lastResult { return lastResult }
        let result = Self.dedupe(files.values.flatMap(\.records))
        lastResult = result
        return result
    }

    /// O mesmo `message.id` aparece em várias linhas (streaming) e em sessões retomadas. Conta uma vez só.
    /// Ordena só os índices (copiar dezenas de milhares de registros com textos dentro custava caro
    /// em cada releitura). A ordenação é estável: no empate de horário, vence o primeiro da lista.
    public static func dedupe(_ records: [UsageRecord]) -> [UsageRecord] {
        let order = records.indices.sorted {
            records[$0].timestamp != records[$1].timestamp ? records[$0].timestamp < records[$1].timestamp : $0 < $1
        }
        var seen = Set<String>(minimumCapacity: records.count)
        var out: [UsageRecord] = []
        out.reserveCapacity(records.count)
        for i in order where seen.insert(records[i].id).inserted {
            out.append(records[i])
        }
        return out
    }

    private func save() {
        let cache = CacheFile(version: Self.cacheVersion, files: files)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }
}

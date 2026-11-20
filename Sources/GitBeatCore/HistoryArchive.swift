import Foundation

/// Histórico permanente: só números (horário, ferramenta, projeto, modelo, tokens), nunca o texto das conversas.
///
/// Cada Mac grava a própria pasta (`<id do Mac>/aaaa-mm.json`, um arquivo por mês), no Mac e,
/// se houver, numa pasta do iCloud Drive. Cada Mac só escreve na sua pasta, então não há conflito
/// de sincronização; na leitura, junta todas as pastas e conta cada resposta uma vez.
public final class HistoryArchive: @unchecked Sendable {
    public struct MachineInfo: Codable, Sendable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    struct MonthFile: Codable {
        var version: Int
        var machine: MachineInfo
        var month: String
        var records: [UsageRecord]
    }

    public let localDir: URL
    public let cloudDir: URL?
    public let machine: MachineInfo
    private var written: [String: Int] = [:] // mês -> quantos registros já gravados
    private let lock = NSLock()

    public init(localDir: URL, cloudDir: URL?, machine: MachineInfo) {
        self.localDir = localDir
        self.cloudDir = cloudDir
        self.machine = machine
    }

    /// Pasta do iCloud Drive, se o iCloud Drive estiver ligado neste Mac.
    public static var defaultCloudDir: URL? {
        let drive = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        guard FileManager.default.fileExists(atPath: drive.path) else { return nil }
        return drive.appendingPathComponent("GitBeat/History", isDirectory: true)
    }

    /// Registros guardados: os deste Mac e os dos outros Macs (local e iCloud).
    /// Os meses deste Mac vêm da cópia local; a do iCloud só entra para um mês que falta no local
    /// (antes eram lidas as duas e metade era descartada como repetida).
    public func load() -> (own: [UsageRecord], others: [UsageRecord]) {
        lock.lock(); defer { lock.unlock() }
        var own: [UsageRecord] = []
        var others: [UsageRecord] = []
        var ownMonthsLocal = Set<String>()
        for base in [localDir, cloudDir].compactMap({ $0 }) {
            let machines = (try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
            for dir in machines where dir.hasDirectoryPath {
                let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
                for file in files {
                    if file.lastPathComponent.hasSuffix(".icloud") { // ainda não baixado do iCloud
                        try? FileManager.default.startDownloadingUbiquitousItem(at: file)
                        continue
                    }
                    let isOwn = dir.lastPathComponent == machine.id
                    if isOwn, base != localDir, ownMonthsLocal.contains(file.deletingPathExtension().lastPathComponent) { continue }
                    guard file.pathExtension == "json", let data = try? Data(contentsOf: file),
                          let month = try? JSONDecoder().decode(MonthFile.self, from: data) else { continue }
                    if isOwn {
                        own += month.records
                        if base == localDir {
                            ownMonthsLocal.insert(month.month)
                            written[month.month] = max(written[month.month] ?? 0, month.records.count)
                        }
                    } else {
                        others += month.records
                    }
                }
            }
        }
        return (own, others)
    }

    /// Grava os registros deste Mac. Só reescreve os meses que ganharam registros.
    public func save(_ records: [UsageRecord], days: DayKeys) {
        lock.lock(); defer { lock.unlock() }
        let byMonth = Dictionary(grouping: records) { String(days.key($0.timestamp).prefix(7)) }
        for (month, list) in byMonth where list.count > (written[month] ?? 0) {
            let file = MonthFile(version: 1, machine: machine, month: month,
                                 records: list.sorted { $0.timestamp < $1.timestamp })
            guard let data = try? JSONEncoder().encode(file) else { continue }
            for base in [localDir, cloudDir].compactMap({ $0 }) {
                let dir = base.appendingPathComponent(machine.id, isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try? data.write(to: dir.appendingPathComponent("\(month).json"), options: .atomic)
            }
            written[month] = list.count
        }
    }
}

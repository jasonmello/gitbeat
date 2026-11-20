import AppKit
import Observation
import GitBeatCore

/// O mascote animado do ícone da barra de menu (kit do mascote v2).
/// O número ao lado mostra o total de hoje; o movimento mostra o ritmo recente, medido pelo
/// `ActivityMeter` sobre o mesmo total. Parado = quietinho; pouco = fluindo; muito = ocupado; pico = explosão.
@MainActor @Observable
final class MenuBarMascot {
    private(set) var image: NSImage
    private(set) var level: ActivityMeter.Level = .idle

    /// Um trecho da animação: uma imagem que fica parada por `frames` quadros seguidos.
    /// Quadros idênticos viram um trecho só, e o timer acorda só quando a imagem muda
    /// (no estado parado, 25 trocas a cada 8 s em vez de 96).
    private struct Run { let image: NSImage; let frames: Int }

    @ObservationIgnored private var meter: ActivityMeter
    @ObservationIgnored private var runs: [ActivityMeter.Level: [Run]] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var housekeeping: Timer?
    @ObservationIgnored private var phaseStart = Date()
    @ObservationIgnored private var phaseLevel: ActivityMeter.Level?
    @ObservationIgnored private var sleeping = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    /// O app relê os arquivos no máximo a cada 20 s quando há atividade (e a cada 2 min sem),
    /// então a janela é de 3 min, não o 1 min do kit; as faixas crescem na mesma proporção.
    static let configuration: ActivityMeter.Configuration = {
        var c = ActivityMeter.Configuration()
        c.window = 180
        c.busyTokens = 300_000
        c.burstTokens = 1_500_000
        return c
    }()

    /// Kit v3 (brand/mascot/menu-bar/animation-manifest.json): 12 quadros por segundo.
    static let fps: Double = 12
    static let frameCounts: [(ActivityMeter.Level, Int)] = [(.idle, 96), (.flowing, 72), (.busy, 36), (.burst, 36)]

    init() {
        meter = ActivityMeter(configuration: Self.configuration)
        for (level, count) in Self.frameCounts {
            if let built = Self.loadRuns(level.rawValue, count: count) { runs[level] = built }
        }
        image = runs[.idle]?.first?.image ?? Brand.menuBarIcon
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = true; self?.stopTimers() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = false; self?.meter.clearActivity(); self?.show() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.show() }
        })
        show()
    }

    /// Lê os quadros e junta os idênticos seguidos (compara os bytes do PNG).
    private static func loadRuns(_ state: String, count: Int) -> [Run]? {
        var out: [Run] = []
        var lastData: Data?
        for i in 0..<count {
            guard let url = Brand.resourceURL("MenuBar/\(state)/" + String(format: "%03d@2x.png", i)),
                  let data = try? Data(contentsOf: url) else { return nil }
            if data == lastData, let last = out.popLast() {
                out.append(Run(image: last.image, frames: last.frames + 1))
            } else {
                guard let img = NSImage(data: data) else { return nil }
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                out.append(Run(image: img, frames: 1))
            }
            lastData = data
        }
        return out
    }

    /// Recebe o total de tokens de hoje a cada releitura dos arquivos.
    func update(totalTokens: Int) {
        meter.observe(totalTokens: Int64(totalTokens))
        show()
    }

    /// Mostra o quadro certo agora e agenda a próxima troca de imagem.
    private func show(at date: Date = Date()) {
        guard !sleeping else { return }
        let current = meter.level(at: date)
        if level != current { level = current }
        if current != phaseLevel { phaseStart = date; phaseLevel = current }
        timer?.invalidate()
        timer = nil

        guard let runs = runs[current] ?? runs[.idle], !runs.isEmpty else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            setImage(runs[0].image)   // Reduzir movimento: pose parada, contador continua.
        } else {
            let cycle = runs.reduce(0) { $0 + $1.frames }
            var position = Int(date.timeIntervalSince(phaseStart) * Self.fps) % cycle
            var index = 0
            while position >= runs[index].frames { position -= runs[index].frames; index += 1 }
            setImage(runs[index].image)
            if runs.count > 1 {
                let wait = Double(runs[index].frames - position) / Self.fps
                let t = Timer(timeInterval: wait, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.show() }
                }
                t.tolerance = 0.02
                RunLoop.main.add(t, forMode: .common)
                timer = t
            }
        }
        // Com atividade, confere a cada 5 s se ela já expirou (para voltar a ficar quieto).
        if current != .idle, housekeeping == nil {
            let h = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.show() }
            }
            h.tolerance = 1
            RunLoop.main.add(h, forMode: .common)
            housekeeping = h
        } else if current == .idle {
            housekeeping?.invalidate()
            housekeeping = nil
        }
    }

    private func setImage(_ next: NSImage) {
        if next !== image { image = next }
    }

    private func stopTimers() {
        timer?.invalidate(); timer = nil
        housekeeping?.invalidate(); housekeeping = nil
    }

    /// Para a acessibilidade e a dica do ícone.
    var description: String {
        switch level {
        case .idle: T("Quiet", "Quietinho")
        case .flowing: T("Coding", "Programando")
        case .busy: T("Busy", "Ocupado")
        case .burst: T("Peak activity", "Pico de atividade")
        }
    }
}

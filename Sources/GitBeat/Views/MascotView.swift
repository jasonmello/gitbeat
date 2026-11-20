import AppKit
import SwiftUI

/// Os humores do mascote (kit v2). Os quadros vêm das faixas em `Resources/Mascot/<humor>.png`
/// (256 × 256 por quadro, da esquerda para a direita, 24 por segundo); `curious` é só imagem parada.
enum MascotMood: String, CaseIterable {
    case idle, focus, success, rest, greeting, curious

    var frameCount: Int {
        switch self {
        case .idle: 96
        case .focus: 58
        case .success, .greeting: 30
        case .rest: 144
        case .curious: 0
        }
    }

    /// Boas-vindas e conquista tocam uma vez e param no último quadro.
    var loops: Bool { self == .idle || self == .focus || self == .rest }

    var label: String {
        switch self {
        case .idle: T("GitBeat is keeping you company", "GitBeat está por perto")
        case .focus: T("GitBeat is following your session", "GitBeat está acompanhando seu trabalho")
        case .success: T("GitBeat is celebrating: all rings closed", "GitBeat está comemorando: anéis fechados")
        case .rest: T("GitBeat is resting", "GitBeat está descansando")
        case .greeting: T("GitBeat says hi", "GitBeat dá boas-vindas")
        case .curious: T("GitBeat found something new", "GitBeat achou uma novidade")
        }
    }

    static let fps: Double = 24
}

/// Corta as faixas de quadros uma vez só, em imagens próprias de 8 bits já no tamanho de exibição
/// (desenhar direto da faixa de 24 mil pixels de largura custava caro a cada quadro).
/// Guarda só os dois humores mais recentes.
@MainActor
private enum MascotFrames {
    private static var cache: [MascotMood: [NSImage]] = [:]
    private static var order: [MascotMood] = []
    /// 96 pt em tela 2x.
    static let pixels = 192

    static func frames(_ mood: MascotMood) -> [NSImage] {
        if let hit = cache[mood] { return hit }
        guard mood.frameCount > 0,
              let url = Brand.resourceURL("Mascot/\(mood.rawValue).png"),
              let source = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return [] }
        let side = source.height
        let frames = (0..<mood.frameCount).compactMap { i -> NSImage? in
            guard let crop = source.cropping(to: CGRect(x: i * side, y: 0, width: side, height: side)),
                  let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.interpolationQuality = .high
            ctx.draw(crop, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
            return ctx.makeImage().map { NSImage(cgImage: $0, size: NSSize(width: pixels / 2, height: pixels / 2)) }
        }
        cache[mood] = frames
        order.removeAll { $0 == mood }
        order.append(mood)
        while order.count > 2 { cache[order.removeFirst()] = nil }
        return frames
    }

    static func still(_ mood: MascotMood) -> NSImage? {
        Brand.resourceImage("Mascot/\(mood.rawValue)-static.png")
    }
}

/// O mascote animado. Para de pedir quadros quando o gesto de uma vez termina, quando a janela
/// não está ativa e com "Reduzir movimento" (aí mostra a pose parada).
struct MascotView: View {
    var mood: MascotMood
    var size: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState
    @ViewState private var startedAt = Date()
    @ViewState private var finished = false

    var body: some View {
        let frames = reduceMotion ? [] : MascotFrames.frames(mood)
        Group {
            if frames.isEmpty {
                still
            } else {
                TimelineView(.animation(minimumInterval: 1 / MascotMood.fps,
                                        paused: finished || activeState == .inactive)) { timeline in
                    let tick = max(0, Int(timeline.date.timeIntervalSince(startedAt) * MascotMood.fps))
                    let index = finished ? frames.count - 1
                        : mood.loops ? tick % frames.count : min(tick, frames.count - 1)
                    Image(nsImage: frames[index]).resizable().interpolation(.high).scaledToFit()
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mood.label)
        .help(mood.label)
        .task(id: mood) {
            startedAt = Date()
            finished = false
            guard !mood.loops, mood.frameCount > 0 else { return }
            try? await Task.sleep(nanoseconds: UInt64(Double(mood.frameCount) / MascotMood.fps * 1_000_000_000))
            if !Task.isCancelled { finished = true }
        }
    }

    @ViewBuilder
    private var still: some View {
        if let image = MascotFrames.still(mood) {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
        }
    }
}

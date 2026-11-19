import Foundation

/// Preço em dólar por milhão de tokens.
public struct ModelPrice: Equatable, Sendable {
    public var input: Double
    public var output: Double
    public var write5m: Double
    public var write1h: Double
    public var read: Double
}

/// Custo equivalente na API da Anthropic. Quem usa assinatura (Pro/Max) não paga isso,
/// mas o número mostra o tamanho real do uso.
///
/// Fonte: tabela de modelos da skill claude-api (cache de 2026-11-03), conferida em 2026-11-19.
/// Escrita de cache: 1,25× a entrada (5 min) e 2× (1 h). Leitura de cache: valor por modelo.
/// Modo rápido custa 2× nos modelos que o têm.
public enum Pricing {
    private static func p(_ input: Double, _ output: Double, read: Double) -> ModelPrice {
        ModelPrice(input: input, output: output, write5m: input * 1.25, write1h: input * 2, read: read)
    }

    /// Ordem importa: o primeiro prefixo que casar vence (ex.: "claude-opus-5-5" antes de "claude-opus-5").
    static let table: [(prefix: String, price: ModelPrice)] = [
        ("claude-fable-5-2", p(8, 40, read: 0.20)),
        ("claude-mythos-5-2", p(8, 40, read: 0.20)),
        ("claude-fable-5-1", p(10, 50, read: 0.25)),
        ("claude-mythos-5-1", p(10, 50, read: 0.25)),
        ("claude-fable-5", p(10, 50, read: 1.00)),
        ("claude-mythos-5", p(10, 50, read: 1.00)),
        ("claude-opus-5-5", p(4, 20, read: 0.20)),
        ("claude-opus-5", p(5, 25, read: 0.50)),
        ("claude-opus-4", p(5, 25, read: 0.50)),
        ("claude-sonnet-5-5", p(2, 10, read: 0.10)),
        ("claude-sonnet-5", p(2, 10, read: 0.20)),
        ("claude-sonnet-4", p(3, 15, read: 0.30)),
        ("claude-haiku-5-5", p(0.10, 0.50, read: 0.01)),
        ("claude-haiku-4", p(1, 5, read: 0.10)),
    ]

    public static func price(for model: String) -> ModelPrice? {
        let id = model.lowercased()
        return table.first { id.hasPrefix($0.prefix) }?.price
    }

    /// `nil` quando o modelo não está na tabela.
    public static func cost(of r: UsageRecord) -> Double? {
        if let stored = r.costUSD { return stored }
        guard let p = price(for: r.model) else { return nil }
        let perToken = 1.0 / 1_000_000
        let base = Double(r.input) * p.input + Double(r.output) * p.output
            + Double(r.cacheWrite5m) * p.write5m + Double(r.cacheWrite1h) * p.write1h
            + Double(r.cacheRead) * p.read
        return base * perToken * (r.fast ? 2 : 1)
    }

    /// Nome curto para a tela: "claude-opus-5-5" → "Opus 5.5".
    public static func displayName(for model: String) -> String {
        var s = model.lowercased()
        guard s.hasPrefix("claude-") else { return model } // modelos de outras empresas: nome como veio
        s.removeFirst("claude-".count)
        var parts = s.split(separator: "-").map(String.init)
        guard let family = parts.first else { return model }
        parts.removeFirst()
        let version = parts.prefix { $0.count <= 2 && Int($0) != nil }.joined(separator: ".")
        return version.isEmpty ? family.capitalized : "\(family.capitalized) \(version)"
    }
}

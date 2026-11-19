import SwiftUI

/// Igual ao `@State` do SwiftUI.
///
/// No SDK do macOS 27, `@State` virou macro, e o plugin dessa macro só vem com o Xcode completo.
/// Este projeto compila só com as Command Line Tools (ver docs/decisoes.md), então guarda um
/// `State` por dentro, que o SwiftUI reconhece como uma propriedade dinâmica qualquer.
@propertyWrapper
struct ViewState<Value>: DynamicProperty {
    private let storage: State<Value>

    init(wrappedValue: Value) {
        storage = State(initialValue: wrappedValue)
    }

    var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }

    var projectedValue: Binding<Value> { storage.projectedValue }
}

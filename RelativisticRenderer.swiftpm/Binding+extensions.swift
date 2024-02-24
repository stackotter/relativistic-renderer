import SwiftUI

public extension Binding where Value: BinaryInteger {
    func into<F: BinaryFloatingPoint>() -> Binding<F> {
        Binding<F>(
            get: { F(wrappedValue) },
            set: { wrappedValue = Value($0) }
        )
    }
}

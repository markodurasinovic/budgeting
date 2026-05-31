import Foundation

public extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
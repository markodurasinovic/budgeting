import Foundation
import SwiftData

@Model
final public class Tag {
    public var id: UUID
    public var name: String
    public var colorHex: String

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = ""
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
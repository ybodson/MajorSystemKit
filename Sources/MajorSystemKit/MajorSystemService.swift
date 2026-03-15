import Foundation

public protocol MajorSystemServing: Sendable {
    func matches(for number: String, limit: Int) -> [MajorEntry]
    func code(for phonemes: [String]) -> String
}

public struct MajorSystemService: MajorSystemServing, Sendable {
    public let index: MajorIndexFile
    public let encoder: MajorEncoder

    public init(index: MajorIndexFile, encoder: MajorEncoder = MajorEncoder()) {
        self.index = index
        self.encoder = encoder
    }

    public func matches(for number: String, limit: Int = 20) -> [MajorEntry] {
        Array(index.entriesByCode[number, default: []].sorted(by: sortEntries).prefix(limit))
    }

    public func code(for phonemes: [String]) -> String {
        encoder.encode(phonemes: phonemes)
    }

    private func sortEntries(lhs: MajorEntry, rhs: MajorEntry) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.word.count != rhs.word.count {
            return lhs.word.count < rhs.word.count
        }
        return lhs.word < rhs.word
    }
}

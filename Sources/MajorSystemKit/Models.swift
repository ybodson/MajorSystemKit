import Foundation

public struct MajorEntry: Codable, Hashable, Sendable {
    public let word: String
    public let phonemes: [String]
    public let majorCode: String
    public let score: Double

    public init(word: String, phonemes: [String], majorCode: String, score: Double = 1.0) {
        self.word = word
        self.phonemes = phonemes
        self.majorCode = majorCode
        self.score = score
    }
}

public struct MajorIndexFile: Codable, Hashable, Sendable {
    public let entriesByCode: [String: [MajorEntry]]

    public init(entriesByCode: [String: [MajorEntry]]) {
        self.entriesByCode = entriesByCode
    }
}

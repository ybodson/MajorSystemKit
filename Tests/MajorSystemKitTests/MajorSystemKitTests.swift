import Foundation
import Testing
@testable import MajorSystemKit

@Test func majorEncoderMapsARPABETToDigits() {
    let encoder = MajorEncoder()

    #expect(encoder.encode(phonemes: ["SH", "EH1", "F"]) == "68")
    #expect(encoder.encode(phonemes: ["F", "OW1", "N"]) == "82")
    #expect(encoder.encode(phonemes: ["M", "IY1", "T", "ER0"]) == "314")
    #expect(encoder.encode(phonemes: ["S", "IH1", "NG"]) == "07")
}

@Test func encoderKeepsOnlyConsonantPhonemes() {
    let encoder = MajorEncoder()

    #expect(encoder.consonantPhonemes(from: ["M", "IY1", "T", "ER0"]) == ["M", "T", "R"])
    #expect(encoder.consonantPhonemes(from: ["SH", "EH1", "F"]) == ["SH", "F"])
}

@Test func bundledIndexLoads() throws {
    let index = try MajorIndexLoader.loadBundledIndex()
    #expect(index.entriesByCode["314"]?.count == 76)
}

@Test func bundledIndexContainsOnlyConsonants() throws {
    let index = try MajorIndexLoader.loadBundledIndex()
    let meter = try #require(index.entriesByCode["314"]?.first(where: { $0.word == "meter" }))

    #expect(meter.phonemes == ["M", "T", "R"])
}

@Test func bundledIndexKeepsDistinctPronunciationsForSameWordAndCode() throws {
    let index = try MajorIndexLoader.loadBundledIndex()
    let actualEntries = index.entriesByCode["765"]?.filter { $0.word == "actual" } ?? []

    #expect(actualEntries.map(\.phonemes) == [["K", "CH", "L"], ["K", "SH", "L"]])
}

@Test func serviceReturnsSortedMatches() throws {
    let index = try MajorIndexLoader.loadBundledIndex()
    let service = MajorSystemService(index: index)

    let matches = service.matches(for: "314")
    #expect(matches.count == 20)

    // Entries with score == -1 (filtered: too short, no vowel, or below frequency threshold)
    // must appear after all positively-scored entries.
    var seenFiltered = false
    for match in matches {
        if match.score == -1 {
            seenFiltered = true
        } else {
            #expect(!seenFiltered, "Scored entry '\(match.word)' appears after a filtered (-1) entry")
        }
    }

    // Among entries in the same score tier, verify sort order: score desc → length asc → alpha.
    for i in 0 ..< matches.count - 1 {
        let a = matches[i], b = matches[i + 1]
        guard a.score != -1, b.score != -1 else { continue }
        if a.score != b.score {
            #expect(a.score > b.score)
        } else if a.word.count != b.word.count {
            #expect(a.word.count <= b.word.count)
        } else {
            #expect(a.word <= b.word)
        }
    }
}

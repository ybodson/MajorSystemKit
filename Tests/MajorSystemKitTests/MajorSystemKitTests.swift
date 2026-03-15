import Foundation
import Testing
@testable import MajorSystemKit

@Test func majorEncoderMapsARPABETToDigits() {
    let encoder = MajorEncoder()

    #expect(encoder.encode(phonemes: ["SH", "EH1", "F"]) == "68")
    #expect(encoder.encode(phonemes: ["F", "OW1", "N"]) == "82")
    #expect(encoder.encode(phonemes: ["M", "IY1", "T", "ER0"]) == "314")
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

@Test func serviceReturnsSortedMatches() throws {
    let index = try MajorIndexLoader.loadBundledIndex()
    let service = MajorSystemService(index: index)

    let matches = service.matches(for: "314")

    #expect(matches.map(\.word) == ["emdr", "amdur", "madar", "mader", "madra", "madre", "madry", "mater", "matra", "medar", "meder", "meter", "metra", "metre", "metro", "miter", "mitra", "mitre", "mitro", "moder"])
}

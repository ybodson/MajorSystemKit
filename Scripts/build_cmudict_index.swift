#!/usr/bin/env swift

import Foundation

struct MajorEntry: Codable, Hashable {
    let word: String
    let phonemes: [String]
    let majorCode: String
    let score: Double
}

struct MajorIndexFile: Codable {
    let entriesByCode: [String: [MajorEntry]]
}

enum ScriptError: LocalizedError {
    case invalidArguments
    case unreadableSource(URL)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return """
            Usage: swift Scripts/build_cmudict_index.swift \\
              path/to/cmudict.dict output.json \\
              [path/to/SUBTLEX-US.txt [path/to/brysbaert-concreteness.txt]]

            Data sources (download separately):
              SUBTLEX-US.txt     — Brysbaert & New (2009), tab-separated, column SUBTLWF = freq/million
              brysbaert-concreteness.txt — Brysbaert et al. (2014), tab-separated, column Conc.M = 1–5
            """
        case .unreadableSource(let url):
            return "Could not read file at \(url.path)"
        }
    }
}

// MARK: - Scoring data

struct ScoringData {
    /// Lowercase word → frequency per million words (SUBTLWF from SUBTLEX-US)
    let frequencyPerMillion: [String: Double]
    /// Lowercase word → mean concreteness rating 1–5 (Conc.M from Brysbaert et al. 2014)
    let concreteness: [String: Double]

    static let empty = ScoringData(frequencyPerMillion: [:], concreteness: [:])
}

enum ScoringDataLoader {
    /// Tab-separated SUBTLEX-US file with header row.
    /// Key columns: Word, SUBTLWF (frequency per million words).
    static func loadFrequency(from url: URL) throws -> [String: Double] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var result: [String: Double] = [:]
        var wordCol = 0
        var fpmCol = 5
        var isHeader = true

        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if isHeader {
                if let i = parts.firstIndex(of: "Word") { wordCol = i }
                if let i = parts.firstIndex(of: "SUBTLWF") { fpmCol = i }
                isHeader = false
                continue
            }
            guard parts.count > max(wordCol, fpmCol) else { continue }
            let word = parts[wordCol].lowercased()
            guard let fpm = Double(parts[fpmCol]) else { continue }
            result[word] = max(result[word, default: 0], fpm)
        }
        return result
    }

    /// Tab-separated Brysbaert et al. (2014) concreteness file with header row.
    /// Key columns: Word, Conc.M (mean concreteness 1–5).
    static func loadConcreteness(from url: URL) throws -> [String: Double] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var result: [String: Double] = [:]
        var wordCol = 0
        var concCol = 2
        var isHeader = true

        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if isHeader {
                if let i = parts.firstIndex(of: "Word") { wordCol = i }
                if let i = parts.firstIndex(of: "Conc.M") { concCol = i }
                isHeader = false
                continue
            }
            guard parts.count > max(wordCol, concCol) else { continue }
            let word = parts[wordCol].lowercased()
            guard let conc = Double(parts[concCol]) else { continue }
            result[word] = conc
        }
        return result
    }
}

// MARK: - Scoring

enum Scorer {
    /// Minimum SUBTLWF (freq per million) for a word to pass the frequency filter.
    private static let freqThreshold = 1.0
    /// Approximate FPM of "the" in SUBTLEX-US, used to normalize the log scale.
    private static let maxFPM = 20000.0
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u"]

    /// Returns a score in [0, 1] for memorable words, or -1 for words that fail hard filters.
    ///
    /// Hard filters (score = -1):
    ///   - Fewer than 3 characters (too short to be useful as a mnemonic)
    ///   - No vowel in spelling (abbreviations / acronyms like "emdr")
    ///   - Below frequency threshold when frequency data is available
    ///
    /// Composite score weights:
    ///   - 60% frequency   — log-normalized SUBTLWF; neutral 0.5 when data unavailable
    ///   - 25% concreteness — Brysbaert 1–5 normalized to 0–1; neutral 0.5 when unavailable
    ///   - 15% length      — peaks at 4–7 chars, falls off at extremes
    static func score(word: String, scoring: ScoringData, hasFrequencyData: Bool) -> Double {
        guard word.count >= 3 else { return -1.0 }
        guard word.contains(where: { vowels.contains($0) }) else { return -1.0 }

        let fpm: Double?
        if hasFrequencyData {
            guard let f = scoring.frequencyPerMillion[word], f >= freqThreshold else { return -1.0 }
            fpm = f
        } else {
            fpm = nil
        }

        let freqScore: Double
        if let f = fpm {
            freqScore = log(f + 1) / log(maxFPM + 1)
        } else {
            freqScore = 0.5
        }

        // Brysbaert scale is 1–5; normalize to 0–1
        let rawConc = scoring.concreteness[word] ?? 3.0
        let concScore = (rawConc - 1.0) / 4.0

        let composite = freqScore * 0.60 + concScore * 0.25 + lengthScore(word.count) * 0.15
        return (composite * 1000).rounded() / 1000
    }

    private static func lengthScore(_ length: Int) -> Double {
        switch length {
        case ..<4: return 0.6
        case 4...7: return 1.0
        case 8: return 0.9
        case 9: return 0.75
        default: return 0.5
        }
    }
}

// MARK: - Index builder

enum CMUDictBuilder {
    private static let digitMap: [String: String] = [
        "S": "0", "Z": "0",
        "T": "1", "D": "1", "TH": "1", "DH": "1",
        "N": "2",
        "M": "3",
        "R": "4",
        "L": "5",
        "CH": "6", "JH": "6", "SH": "6", "ZH": "6",
        "K": "7", "G": "7", "NG": "7",
        "F": "8", "V": "8",
        "P": "9", "B": "9"
    ]

    static func run(arguments: [String]) throws {
        guard arguments.count >= 3 else {
            throw ScriptError.invalidArguments
        }

        let sourceURL = URL(fileURLWithPath: arguments[1])
        let destinationURL = URL(fileURLWithPath: arguments[2])

        guard let rawText = try? String(contentsOf: sourceURL, encoding: .isoLatin1) else {
            throw ScriptError.unreadableSource(sourceURL)
        }

        var frequencyData: [String: Double] = [:]
        var concretenessData: [String: Double] = [:]

        if arguments.count >= 4 {
            let url = URL(fileURLWithPath: arguments[3])
            frequencyData = (try? ScoringDataLoader.loadFrequency(from: url)) ?? [:]
            print("Loaded \(frequencyData.count) frequency entries from \(url.lastPathComponent)")
        }
        if arguments.count >= 5 {
            let url = URL(fileURLWithPath: arguments[4])
            concretenessData = (try? ScoringDataLoader.loadConcreteness(from: url)) ?? [:]
            print("Loaded \(concretenessData.count) concreteness entries from \(url.lastPathComponent)")
        }

        let scoring = ScoringData(frequencyPerMillion: frequencyData, concreteness: concretenessData)
        let hasFrequencyData = !frequencyData.isEmpty

        let index = buildIndex(from: rawText, scoring: scoring, hasFrequencyData: hasFrequencyData)
        try write(index: index, to: destinationURL)

        let totalEntries = index.entriesByCode.values.reduce(0) { $0 + $1.count }
        let filteredEntries = index.entriesByCode.values.flatMap { $0 }.filter { $0.score == -1 }.count
        print("Done. \(totalEntries) total entries, \(filteredEntries) scored -1. Written to \(destinationURL.path)")
    }

    static func buildIndex(from text: String, scoring: ScoringData, hasFrequencyData: Bool) -> MajorIndexFile {
        var entriesByCode: [String: [MajorEntry]] = [:]
        var seen: Set<SeenKey> = []

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";;;") else { continue }

            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2 else { continue }

            let rawWord = String(parts[0])
            let word = normalizeWord(rawWord)
            guard isValidWord(word) else { continue }

            let consonantPhonemes = majorConsonantPhonemes(from: parts.dropFirst().map(String.init))
            guard !consonantPhonemes.isEmpty else { continue }

            let code = consonantPhonemes.compactMap { digitMap[$0] }.joined()
            let key = SeenKey(word: word, code: code, phonemes: consonantPhonemes)
            guard seen.insert(key).inserted else { continue }

            let wordScore = Scorer.score(word: word, scoring: scoring, hasFrequencyData: hasFrequencyData)
            let entry = MajorEntry(word: word, phonemes: consonantPhonemes, majorCode: code, score: wordScore)
            entriesByCode[code, default: []].append(entry)
        }

        for code in entriesByCode.keys {
            entriesByCode[code]?.sort { a, b in
                // Filtered entries (-1) go after all scored entries
                if (a.score == -1) != (b.score == -1) { return b.score == -1 }
                // Higher score first
                if a.score != b.score { return a.score > b.score }
                // Shorter word first
                if a.word.count != b.word.count { return a.word.count < b.word.count }
                // Alphabetical
                if a.word != b.word { return a.word < b.word }
                // Tie-break by phonemes to give stable ordering for multiple pronunciations
                return a.phonemes.lexicographicallyPrecedes(b.phonemes)
            }
        }

        return MajorIndexFile(
            entriesByCode: entriesByCode
                .sorted { $0.key < $1.key }
                .reduce(into: [:]) { $0[$1.key] = $1.value }
        )
    }

    private static func normalizeWord(_ rawWord: String) -> String {
        let uppercased = rawWord.uppercased()
        let stripped: String
        if let open = uppercased.firstIndex(of: "("), uppercased.hasSuffix(")") {
            stripped = String(uppercased[..<open])
        } else {
            stripped = uppercased
        }
        return stripped.lowercased()
    }

    private static func isValidWord(_ word: String) -> Bool {
        !word.isEmpty && word.allSatisfy(\.isLetter)
    }

    private static func normalizePhoneme(_ phoneme: String) -> String {
        let withoutStress = phoneme.filter { !$0.isNumber }.uppercased()
        return withoutStress == "ER" ? "R" : withoutStress
    }

    private static func majorConsonantPhonemes(from phonemes: [String]) -> [String] {
        phonemes.compactMap { phoneme in
            let normalized = normalizePhoneme(phoneme)
            return digitMap[normalized] != nil ? normalized : nil
        }
    }

    private static func write(index: MajorIndexFile, to destinationURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(index)
        let directoryURL = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: destinationURL, options: .atomic)
    }

    private struct SeenKey: Hashable {
        let word: String
        let code: String
        let phonemes: [String]
    }
}

do {
    try CMUDictBuilder.run(arguments: CommandLine.arguments)
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

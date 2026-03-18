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
            return "Usage: swift Scripts/build_cmudict_index.swift path/to/cmudict.dict output.json"
        case .unreadableSource(let url):
            return "Could not read CMUdict source at \(url.path)"
        }
    }
}

enum CMUDictBuilder {
    private static let digitMap: [String: String] = [
        "S": "0",
        "Z": "0",
        "T": "1",
        "D": "1",
        "TH": "1",
        "DH": "1",
        "N": "2",
        "M": "3",
        "R": "4",
        "L": "5",
        "CH": "6",
        "JH": "6",
        "SH": "6",
        "ZH": "6",
        "K": "7",
        "G": "7",
        "NG": "7",
        "F": "8",
        "V": "8",
        "P": "9",
        "B": "9"
    ]

    static func run(arguments: [String]) throws {
        guard arguments.count == 3 else {
            throw ScriptError.invalidArguments
        }

        let sourceURL = URL(fileURLWithPath: arguments[1])
        let destinationURL = URL(fileURLWithPath: arguments[2])

        guard let rawText = try String(contentsOf: sourceURL, encoding: .isoLatin1) as String? else {
            throw ScriptError.unreadableSource(sourceURL)
        }

        let index = buildIndex(from: rawText)
        try write(index: index, to: destinationURL)
    }

    static func buildIndex(from text: String) -> MajorIndexFile {
        var entriesByCode: [String: [MajorEntry]] = [:]
        var seen: Set<SeenKey> = []

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";;;") else {
                continue
            }

            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2 else {
                continue
            }

            let rawWord = String(parts[0])
            let word = normalizeWord(rawWord)
            guard isValidWord(word) else {
                continue
            }

            let consonantPhonemes = majorConsonantPhonemes(from: parts.dropFirst().map(String.init))
            guard !consonantPhonemes.isEmpty else {
                continue
            }

            let code = consonantPhonemes.compactMap { digitMap[$0] }.joined()
            let key = SeenKey(word: word, code: code, phonemes: consonantPhonemes)
            guard seen.insert(key).inserted else {
                continue
            }

            let entry = MajorEntry(
                word: word,
                phonemes: consonantPhonemes,
                majorCode: code,
                score: 1.0
            )

            entriesByCode[code, default: []].append(entry)
        }

        for code in entriesByCode.keys {
            entriesByCode[code]?.sort {
                if $0.word != $1.word {
                    return $0.word < $1.word
                }
                return $0.phonemes.lexicographicallyPrecedes($1.phonemes)
            }
        }

        return MajorIndexFile(entriesByCode: entriesByCode.sorted { $0.key < $1.key }.reduce(into: [:]) { partialResult, item in
            partialResult[item.key] = item.value
        })
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
        switch withoutStress {
        case "ER":
            return "R"
        default:
            return withoutStress
        }
    }

    private static func majorConsonantPhonemes(from phonemes: [String]) -> [String] {
        phonemes.compactMap { phoneme in
            let normalized = normalizePhoneme(phoneme)
            guard digitMap[normalized] != nil else {
                return nil
            }
            return normalized
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

import Foundation

public protocol MajorEncoding: Sendable {
    func encode(phonemes: [String]) -> String
    func consonantPhonemes(from phonemes: [String]) -> [String]
}

public struct MajorEncoder: MajorEncoding, Sendable {
    public init() {}

    public func encode(phonemes: [String]) -> String {
        consonantPhonemes(from: phonemes)
            .compactMap(Self.mapPhonemeToDigit)
            .map(String.init)
            .joined()
    }

    public func consonantPhonemes(from phonemes: [String]) -> [String] {
        phonemes.compactMap { phoneme in
            let normalized = Self.normalize(phoneme)
            guard Self.mapPhonemeToDigit(normalized) != nil else {
                return nil
            }
            return normalized
        }
    }

    public static func normalize(_ phoneme: String) -> String {
        let stripped = phoneme.filter { !$0.isNumber }.uppercased()

        switch stripped {
        case "ER":
            return "R"
        default:
            return stripped
        }
    }

    public static func mapPhonemeToDigit(_ phoneme: String) -> Int? {
        switch phoneme {
        case "S", "Z":
            return 0
        case "T", "D", "TH", "DH":
            return 1
        case "N":
            return 2
        case "M":
            return 3
        case "R":
            return 4
        case "L":
            return 5
        case "CH", "JH", "SH", "ZH":
            return 6
        case "K", "G":
            return 7
        case "F", "V":
            return 8
        case "P", "B":
            return 9
        default:
            return nil
        }
    }
}

import Foundation

public enum MajorIndexLoader {
    public static func loadBundledIndex(named resourceName: String = "cmudict-major-index") throws -> MajorIndexFile {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw MajorSystemError.missingBundledResource(resourceName)
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MajorIndexFile.self, from: data)
    }

    public static func loadIndex(from url: URL) throws -> MajorIndexFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MajorIndexFile.self, from: data)
    }
}

public enum MajorSystemError: LocalizedError, Sendable {
    case missingBundledResource(String)

    public var errorDescription: String? {
        switch self {
        case .missingBundledResource(let name):
            return "Could not find bundled index resource named \(name).json"
        }
    }
}

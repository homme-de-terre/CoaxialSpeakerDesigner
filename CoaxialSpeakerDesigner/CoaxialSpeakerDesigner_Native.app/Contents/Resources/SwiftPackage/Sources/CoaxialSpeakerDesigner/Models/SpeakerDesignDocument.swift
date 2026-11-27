import Foundation

/// Unified Loudspeaker Design Document encapsulating all driver, cabinet, crossover, and curve parameters.
public struct SpeakerDesignDocument: Codable, Sendable {
    public var version: Int
    public var timestamp: Date
    public var name: String
    public var driver: CoaxialDriver
    public var cabinet: SealedCabinet
    public var crossover: CrossoverNetwork
    public var wooferFRDText: String?
    public var tweeterFRDText: String?

    public init(
        version: Int = 1,
        timestamp: Date = Date(),
        name: String,
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        wooferFRDText: String? = nil,
        tweeterFRDText: String? = nil
    ) {
        self.version = version
        self.timestamp = timestamp
        self.name = name
        self.driver = driver
        self.cabinet = cabinet
        self.crossover = crossover
        self.wooferFRDText = wooferFRDText
        self.tweeterFRDText = tweeterFRDText
    }

    /// Serializes document into formatted JSON string.
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SpeakerDesignDocument", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON data to UTF-8 string"])
        }
        return str
    }

    /// Deserializes a document from a JSON string.
    public static func fromJSON(_ jsonString: String) throws -> SpeakerDesignDocument {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "SpeakerDesignDocument", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 string"])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SpeakerDesignDocument.self, from: data)
    }
}
